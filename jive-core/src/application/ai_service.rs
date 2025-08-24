// AI Service - Based on Maybe's assistant and auto-categorization
// References: app/models/assistant.rb, family/auto_categorizer.rb

use crate::domain::errors::DomainError;
use crate::infrastructure::entities::transaction::*;
use crate::infrastructure::entities::ledger::*;
use chrono::{DateTime, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::sync::Arc;
use sqlx::PgPool;
use uuid::Uuid;

pub struct AIService {
    pool: Arc<PgPool>,
    openai_api_key: Option<String>,
    anthropic_api_key: Option<String>,
}

impl AIService {
    pub fn new(pool: Arc<PgPool>) -> Self {
        Self {
            pool,
            openai_api_key: std::env::var("OPENAI_API_KEY").ok(),
            anthropic_api_key: std::env::var("ANTHROPIC_API_KEY").ok(),
        }
    }
    
    // Auto-categorize transactions using AI
    pub async fn auto_categorize_with_ai(
        &self,
        family_id: Uuid,
        transaction_ids: Vec<Uuid>,
    ) -> Result<Vec<AICategorization>, DomainError> {
        if self.openai_api_key.is_none() {
            return Err(DomainError::Configuration("No OpenAI API key configured".to_string()));
        }
        
        // Get transactions to categorize
        let transactions = self.get_transactions_for_categorization(
            family_id,
            &transaction_ids,
        ).await?;
        
        if transactions.is_empty() {
            return Ok(Vec::new());
        }
        
        // Get user's categories
        let categories = self.get_family_categories(family_id).await?;
        
        // Prepare AI request
        let ai_request = AICategorizeRequest {
            transactions: transactions.clone(),
            categories,
        };
        
        // Call OpenAI API
        let ai_result = self.call_openai_categorization(ai_request).await?;
        
        // Apply categorizations
        let mut results = Vec::new();
        
        for categorization in ai_result.categorizations {
            if let Some(category_id) = categorization.category_id {
                // Update transaction
                sqlx::query!(
                    r#"
                    UPDATE transactions 
                    SET category_id = $1, updated_at = $2
                    WHERE id = $3
                    "#,
                    category_id,
                    Utc::now(),
                    categorization.transaction_id
                )
                .execute(&*self.pool)
                .await
                .map_err(|e| DomainError::Database(e.to_string()))?;
                
                // Create enrichment record
                sqlx::query!(
                    r#"
                    INSERT INTO data_enrichments (
                        id, family_id, enrichment_type, resource_type, resource_id,
                        original_value, enriched_value, confidence, provider, applied,
                        created_at, updated_at
                    )
                    VALUES ($1, $2, 'category_detection', 'Transaction', $3, $4, $5, $6, 'openai', true, $7, $7)
                    "#,
                    Uuid::new_v4(),
                    family_id,
                    categorization.transaction_id,
                    categorization.original_description,
                    categorization.category_name.unwrap_or_default(),
                    categorization.confidence,
                    Utc::now()
                )
                .execute(&*self.pool)
                .await
                .map_err(|e| DomainError::Database(e.to_string()))?;
                
                results.push(categorization);
            }
        }
        
        Ok(results)
    }
    
    // Chat with AI assistant
    pub async fn chat(
        &self,
        user_id: Uuid,
        chat_id: Option<Uuid>,
        message: String,
    ) -> Result<ChatResponse, DomainError> {
        let chat_id = if let Some(id) = chat_id {
            id
        } else {
            // Create new chat
            self.create_chat(user_id).await?
        };
        
        // Save user message
        let user_message = self.save_message(
            chat_id,
            MessageRole::User,
            message.clone(),
            "gpt-4".to_string(),
        ).await?;
        
        // Get chat context
        let context = self.get_chat_context(chat_id).await?;
        
        // Prepare AI request with financial functions
        let ai_request = ChatRequest {
            messages: context.messages,
            functions: self.get_financial_functions(),
            model: "gpt-4".to_string(),
        };
        
        // Call AI
        let ai_response = self.call_openai_chat(ai_request).await?;
        
        // Save assistant response
        let assistant_message = self.save_message(
            chat_id,
            MessageRole::Assistant,
            ai_response.content,
            "gpt-4".to_string(),
        ).await?;
        
        // Handle function calls if any
        if let Some(function_calls) = ai_response.function_calls {
            for function_call in function_calls {
                let function_result = self.execute_function(
                    user_id,
                    &function_call,
                ).await?;
                
                // Save function result
                self.save_message(
                    chat_id,
                    MessageRole::Tool,
                    function_result,
                    "system".to_string(),
                ).await?;
            }
        }
        
        Ok(ChatResponse {
            chat_id,
            message_id: assistant_message.id,
            content: assistant_message.content,
            function_calls: ai_response.function_calls,
        })
    }
    
    // Execute financial function calls
    async fn execute_function(
        &self,
        user_id: Uuid,
        function_call: &FunctionCall,
    ) -> Result<String, DomainError> {
        // Get user's family
        let family_id = self.get_user_family(user_id).await?;
        
        match function_call.name.as_str() {
            "get_accounts" => {
                let accounts = sqlx::query!(
                    r#"
                    SELECT name, accountable_type, balance, currency
                    FROM accounts 
                    WHERE family_id = $1 AND status = 'active'
                    ORDER BY name
                    "#,
                    family_id
                )
                .fetch_all(&*self.pool)
                .await
                .map_err(|e| DomainError::Database(e.to_string()))?;
                
                let result = accounts.into_iter()
                    .map(|a| format!("{}: {} {}", a.name, a.balance.unwrap_or(Decimal::ZERO), a.currency))
                    .collect::<Vec<_>>()
                    .join("\n");
                
                Ok(result)
            }
            
            "get_transactions" => {
                let args: GetTransactionsArgs = serde_json::from_value(function_call.arguments.clone())
                    .map_err(|e| DomainError::Parsing(e.to_string()))?;
                
                let transactions = sqlx::query!(
                    r#"
                    SELECT e.date, e.name, e.amount, e.currency, a.name as account_name
                    FROM entries e
                    JOIN transactions t ON t.entry_id = e.id
                    JOIN accounts a ON a.id = e.account_id
                    WHERE a.family_id = $1
                        AND e.date >= CURRENT_DATE - INTERVAL '%s days'
                    ORDER BY e.date DESC
                    LIMIT $2
                    "#,
                    family_id,
                    args.limit.unwrap_or(10) as i64
                )
                .fetch_all(&*self.pool)
                .await
                .map_err(|e| DomainError::Database(e.to_string()))?;
                
                let result = transactions.into_iter()
                    .map(|t| format!("{}: {} {} {} ({})", 
                        t.date, t.name, t.amount, t.currency, t.account_name))
                    .collect::<Vec<_>>()
                    .join("\n");
                
                Ok(result)
            }
            
            "get_balance_sheet" => {
                // Generate balance sheet
                let today = chrono::Local::now().naive_local().date();
                let net_worth = sqlx::query!(
                    r#"
                    SELECT 
                        COALESCE(SUM(CASE 
                            WHEN a.classification = 'asset' 
                            THEN COALESCE(a.balance, 0) 
                            ELSE 0 
                        END), 0) as assets,
                        COALESCE(SUM(CASE 
                            WHEN a.classification = 'liability' 
                            THEN ABS(COALESCE(a.balance, 0))
                            ELSE 0 
                        END), 0) as liabilities
                    FROM accounts a
                    WHERE a.family_id = $1 AND a.include_in_net_worth = true
                    "#,
                    family_id
                )
                .fetch_one(&*self.pool)
                .await
                .map_err(|e| DomainError::Database(e.to_string()))?;
                
                let assets = net_worth.assets.unwrap_or(Decimal::ZERO);
                let liabilities = net_worth.liabilities.unwrap_or(Decimal::ZERO);
                let net_worth_total = assets - liabilities;
                
                Ok(format!("Assets: {}\nLiabilities: {}\nNet Worth: {}", 
                    assets, liabilities, net_worth_total))
            }
            
            _ => Err(DomainError::Configuration(
                format!("Unknown function: {}", function_call.name)
            ))
        }
    }
    
    // Get financial functions available to AI
    fn get_financial_functions(&self) -> Vec<FunctionDefinition> {
        vec![
            FunctionDefinition {
                name: "get_accounts".to_string(),
                description: "Get list of user's accounts with balances".to_string(),
                parameters: serde_json::json!({
                    "type": "object",
                    "properties": {},
                    "required": []
                }),
            },
            FunctionDefinition {
                name: "get_transactions".to_string(),
                description: "Get recent transactions".to_string(),
                parameters: serde_json::json!({
                    "type": "object",
                    "properties": {
                        "limit": {
                            "type": "integer",
                            "description": "Number of transactions to return"
                        },
                        "days": {
                            "type": "integer", 
                            "description": "Number of days to look back"
                        }
                    },
                    "required": []
                }),
            },
            FunctionDefinition {
                name: "get_balance_sheet".to_string(),
                description: "Get current balance sheet summary".to_string(),
                parameters: serde_json::json!({
                    "type": "object",
                    "properties": {},
                    "required": []
                }),
            },
        ]
    }
    
    // Helper methods
    
    async fn get_transactions_for_categorization(
        &self,
        family_id: Uuid,
        transaction_ids: &[Uuid],
    ) -> Result<Vec<TransactionForAI>, DomainError> {
        let transactions = sqlx::query!(
            r#"
            SELECT 
                t.id,
                e.name as description,
                e.amount,
                e.currency,
                p.name as merchant_name
            FROM transactions t
            JOIN entries e ON e.id = t.entry_id
            JOIN accounts a ON a.id = e.account_id
            LEFT JOIN payees p ON p.id = t.payee_id
            WHERE a.family_id = $1 
                AND t.id = ANY($2)
                AND t.category_id IS NULL
            "#,
            family_id,
            &transaction_ids
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut result = Vec::new();
        for tx in transactions {
            result.push(TransactionForAI {
                id: tx.id,
                description: tx.description,
                amount: tx.amount.abs(),
                currency: tx.currency,
                merchant_name: tx.merchant_name,
            });
        }
        
        Ok(result)
    }
    
    async fn get_family_categories(&self, family_id: Uuid) -> Result<Vec<CategoryForAI>, DomainError> {
        let categories = sqlx::query!(
            r#"
            SELECT id, name, classification, parent_id
            FROM categories
            WHERE family_id = $1 AND is_archived = false
            ORDER BY name
            "#,
            family_id
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        let mut result = Vec::new();
        for cat in categories {
            result.push(CategoryForAI {
                id: cat.id,
                name: cat.name,
                classification: cat.classification,
                is_subcategory: cat.parent_id.is_some(),
                parent_id: cat.parent_id,
            });
        }
        
        Ok(result)
    }
    
    async fn call_openai_categorization(
        &self,
        request: AICategorizeRequest,
    ) -> Result<AICategorizeResponse, DomainError> {
        let api_key = self.openai_api_key.as_ref()
            .ok_or_else(|| DomainError::Configuration("OpenAI API key not configured".to_string()))?;
        
        // Prepare system prompt
        let system_prompt = format!(
            "You are a financial categorization assistant. Categorize the following transactions using the provided categories.\n\nAvailable categories:\n{}",
            request.categories.iter()
                .map(|c| format!("- {} ({})", c.name, c.classification))
                .collect::<Vec<_>>()
                .join("\n")
        );
        
        // Prepare user message
        let user_message = format!(
            "Categorize these transactions:\n{}",
            request.transactions.iter()
                .map(|t| format!("{}: {} {} - {}", t.id, t.amount, t.currency, t.description))
                .collect::<Vec<_>>()
                .join("\n")
        );
        
        // Mock response for now (would call actual OpenAI API)
        let mut categorizations = Vec::new();
        
        for transaction in &request.transactions {
            // Simple pattern matching as fallback
            let category = self.simple_pattern_match(&transaction.description, &request.categories);
            
            categorizations.push(AICategorization {
                transaction_id: transaction.id,
                original_description: transaction.description.clone(),
                category_id: category.as_ref().map(|c| c.id),
                category_name: category.map(|c| c.name),
                confidence: Decimal::from_str("0.8").unwrap(),
                reasoning: Some("Pattern matched".to_string()),
            });
        }
        
        Ok(AICategorizeResponse {
            success: true,
            categorizations,
            error: None,
        })
    }
    
    async fn call_openai_chat(
        &self,
        request: ChatRequest,
    ) -> Result<ChatAIResponse, DomainError> {
        // Mock implementation - would call actual OpenAI API
        Ok(ChatAIResponse {
            content: "I'm here to help with your financial questions!".to_string(),
            function_calls: None,
        })
    }
    
    // Simple pattern matching fallback
    fn simple_pattern_match(
        &self,
        description: &str,
        categories: &[CategoryForAI],
    ) -> Option<CategoryForAI> {
        let desc_lower = description.to_lowercase();
        
        // Common patterns
        let patterns = vec![
            ("grocery", "Groceries"),
            ("supermarket", "Groceries"),
            ("restaurant", "Dining"),
            ("coffee", "Dining"),
            ("gas", "Transportation"),
            ("uber", "Transportation"),
            ("netflix", "Entertainment"),
            ("amazon", "Shopping"),
            ("pharmacy", "Healthcare"),
            ("rent", "Housing"),
            ("mortgage", "Housing"),
            ("electric", "Utilities"),
        ];
        
        for (pattern, category_name) in patterns {
            if desc_lower.contains(pattern) {
                if let Some(category) = categories.iter().find(|c| c.name == category_name) {
                    return Some(category.clone());
                }
            }
        }
        
        None
    }
    
    async fn create_chat(&self, user_id: Uuid) -> Result<Uuid, DomainError> {
        let chat_id = Uuid::new_v4();
        
        sqlx::query!(
            r#"
            INSERT INTO chats (id, user_id, title, is_active, created_at, updated_at)
            VALUES ($1, $2, 'New Chat', true, $3, $3)
            "#,
            chat_id,
            user_id,
            Utc::now()
        )
        .execute(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(chat_id)
    }
    
    async fn save_message(
        &self,
        chat_id: Uuid,
        role: MessageRole,
        content: String,
        ai_model: String,
    ) -> Result<AssistantMessage, DomainError> {
        let message = sqlx::query_as!(
            AssistantMessage,
            r#"
            INSERT INTO assistant_messages (id, chat_id, role, content, ai_model, created_at, updated_at)
            VALUES ($1, $2, $3, $4, $5, $6, $6)
            RETURNING *
            "#,
            Uuid::new_v4(),
            chat_id,
            role as MessageRole,
            content,
            ai_model,
            Utc::now()
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(message)
    }
    
    async fn get_chat_context(&self, chat_id: Uuid) -> Result<ChatContext, DomainError> {
        let messages = sqlx::query_as!(
            AssistantMessage,
            r#"
            SELECT * FROM assistant_messages 
            WHERE chat_id = $1 
            ORDER BY created_at ASC
            LIMIT 20
            "#,
            chat_id
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(ChatContext { messages })
    }
    
    async fn get_user_family(&self, user_id: Uuid) -> Result<Uuid, DomainError> {
        let user = sqlx::query!(
            "SELECT family_id FROM users WHERE id = $1",
            user_id
        )
        .fetch_one(&*self.pool)
        .await
        .map_err(|e| DomainError::Database(e.to_string()))?;
        
        Ok(user.family_id)
    }
}

// DTOs

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionForAI {
    pub id: Uuid,
    pub description: String,
    pub amount: Decimal,
    pub currency: String,
    pub merchant_name: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryForAI {
    pub id: Uuid,
    pub name: String,
    pub classification: String,
    pub is_subcategory: bool,
    pub parent_id: Option<Uuid>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AICategorizeRequest {
    pub transactions: Vec<TransactionForAI>,
    pub categories: Vec<CategoryForAI>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AICategorizeResponse {
    pub success: bool,
    pub categorizations: Vec<AICategorization>,
    pub error: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AICategorization {
    pub transaction_id: Uuid,
    pub original_description: String,
    pub category_id: Option<Uuid>,
    pub category_name: Option<String>,
    pub confidence: Decimal,
    pub reasoning: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatRequest {
    pub messages: Vec<AssistantMessage>,
    pub functions: Vec<FunctionDefinition>,
    pub model: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatResponse {
    pub chat_id: Uuid,
    pub message_id: Uuid,
    pub content: String,
    pub function_calls: Option<Vec<FunctionCall>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatAIResponse {
    pub content: String,
    pub function_calls: Option<Vec<FunctionCall>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionDefinition {
    pub name: String,
    pub description: String,
    pub parameters: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FunctionCall {
    pub name: String,
    pub arguments: serde_json::Value,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChatContext {
    pub messages: Vec<AssistantMessage>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GetTransactionsArgs {
    pub limit: Option<i32>,
    pub days: Option<i32>,
}

use rust_decimal::prelude::FromStr;