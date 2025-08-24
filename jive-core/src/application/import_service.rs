//! Import service - 数据导入服务
//! 
//! 基于 Maybe 的导入功能转换而来，支持 CSV、Mint、QIF、OFX 等格式

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc, NaiveDate};
use rust_decimal::Decimal;
use uuid::Uuid;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::error::{JiveError, Result};
use crate::domain::{Account, Transaction, Category};
use super::{ServiceContext, ServiceResponse, BatchResult};

/// 导入格式
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum ImportFormat {
    CSV,        // 通用 CSV
    Mint,       // Mint 导出格式
    QIF,        // Quicken Interchange Format
    OFX,        // Open Financial Exchange
    JSON,       // JSON 格式
    Excel,      // Excel 表格
    Alipay,     // 支付宝账单
    WeChat,     // 微信账单
}

/// 导入状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum ImportStatus {
    Pending,     // 待处理
    Parsing,     // 解析中
    Validating,  // 验证中
    Mapping,     // 映射中
    Importing,   // 导入中
    Completed,   // 完成
    Failed,      // 失败
}

/// 导入配置
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ImportConfig {
    format: ImportFormat,
    date_format: String,
    decimal_separator: String,
    thousands_separator: String,
    encoding: String,
    skip_duplicates: bool,
    auto_categorize: bool,
    create_missing_categories: bool,
    create_missing_accounts: bool,
}

impl Default for ImportConfig {
    fn default() -> Self {
        Self {
            format: ImportFormat::CSV,
            date_format: "%Y-%m-%d".to_string(),
            decimal_separator: ".".to_string(),
            thousands_separator: ",".to_string(),
            encoding: "UTF-8".to_string(),
            skip_duplicates: true,
            auto_categorize: true,
            create_missing_categories: false,
            create_missing_accounts: false,
        }
    }
}

/// 字段映射
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldMapping {
    source_field: String,
    target_field: String,
    transform: Option<String>,
}

/// 导入模板
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ImportTemplate {
    id: String,
    name: String,
    format: ImportFormat,
    field_mappings: Vec<FieldMapping>,
    config: ImportConfig,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

/// 导入任务
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ImportTask {
    id: String,
    user_id: String,
    ledger_id: String,
    file_name: String,
    file_size: u64,
    format: ImportFormat,
    status: ImportStatus,
    total_rows: u32,
    processed_rows: u32,
    successful_rows: u32,
    failed_rows: u32,
    duplicate_rows: u32,
    error_messages: Vec<String>,
    started_at: DateTime<Utc>,
    completed_at: Option<DateTime<Utc>>,
}

/// 导入行
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportRow {
    row_number: u32,
    raw_data: HashMap<String, String>,
    parsed_data: Option<ParsedTransaction>,
    validation_errors: Vec<String>,
    status: ImportRowStatus,
}

/// 导入行状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ImportRowStatus {
    Pending,
    Valid,
    Invalid,
    Duplicate,
    Imported,
    Failed,
}

/// 解析后的交易
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ParsedTransaction {
    date: NaiveDate,
    description: String,
    amount: Decimal,
    account_name: Option<String>,
    category_name: Option<String>,
    payee: Option<String>,
    notes: Option<String>,
    tags: Vec<String>,
    reference_number: Option<String>,
}

/// CSV 解析器配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CsvParserConfig {
    delimiter: char,
    quote_char: char,
    has_header: bool,
    skip_rows: usize,
}

impl Default for CsvParserConfig {
    fn default() -> Self {
        Self {
            delimiter: ',',
            quote_char: '"',
            has_header: true,
            skip_rows: 0,
        }
    }
}

/// 导入结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ImportResult {
    task_id: String,
    status: ImportStatus,
    total_rows: u32,
    imported_rows: u32,
    failed_rows: u32,
    duplicate_rows: u32,
    created_accounts: Vec<String>,
    created_categories: Vec<String>,
    created_transactions: Vec<String>,
    errors: Vec<ImportError>,
}

/// 导入错误
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportError {
    row_number: u32,
    field: Option<String>,
    message: String,
}

/// 导入预览
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportPreview {
    format: ImportFormat,
    detected_columns: Vec<String>,
    sample_rows: Vec<HashMap<String, String>>,
    suggested_mappings: Vec<FieldMapping>,
    total_rows: u32,
}

/// 导入服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ImportService {}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl ImportService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }

    /// 预览导入文件
    #[wasm_bindgen]
    pub async fn preview_import(
        &self,
        file_data: Vec<u8>,
        format: ImportFormat,
        context: ServiceContext,
    ) -> ServiceResponse<ImportPreview> {
        let result = self._preview_import(file_data, format, context).await;
        result.into()
    }

    /// 开始导入任务
    #[wasm_bindgen]
    pub async fn start_import(
        &self,
        file_data: Vec<u8>,
        config: ImportConfig,
        mappings: Vec<FieldMapping>,
        context: ServiceContext,
    ) -> ServiceResponse<ImportTask> {
        let result = self._start_import(file_data, config, mappings, context).await;
        result.into()
    }

    /// 获取导入任务状态
    #[wasm_bindgen]
    pub async fn get_import_status(
        &self,
        task_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<ImportTask> {
        let result = self._get_import_status(task_id, context).await;
        result.into()
    }

    /// 取消导入任务
    #[wasm_bindgen]
    pub async fn cancel_import(
        &self,
        task_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._cancel_import(task_id, context).await;
        result.into()
    }

    /// 获取导入历史
    #[wasm_bindgen]
    pub async fn get_import_history(
        &self,
        limit: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ImportTask>> {
        let result = self._get_import_history(limit, context).await;
        result.into()
    }

    /// 保存导入模板
    #[wasm_bindgen]
    pub async fn save_import_template(
        &self,
        template: ImportTemplate,
        context: ServiceContext,
    ) -> ServiceResponse<ImportTemplate> {
        let result = self._save_import_template(template, context).await;
        result.into()
    }

    /// 获取导入模板
    #[wasm_bindgen]
    pub async fn get_import_templates(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ImportTemplate>> {
        let result = self._get_import_templates(context).await;
        result.into()
    }

    /// 删除导入模板
    #[wasm_bindgen]
    pub async fn delete_import_template(
        &self,
        template_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._delete_import_template(template_id, context).await;
        result.into()
    }

    /// 验证导入数据
    #[wasm_bindgen]
    pub async fn validate_import_data(
        &self,
        rows: Vec<ImportRow>,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ImportRow>> {
        let result = self._validate_import_data(rows, context).await;
        result.into()
    }

    /// 执行导入
    #[wasm_bindgen]
    pub async fn execute_import(
        &self,
        task_id: String,
        rows: Vec<ImportRow>,
        context: ServiceContext,
    ) -> ServiceResponse<ImportResult> {
        let result = self._execute_import(task_id, rows, context).await;
        result.into()
    }
}

impl ImportService {
    /// 预览导入文件的内部实现
    async fn _preview_import(
        &self,
        file_data: Vec<u8>,
        format: ImportFormat,
        _context: ServiceContext,
    ) -> Result<ImportPreview> {
        let content = String::from_utf8(file_data)
            .map_err(|_| JiveError::ValidationError {
                message: "Invalid file encoding".to_string(),
            })?;

        match format {
            ImportFormat::CSV => self.preview_csv(content),
            ImportFormat::Mint => self.preview_mint(content),
            ImportFormat::JSON => self.preview_json(content),
            _ => Err(JiveError::ValidationError {
                message: format!("Unsupported import format: {:?}", format),
            }),
        }
    }

    /// 预览 CSV 文件
    fn preview_csv(&self, content: String) -> Result<ImportPreview> {
        let lines: Vec<&str> = content.lines().collect();
        if lines.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Empty CSV file".to_string(),
            });
        }

        // 检测列
        let headers: Vec<String> = lines[0]
            .split(',')
            .map(|s| s.trim().to_string())
            .collect();

        // 获取示例行
        let mut sample_rows = Vec::new();
        for line in lines.iter().skip(1).take(5) {
            let values: Vec<&str> = line.split(',').collect();
            let mut row = HashMap::new();
            for (i, header) in headers.iter().enumerate() {
                if let Some(value) = values.get(i) {
                    row.insert(header.clone(), value.trim().to_string());
                }
            }
            sample_rows.push(row);
        }

        // 建议映射
        let suggested_mappings = self.suggest_field_mappings(&headers);

        Ok(ImportPreview {
            format: ImportFormat::CSV,
            detected_columns: headers,
            sample_rows,
            suggested_mappings,
            total_rows: (lines.len() - 1) as u32,
        })
    }

    /// 预览 Mint 格式
    fn preview_mint(&self, content: String) -> Result<ImportPreview> {
        // Mint 格式有特定的列
        self.preview_csv(content)
    }

    /// 预览 JSON 格式
    fn preview_json(&self, content: String) -> Result<ImportPreview> {
        let data: Vec<HashMap<String, String>> = serde_json::from_str(&content)
            .map_err(|e| JiveError::ValidationError {
                message: format!("Invalid JSON: {}", e),
            })?;

        if data.is_empty() {
            return Err(JiveError::ValidationError {
                message: "Empty JSON file".to_string(),
            });
        }

        let headers: Vec<String> = data[0].keys().cloned().collect();
        let sample_rows = data.iter().take(5).cloned().collect();

        Ok(ImportPreview {
            format: ImportFormat::JSON,
            detected_columns: headers.clone(),
            sample_rows,
            suggested_mappings: self.suggest_field_mappings(&headers),
            total_rows: data.len() as u32,
        })
    }

    /// 建议字段映射
    fn suggest_field_mappings(&self, headers: &[String]) -> Vec<FieldMapping> {
        let mut mappings = Vec::new();

        for header in headers {
            let lower = header.to_lowercase();
            let target_field = if lower.contains("date") {
                "date"
            } else if lower.contains("description") || lower.contains("memo") {
                "description"
            } else if lower.contains("amount") || lower.contains("value") {
                "amount"
            } else if lower.contains("category") {
                "category"
            } else if lower.contains("account") {
                "account"
            } else if lower.contains("payee") || lower.contains("merchant") {
                "payee"
            } else if lower.contains("note") || lower.contains("comment") {
                "notes"
            } else if lower.contains("tag") {
                "tags"
            } else {
                continue;
            };

            mappings.push(FieldMapping {
                source_field: header.clone(),
                target_field: target_field.to_string(),
                transform: None,
            });
        }

        mappings
    }

    /// 开始导入任务的内部实现
    async fn _start_import(
        &self,
        file_data: Vec<u8>,
        config: ImportConfig,
        mappings: Vec<FieldMapping>,
        context: ServiceContext,
    ) -> Result<ImportTask> {
        let task = ImportTask {
            id: Uuid::new_v4().to_string(),
            user_id: context.user_id.clone(),
            ledger_id: context.current_ledger_id.unwrap_or_default(),
            file_name: "import.csv".to_string(),
            file_size: file_data.len() as u64,
            format: config.format.clone(),
            status: ImportStatus::Parsing,
            total_rows: 0,
            processed_rows: 0,
            successful_rows: 0,
            failed_rows: 0,
            duplicate_rows: 0,
            error_messages: Vec::new(),
            started_at: Utc::now(),
            completed_at: None,
        };

        // 解析文件
        let rows = self.parse_file(file_data, &config, &mappings)?;

        // 在实际实现中，这里会：
        // 1. 保存任务到数据库
        // 2. 启动异步导入进程
        // 3. 返回任务ID供跟踪

        Ok(task)
    }

    /// 解析文件
    fn parse_file(
        &self,
        file_data: Vec<u8>,
        config: &ImportConfig,
        mappings: &[FieldMapping],
    ) -> Result<Vec<ImportRow>> {
        let content = String::from_utf8(file_data)
            .map_err(|_| JiveError::ValidationError {
                message: "Invalid file encoding".to_string(),
            })?;

        match config.format {
            ImportFormat::CSV => self.parse_csv(content, config, mappings),
            ImportFormat::JSON => self.parse_json(content, mappings),
            _ => Err(JiveError::ValidationError {
                message: "Unsupported format".to_string(),
            }),
        }
    }

    /// 解析 CSV
    fn parse_csv(
        &self,
        content: String,
        config: &ImportConfig,
        mappings: &[FieldMapping],
    ) -> Result<Vec<ImportRow>> {
        let mut rows = Vec::new();
        let lines: Vec<&str> = content.lines().collect();
        
        if lines.is_empty() {
            return Ok(rows);
        }

        let headers: Vec<String> = lines[0]
            .split(',')
            .map(|s| s.trim().to_string())
            .collect();

        for (index, line) in lines.iter().skip(1).enumerate() {
            let values: Vec<&str> = line.split(',').collect();
            let mut raw_data = HashMap::new();
            
            for (i, header) in headers.iter().enumerate() {
                if let Some(value) = values.get(i) {
                    raw_data.insert(header.clone(), value.trim().to_string());
                }
            }

            let parsed_data = self.parse_transaction(&raw_data, mappings, config)?;

            rows.push(ImportRow {
                row_number: (index + 2) as u32,
                raw_data,
                parsed_data: Some(parsed_data),
                validation_errors: Vec::new(),
                status: ImportRowStatus::Pending,
            });
        }

        Ok(rows)
    }

    /// 解析 JSON
    fn parse_json(
        &self,
        content: String,
        mappings: &[FieldMapping],
    ) -> Result<Vec<ImportRow>> {
        let data: Vec<HashMap<String, String>> = serde_json::from_str(&content)
            .map_err(|e| JiveError::ValidationError {
                message: format!("Invalid JSON: {}", e),
            })?;

        let config = ImportConfig::default();
        let mut rows = Vec::new();

        for (index, item) in data.iter().enumerate() {
            let parsed_data = self.parse_transaction(item, mappings, &config)?;

            rows.push(ImportRow {
                row_number: (index + 1) as u32,
                raw_data: item.clone(),
                parsed_data: Some(parsed_data),
                validation_errors: Vec::new(),
                status: ImportRowStatus::Pending,
            });
        }

        Ok(rows)
    }

    /// 解析交易
    fn parse_transaction(
        &self,
        raw_data: &HashMap<String, String>,
        mappings: &[FieldMapping],
        config: &ImportConfig,
    ) -> Result<ParsedTransaction> {
        let mut transaction = ParsedTransaction {
            date: NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
            description: String::new(),
            amount: Decimal::ZERO,
            account_name: None,
            category_name: None,
            payee: None,
            notes: None,
            tags: Vec::new(),
            reference_number: None,
        };

        for mapping in mappings {
            if let Some(value) = raw_data.get(&mapping.source_field) {
                match mapping.target_field.as_str() {
                    "date" => {
                        // 解析日期
                        if let Ok(date) = NaiveDate::parse_from_str(value, &config.date_format) {
                            transaction.date = date;
                        }
                    }
                    "description" => transaction.description = value.clone(),
                    "amount" => {
                        // 解析金额
                        let cleaned = value
                            .replace(&config.thousands_separator, "")
                            .replace(&config.decimal_separator, ".");
                        if let Ok(amount) = cleaned.parse::<Decimal>() {
                            transaction.amount = amount;
                        }
                    }
                    "category" => transaction.category_name = Some(value.clone()),
                    "account" => transaction.account_name = Some(value.clone()),
                    "payee" => transaction.payee = Some(value.clone()),
                    "notes" => transaction.notes = Some(value.clone()),
                    "tags" => {
                        transaction.tags = value
                            .split(',')
                            .map(|s| s.trim().to_string())
                            .collect();
                    }
                    _ => {}
                }
            }
        }

        Ok(transaction)
    }

    /// 获取导入状态的内部实现
    async fn _get_import_status(
        &self,
        task_id: String,
        _context: ServiceContext,
    ) -> Result<ImportTask> {
        // 在实际实现中，从数据库获取任务状态
        Ok(ImportTask {
            id: task_id,
            user_id: "user-123".to_string(),
            ledger_id: "ledger-456".to_string(),
            file_name: "import.csv".to_string(),
            file_size: 1024,
            format: ImportFormat::CSV,
            status: ImportStatus::Completed,
            total_rows: 100,
            processed_rows: 100,
            successful_rows: 95,
            failed_rows: 5,
            duplicate_rows: 0,
            error_messages: Vec::new(),
            started_at: Utc::now() - chrono::Duration::minutes(5),
            completed_at: Some(Utc::now()),
        })
    }

    /// 取消导入的内部实现
    async fn _cancel_import(
        &self,
        _task_id: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 在实际实现中，取消正在进行的导入任务
        Ok(true)
    }

    /// 获取导入历史的内部实现
    async fn _get_import_history(
        &self,
        limit: u32,
        context: ServiceContext,
    ) -> Result<Vec<ImportTask>> {
        // 在实际实现中，从数据库获取导入历史
        let history = vec![
            ImportTask {
                id: Uuid::new_v4().to_string(),
                user_id: context.user_id.clone(),
                ledger_id: "ledger-456".to_string(),
                file_name: "transactions_2024.csv".to_string(),
                file_size: 10240,
                format: ImportFormat::CSV,
                status: ImportStatus::Completed,
                total_rows: 500,
                processed_rows: 500,
                successful_rows: 495,
                failed_rows: 5,
                duplicate_rows: 10,
                error_messages: Vec::new(),
                started_at: Utc::now() - chrono::Duration::days(1),
                completed_at: Some(Utc::now() - chrono::Duration::days(1) + chrono::Duration::minutes(2)),
            },
        ];

        Ok(history.into_iter().take(limit as usize).collect())
    }

    /// 保存导入模板的内部实现
    async fn _save_import_template(
        &self,
        mut template: ImportTemplate,
        _context: ServiceContext,
    ) -> Result<ImportTemplate> {
        template.id = Uuid::new_v4().to_string();
        template.created_at = Utc::now();
        template.updated_at = Utc::now();

        // 在实际实现中，保存到数据库
        Ok(template)
    }

    /// 获取导入模板的内部实现
    async fn _get_import_templates(
        &self,
        _context: ServiceContext,
    ) -> Result<Vec<ImportTemplate>> {
        // 在实际实现中，从数据库获取模板
        Ok(Vec::new())
    }

    /// 删除导入模板的内部实现
    async fn _delete_import_template(
        &self,
        _template_id: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 在实际实现中，从数据库删除模板
        Ok(true)
    }

    /// 验证导入数据的内部实现
    async fn _validate_import_data(
        &self,
        mut rows: Vec<ImportRow>,
        _context: ServiceContext,
    ) -> Result<Vec<ImportRow>> {
        for row in &mut rows {
            if let Some(ref parsed) = row.parsed_data {
                // 验证必填字段
                if parsed.description.is_empty() {
                    row.validation_errors.push("Description is required".to_string());
                }

                if parsed.amount == Decimal::ZERO {
                    row.validation_errors.push("Amount cannot be zero".to_string());
                }

                // 设置状态
                row.status = if row.validation_errors.is_empty() {
                    ImportRowStatus::Valid
                } else {
                    ImportRowStatus::Invalid
                };
            }
        }

        Ok(rows)
    }

    /// 执行导入的内部实现
    async fn _execute_import(
        &self,
        task_id: String,
        rows: Vec<ImportRow>,
        context: ServiceContext,
    ) -> Result<ImportResult> {
        let mut imported_rows = 0;
        let mut failed_rows = 0;
        let mut duplicate_rows = 0;
        let mut errors = Vec::new();
        let mut created_transactions = Vec::new();

        for row in rows {
            if row.status != ImportRowStatus::Valid {
                failed_rows += 1;
                errors.push(ImportError {
                    row_number: row.row_number,
                    field: None,
                    message: row.validation_errors.join(", "),
                });
                continue;
            }

            // 在实际实现中，这里会创建交易
            if let Some(parsed) = row.parsed_data {
                // 检查重复
                if self.is_duplicate(&parsed, &context).await? {
                    duplicate_rows += 1;
                    continue;
                }

                // 创建交易
                match self.create_transaction_from_parsed(parsed, &context).await {
                    Ok(transaction_id) => {
                        imported_rows += 1;
                        created_transactions.push(transaction_id);
                    }
                    Err(e) => {
                        failed_rows += 1;
                        errors.push(ImportError {
                            row_number: row.row_number,
                            field: None,
                            message: e.to_string(),
                        });
                    }
                }
            }
        }

        Ok(ImportResult {
            task_id,
            status: if failed_rows == 0 {
                ImportStatus::Completed
            } else {
                ImportStatus::Failed
            },
            total_rows: rows.len() as u32,
            imported_rows,
            failed_rows,
            duplicate_rows,
            created_accounts: Vec::new(),
            created_categories: Vec::new(),
            created_transactions,
            errors,
        })
    }

    /// 检查是否重复
    async fn is_duplicate(&self, _parsed: &ParsedTransaction, _context: &ServiceContext) -> Result<bool> {
        // 在实际实现中，检查数据库中是否存在相同的交易
        Ok(false)
    }

    /// 从解析数据创建交易
    async fn create_transaction_from_parsed(
        &self,
        _parsed: ParsedTransaction,
        _context: &ServiceContext,
    ) -> Result<String> {
        // 在实际实现中，创建交易并返回ID
        Ok(Uuid::new_v4().to_string())
    }
}

impl Default for ImportService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_csv_preview() {
        let service = ImportService::new();
        let csv_content = "Date,Description,Amount,Category\n2024-01-01,Test Transaction,-50.00,Food".to_string();
        
        let preview = service.preview_csv(csv_content);
        assert!(preview.is_ok());
        
        let preview = preview.unwrap();
        assert_eq!(preview.detected_columns.len(), 4);
        assert_eq!(preview.total_rows, 1);
    }

    #[test]
    fn test_field_mapping_suggestions() {
        let service = ImportService::new();
        let headers = vec![
            "Transaction Date".to_string(),
            "Description".to_string(),
            "Amount".to_string(),
            "Category Name".to_string(),
        ];

        let mappings = service.suggest_field_mappings(&headers);
        assert!(!mappings.is_empty());
        assert!(mappings.iter().any(|m| m.target_field == "date"));
        assert!(mappings.iter().any(|m| m.target_field == "description"));
        assert!(mappings.iter().any(|m| m.target_field == "amount"));
        assert!(mappings.iter().any(|m| m.target_field == "category"));
    }

    #[test]
    fn test_import_config_default() {
        let config = ImportConfig::default();
        assert_eq!(config.format, ImportFormat::CSV);
        assert_eq!(config.date_format, "%Y-%m-%d");
        assert_eq!(config.decimal_separator, ".");
        assert!(config.skip_duplicates);
    }
}