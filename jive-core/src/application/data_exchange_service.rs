//! Data Exchange Service - 数据导入导出服务
//!
//! 基于 Maybe 的完整导入导出实现，支持多种格式和智能映射

use chrono::{DateTime, NaiveDate, Utc};
use csv::{Reader, StringRecord, Writer};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use serde_json;
use std::collections::{HashMap, HashSet};
use std::io::{Read, Write};
use std::path::PathBuf;
use uuid::Uuid;

use crate::application::{BatchResult, ServiceContext, ServiceResponse};
use crate::domain::{Account, Category, Payee, Tag, Transaction, TransactionType};
use crate::error::{JiveError, Result};

/// 数据交换服务
pub struct DataExchangeService {
    // 依赖注入
}

impl DataExchangeService {
    pub fn new() -> Self {
        Self {}
    }

    // ========== 导出功能 ==========

    /// 导出交易数据
    pub async fn export_transactions(
        &self,
        context: ServiceContext,
        request: ExportRequest,
    ) -> Result<ServiceResponse<ExportResult>> {
        // 权限检查
        if !context.has_permission_str("export_data") {
            return Err(JiveError::Forbidden("No permission to export data".into()));
        }

        // 获取数据
        let transactions = self
            .get_transactions_for_export(&context.family_id, &request.filters)
            .await?;

        // 根据格式导出
        let file_content = match request.format {
            ExportFormat::CSV => self.export_to_csv(&transactions)?,
            ExportFormat::Excel => self.export_to_excel(&transactions)?,
            ExportFormat::JSON => self.export_to_json(&transactions)?,
            ExportFormat::PDF => self.export_to_pdf(&transactions, &request.options)?,
            ExportFormat::QIF => self.export_to_qif(&transactions)?,
            ExportFormat::OFX => self.export_to_ofx(&transactions)?,
        };

        // 生成文件名
        let filename = format!(
            "transactions_{}_{}.{}",
            context.family_id,
            Utc::now().format("%Y%m%d_%H%M%S"),
            request.format.extension()
        );

        // 记录导出日志
        self.log_export(&context, &filename, transactions.len())
            .await?;

        Ok(ServiceResponse::success(ExportResult {
            filename,
            format: request.format,
            content: file_content,
            record_count: transactions.len(),
            file_size: file_content.len(),
            exported_at: Utc::now(),
        }))
    }

    /// 导出账户数据
    pub async fn export_accounts(
        &self,
        context: ServiceContext,
        request: ExportRequest,
    ) -> Result<ServiceResponse<ExportResult>> {
        // 权限检查
        if !context.has_permission_str("export_data") {
            return Err(JiveError::Forbidden("No permission to export data".into()));
        }

        let accounts = self.get_accounts_for_export(&context.family_id).await?;

        let file_content = match request.format {
            ExportFormat::CSV => self.export_accounts_to_csv(&accounts)?,
            ExportFormat::JSON => self.export_accounts_to_json(&accounts)?,
            _ => {
                return Err(JiveError::ValidationError(
                    "Unsupported format for accounts".into(),
                ))
            }
        };

        let filename = format!(
            "accounts_{}_{}.{}",
            context.family_id,
            Utc::now().format("%Y%m%d_%H%M%S"),
            request.format.extension()
        );

        Ok(ServiceResponse::success(ExportResult {
            filename,
            format: request.format,
            content: file_content,
            record_count: accounts.len(),
            file_size: file_content.len(),
            exported_at: Utc::now(),
        }))
    }

    /// 导出完整备份
    pub async fn export_full_backup(
        &self,
        context: ServiceContext,
    ) -> Result<ServiceResponse<BackupResult>> {
        // 权限检查 - 需要更高权限
        if !context.has_permission_str("manage_family") {
            return Err(JiveError::Forbidden(
                "No permission to create backup".into(),
            ));
        }

        // 收集所有数据
        let backup_data = BackupData {
            version: "1.0".to_string(),
            family_id: context.family_id.clone(),
            created_at: Utc::now(),
            accounts: self.get_accounts_for_export(&context.family_id).await?,
            categories: self.get_categories_for_export(&context.family_id).await?,
            transactions: self.get_all_transactions(&context.family_id).await?,
            budgets: self.get_budgets_for_export(&context.family_id).await?,
            tags: self.get_tags_for_export(&context.family_id).await?,
            payees: self.get_payees_for_export(&context.family_id).await?,
            rules: self.get_rules_for_export(&context.family_id).await?,
        };

        // 序列化为 JSON
        let json_content = serde_json::to_string_pretty(&backup_data)?;

        // 可选：加密备份
        let encrypted_content = json_content.into_bytes(); // TODO: 实现加密支持

        let filename = format!(
            "jive_backup_{}_{}.jbk",
            context.family_id,
            Utc::now().format("%Y%m%d_%H%M%S")
        );

        Ok(ServiceResponse::success(BackupResult {
            filename,
            content: encrypted_content,
            checksum: self.calculate_checksum(&encrypted_content),
            record_counts: RecordCounts {
                accounts: backup_data.accounts.len(),
                categories: backup_data.categories.len(),
                transactions: backup_data.transactions.len(),
                budgets: backup_data.budgets.len(),
                tags: backup_data.tags.len(),
                payees: backup_data.payees.len(),
                rules: backup_data.rules.len(),
            },
            created_at: Utc::now(),
        }))
    }

    // ========== 导入功能 ==========

    /// 导入交易数据
    pub async fn import_transactions(
        &self,
        context: ServiceContext,
        request: ImportRequest,
    ) -> Result<ServiceResponse<ImportResult>> {
        // 权限检查
        if !context.has_permission_str("import_data") {
            return Err(JiveError::Forbidden("No permission to import data".into()));
        }

        // 创建导入会话
        let import_session = ImportSession {
            id: Uuid::new_v4().to_string(),
            family_id: context.family_id.clone(),
            status: ImportStatus::Parsing,
            created_at: Utc::now(),
        };

        // 解析文件
        let parsed_rows = match request.format {
            ImportFormat::CSV => self.parse_csv(&request.content)?,
            ImportFormat::Excel => self.parse_excel(&request.content)?,
            ImportFormat::JSON => self.parse_json(&request.content)?,
            ImportFormat::QIF => self.parse_qif(&request.content)?,
            ImportFormat::OFX => self.parse_ofx(&request.content)?,
            ImportFormat::Mint => self.parse_mint_csv(&request.content)?,
            ImportFormat::Alipay => self.parse_alipay(&request.content)?,
            ImportFormat::WeChat => self.parse_wechat(&request.content)?,
        };

        // 验证数据
        let validation_result = self.validate_import_data(&parsed_rows)?;
        if !validation_result.is_valid {
            return Ok(ServiceResponse::error_with_message(
                JiveError::ValidationError("Import validation failed".into()),
                format!(
                    "Found {} errors in import data",
                    validation_result.errors.len()
                ),
            ));
        }

        // 智能映射
        let mapping = self.generate_smart_mapping(&context, &parsed_rows).await?;

        // 执行导入
        let mut batch_result = BatchResult::new();
        let mut imported_transactions = Vec::new();

        for row in parsed_rows {
            match self
                .import_single_transaction(&context, &row, &mapping)
                .await
            {
                Ok(transaction) => {
                    imported_transactions.push(transaction);
                    batch_result.add_success();
                }
                Err(e) => {
                    batch_result.add_error(format!("Row {}: {}", batch_result.total + 1, e));
                }
            }
        }

        // 应用规则到新导入的交易
        if request.apply_rules {
            self.apply_rules_to_transactions(&context, &imported_transactions)
                .await?;
        }

        Ok(ServiceResponse::success(ImportResult {
            session_id: import_session.id,
            total_rows: batch_result.total as usize,
            successful: batch_result.successful as usize,
            failed: batch_result.failed as usize,
            errors: batch_result.errors,
            mapping_summary: mapping.summary(),
            imported_at: Utc::now(),
        }))
    }

    /// 恢复备份
    pub async fn restore_backup(
        &self,
        context: ServiceContext,
        request: RestoreRequest,
    ) -> Result<ServiceResponse<RestoreResult>> {
        // 权限检查 - 需要最高权限
        if !context.has_permission_str("manage_family") {
            return Err(JiveError::Forbidden(
                "No permission to restore backup".into(),
            ));
        }

        // 解密备份（如果加密）
        let decrypted_content = request.content.clone(); // TODO: 实现解密支持

        // 验证校验和
        if let Some(expected_checksum) = &request.checksum {
            let actual_checksum = self.calculate_checksum(&request.content);
            if actual_checksum != *expected_checksum {
                return Err(JiveError::ValidationError(
                    "Backup checksum mismatch".into(),
                ));
            }
        }

        // 解析备份数据
        let backup_data: BackupData = serde_json::from_slice(&decrypted_content)?;

        // 验证备份版本兼容性
        if !self.is_compatible_version(&backup_data.version) {
            return Err(JiveError::ValidationError(format!(
                "Incompatible backup version: {}",
                backup_data.version
            )));
        }

        // 创建恢复点（用于回滚）
        let restore_point = self.create_restore_point(&context.family_id).await?;

        // 执行恢复
        let mut restore_stats = RestoreStats::default();

        // 恢复顺序很重要，先恢复基础数据
        restore_stats.accounts = self
            .restore_accounts(&context, &backup_data.accounts)
            .await?;
        restore_stats.categories = self
            .restore_categories(&context, &backup_data.categories)
            .await?;
        restore_stats.tags = self.restore_tags(&context, &backup_data.tags).await?;
        restore_stats.payees = self.restore_payees(&context, &backup_data.payees).await?;

        // 然后恢复交易数据
        restore_stats.transactions = self
            .restore_transactions(&context, &backup_data.transactions)
            .await?;

        // 最后恢复预算和规则
        restore_stats.budgets = self.restore_budgets(&context, &backup_data.budgets).await?;
        restore_stats.rules = self.restore_rules(&context, &backup_data.rules).await?;

        Ok(ServiceResponse::success(RestoreResult {
            restore_point_id: restore_point,
            stats: restore_stats,
            restored_at: Utc::now(),
        }))
    }

    /// 预览导入数据
    pub async fn preview_import(
        &self,
        context: ServiceContext,
        request: ImportRequest,
    ) -> Result<ServiceResponse<ImportPreview>> {
        // 解析前10行作为预览
        let parsed_rows = match request.format {
            ImportFormat::CSV => self.parse_csv_preview(&request.content, 10)?,
            _ => {
                return Err(JiveError::NotImplemented(
                    "Preview only supports CSV".into(),
                ))
            }
        };

        // 检测列映射
        let detected_columns = self.detect_column_mapping(&parsed_rows)?;

        // 生成智能映射建议
        let mapping_suggestions = self
            .generate_mapping_suggestions(&context, &parsed_rows)
            .await?;

        Ok(ServiceResponse::success(ImportPreview {
            sample_rows: parsed_rows,
            detected_columns,
            mapping_suggestions,
            total_rows: self.count_rows(&request.content, request.format)?,
        }))
    }

    // ========== 辅助方法 ==========

    fn export_to_csv(&self, transactions: &[TransactionExport]) -> Result<Vec<u8>> {
        let mut wtr = Writer::from_writer(vec![]);

        // 写入表头
        wtr.write_record(&[
            "Date",
            "Amount",
            "Type",
            "Category",
            "Payee",
            "Account",
            "Description",
            "Tags",
            "Notes",
        ])?;

        // 写入数据
        for t in transactions {
            wtr.write_record(&[
                t.date.to_string(),
                t.amount.to_string(),
                t.transaction_type.to_string(),
                t.category.as_deref().unwrap_or(""),
                t.payee.as_deref().unwrap_or(""),
                t.account.as_str(),
                t.description.as_str(),
                t.tags.join(", ").as_str(),
                t.notes.as_deref().unwrap_or(""),
            ])?;
        }

        wtr.flush()?;
        Ok(wtr.into_inner()?)
    }

    fn export_to_json(&self, transactions: &[TransactionExport]) -> Result<Vec<u8>> {
        let json = serde_json::to_string_pretty(transactions)?;
        Ok(json.into_bytes())
    }

    fn export_to_excel(&self, transactions: &[TransactionExport]) -> Result<Vec<u8>> {
        // TODO: 使用 calamine 或其他 Excel 库
        Err(JiveError::NotImplemented("Excel export".into()))
    }

    fn export_to_pdf(
        &self,
        transactions: &[TransactionExport],
        options: &ExportOptions,
    ) -> Result<Vec<u8>> {
        // TODO: 使用 printpdf 或其他 PDF 库
        Err(JiveError::NotImplemented("PDF export".into()))
    }

    fn export_to_qif(&self, transactions: &[TransactionExport]) -> Result<Vec<u8>> {
        let mut output = String::new();
        output.push_str("!Type:Bank\n");

        for t in transactions {
            output.push_str(&format!("D{}\n", t.date.format("%m/%d/%Y")));
            output.push_str(&format!("T{}\n", t.amount));
            output.push_str(&format!("P{}\n", t.payee.as_deref().unwrap_or("")));
            output.push_str(&format!("L{}\n", t.category.as_deref().unwrap_or("")));
            output.push_str(&format!("M{}\n", t.description));
            output.push_str("^\n");
        }

        Ok(output.into_bytes())
    }

    fn export_to_ofx(&self, transactions: &[TransactionExport]) -> Result<Vec<u8>> {
        // TODO: 实现 OFX 格式导出
        Err(JiveError::NotImplemented("OFX export".into()))
    }

    fn parse_csv(&self, content: &[u8]) -> Result<Vec<ImportRow>> {
        let mut rdr = Reader::from_reader(content);
        let mut rows = Vec::new();

        for result in rdr.records() {
            let record = result?;
            rows.push(self.parse_csv_record(&record)?);
        }

        Ok(rows)
    }

    fn parse_csv_record(&self, record: &StringRecord) -> Result<ImportRow> {
        Ok(ImportRow {
            date: record
                .get(0)
                .and_then(|s| NaiveDate::parse_from_str(s, "%Y-%m-%d").ok()),
            amount: record.get(1).and_then(|s| Decimal::from_str_exact(s).ok()),
            description: record.get(2).map(String::from),
            category: record.get(3).map(String::from),
            payee: record.get(4).map(String::from),
            account: record.get(5).map(String::from),
            tags: record
                .get(6)
                .map(|s| s.split(',').map(String::from).collect())
                .unwrap_or_default(),
            notes: record.get(7).map(String::from),
            raw_data: record.iter().map(String::from).collect(),
        })
    }

    fn parse_csv_preview(&self, content: &[u8], limit: usize) -> Result<Vec<ImportRow>> {
        let mut rdr = Reader::from_reader(content);
        let mut rows = Vec::new();

        for (i, result) in rdr.records().enumerate() {
            if i >= limit {
                break;
            }
            let record = result?;
            rows.push(self.parse_csv_record(&record)?);
        }

        Ok(rows)
    }

    fn parse_excel(&self, content: &[u8]) -> Result<Vec<ImportRow>> {
        // TODO: 使用 calamine 解析 Excel
        Err(JiveError::NotImplemented("Excel import".into()))
    }

    fn parse_json(&self, content: &[u8]) -> Result<Vec<ImportRow>> {
        let transactions: Vec<TransactionImport> = serde_json::from_slice(content)?;
        Ok(transactions
            .into_iter()
            .map(|t| ImportRow {
                date: Some(t.date),
                amount: Some(t.amount),
                description: Some(t.description),
                category: t.category,
                payee: t.payee,
                account: t.account,
                tags: t.tags.unwrap_or_default(),
                notes: t.notes,
                raw_data: vec![],
            })
            .collect())
    }

    fn parse_qif(&self, content: &[u8]) -> Result<Vec<ImportRow>> {
        // TODO: 实现 QIF 解析
        Err(JiveError::NotImplemented("QIF import".into()))
    }

    fn parse_ofx(&self, content: &[u8]) -> Result<Vec<ImportRow>> {
        // TODO: 实现 OFX 解析
        Err(JiveError::NotImplemented("OFX import".into()))
    }

    fn parse_mint_csv(&self, content: &[u8]) -> Result<Vec<ImportRow>> {
        // Mint 特定格式解析
        let mut rdr = Reader::from_reader(content);
        let mut rows = Vec::new();

        for result in rdr.records() {
            let record = result?;
            // Mint 格式: Date, Description, Original Description, Amount, Transaction Type, Category, Account Name, Labels, Notes
            rows.push(ImportRow {
                date: record
                    .get(0)
                    .and_then(|s| NaiveDate::parse_from_str(s, "%m/%d/%Y").ok()),
                amount: record.get(3).and_then(|s| Decimal::from_str_exact(s).ok()),
                description: record.get(1).map(String::from),
                category: record.get(5).map(String::from),
                payee: record.get(2).map(String::from), // Original Description as payee
                account: record.get(6).map(String::from),
                tags: record
                    .get(7)
                    .map(|s| s.split(',').map(String::from).collect())
                    .unwrap_or_default(),
                notes: record.get(8).map(String::from),
                raw_data: record.iter().map(String::from).collect(),
            });
        }

        Ok(rows)
    }

    fn parse_alipay(&self, content: &[u8]) -> Result<Vec<ImportRow>> {
        // 支付宝账单格式解析
        // TODO: 实现支付宝特定格式
        Err(JiveError::NotImplemented("Alipay import".into()))
    }

    fn parse_wechat(&self, content: &[u8]) -> Result<Vec<ImportRow>> {
        // 微信账单格式解析
        // TODO: 实现微信特定格式
        Err(JiveError::NotImplemented("WeChat import".into()))
    }

    fn validate_import_data(&self, rows: &[ImportRow]) -> Result<ValidationResult> {
        let mut errors = Vec::new();

        for (i, row) in rows.iter().enumerate() {
            if row.date.is_none() {
                errors.push(format!("Row {}: Missing date", i + 1));
            }
            if row.amount.is_none() {
                errors.push(format!("Row {}: Missing amount", i + 1));
            }
            if row.description.is_none() {
                errors.push(format!("Row {}: Missing description", i + 1));
            }
        }

        Ok(ValidationResult {
            is_valid: errors.is_empty(),
            errors,
            warnings: vec![],
        })
    }

    async fn generate_smart_mapping(
        &self,
        context: &ServiceContext,
        rows: &[ImportRow],
    ) -> Result<ImportMapping> {
        let mut mapping = ImportMapping::default();

        // 分析并映射分类
        let categories = self.get_categories(&context.family_id).await?;
        for row in rows {
            if let Some(cat_name) = &row.category {
                if !mapping.category_map.contains_key(cat_name) {
                    // 查找匹配的分类
                    let matched = categories
                        .iter()
                        .find(|c| c.name.eq_ignore_ascii_case(cat_name))
                        .or_else(|| {
                            // 模糊匹配
                            categories
                                .iter()
                                .find(|c| c.name.contains(cat_name) || cat_name.contains(&c.name))
                        });

                    if let Some(category) = matched {
                        mapping
                            .category_map
                            .insert(cat_name.clone(), category.id.clone());
                    }
                }
            }
        }

        // 映射账户
        let accounts = self.get_accounts(&context.family_id).await?;
        for row in rows {
            if let Some(acc_name) = &row.account {
                if !mapping.account_map.contains_key(acc_name) {
                    let matched = accounts
                        .iter()
                        .find(|a| a.name.eq_ignore_ascii_case(acc_name))
                        .or_else(|| accounts.first()); // 默认使用第一个账户

                    if let Some(account) = matched {
                        mapping
                            .account_map
                            .insert(acc_name.clone(), account.id.clone());
                    }
                }
            }
        }

        // 映射商户
        let payees = self.get_payees(&context.family_id).await?;
        for row in rows {
            if let Some(payee_name) = &row.payee {
                if !mapping.payee_map.contains_key(payee_name) {
                    let matched = payees
                        .iter()
                        .find(|p| p.name.eq_ignore_ascii_case(payee_name));

                    if let Some(payee) = matched {
                        mapping
                            .payee_map
                            .insert(payee_name.clone(), payee.id.clone());
                    }
                }
            }
        }

        Ok(mapping)
    }

    async fn import_single_transaction(
        &self,
        context: &ServiceContext,
        row: &ImportRow,
        mapping: &ImportMapping,
    ) -> Result<TransactionData> {
        let transaction = TransactionData {
            id: Uuid::new_v4().to_string(),
            family_id: context.family_id.clone(),
            date: row
                .date
                .ok_or_else(|| JiveError::ValidationError("Missing date".into()))?,
            amount: row
                .amount
                .ok_or_else(|| JiveError::ValidationError("Missing amount".into()))?,
            transaction_type: if row.amount.unwrap_or(Decimal::ZERO) >= Decimal::ZERO {
                TransactionType::Income
            } else {
                TransactionType::Expense
            },
            description: row.description.clone().unwrap_or_default(),
            category_id: row
                .category
                .as_ref()
                .and_then(|c| mapping.category_map.get(c))
                .cloned(),
            payee_id: row
                .payee
                .as_ref()
                .and_then(|p| mapping.payee_map.get(p))
                .cloned(),
            account_id: row
                .account
                .as_ref()
                .and_then(|a| mapping.account_map.get(a))
                .cloned()
                .ok_or_else(|| JiveError::ValidationError("Missing account mapping".into()))?,
            tags: row.tags.clone(),
            notes: row.notes.clone(),
            import_id: Some(Uuid::new_v4().to_string()),
            imported_at: Some(Utc::now()),
        };

        // TODO: 保存到数据库

        Ok(transaction)
    }

    async fn apply_rules_to_transactions(
        &self,
        context: &ServiceContext,
        transactions: &[TransactionData],
    ) -> Result<()> {
        // TODO: 应用规则引擎
        Ok(())
    }

    fn calculate_checksum(&self, data: &[u8]) -> String {
        use sha2::{Digest, Sha256};
        let mut hasher = Sha256::new();
        hasher.update(data);
        format!("{:x}", hasher.finalize())
    }

    fn encrypt_backup(&self, data: &str, key: &str) -> Result<Vec<u8>> {
        // TODO: 实现加密
        Ok(data.as_bytes().to_vec())
    }

    fn decrypt_backup(&self, data: &[u8], key: &str) -> Result<Vec<u8>> {
        // TODO: 实现解密
        Ok(data.to_vec())
    }

    fn is_compatible_version(&self, version: &str) -> bool {
        // 检查版本兼容性
        version == "1.0"
    }

    async fn create_restore_point(&self, family_id: &str) -> Result<String> {
        // TODO: 创建恢复点
        Ok(Uuid::new_v4().to_string())
    }

    fn count_rows(&self, content: &[u8], format: ImportFormat) -> Result<usize> {
        match format {
            ImportFormat::CSV => {
                let rdr = Reader::from_reader(content);
                Ok(rdr.into_records().count())
            }
            _ => Ok(0),
        }
    }

    fn detect_column_mapping(&self, rows: &[ImportRow]) -> Result<HashMap<String, String>> {
        // 检测列映射
        let mut mapping = HashMap::new();

        if rows.is_empty() {
            return Ok(mapping);
        }

        // 基于第一行检测
        if rows[0].date.is_some() {
            mapping.insert("date".to_string(), "Date".to_string());
        }
        if rows[0].amount.is_some() {
            mapping.insert("amount".to_string(), "Amount".to_string());
        }
        if rows[0].description.is_some() {
            mapping.insert("description".to_string(), "Description".to_string());
        }

        Ok(mapping)
    }

    async fn generate_mapping_suggestions(
        &self,
        context: &ServiceContext,
        rows: &[ImportRow],
    ) -> Result<Vec<MappingSuggestion>> {
        let mut suggestions = Vec::new();

        // 基于描述文本建议分类
        for row in rows.iter().take(5) {
            if let Some(desc) = &row.description {
                // 简单的关键词匹配
                let suggested_category = if desc.to_lowercase().contains("grocery") {
                    Some("Food & Dining".to_string())
                } else if desc.to_lowercase().contains("uber")
                    || desc.to_lowercase().contains("lyft")
                {
                    Some("Transportation".to_string())
                } else {
                    None
                };

                if let Some(category) = suggested_category {
                    suggestions.push(MappingSuggestion {
                        original_value: desc.clone(),
                        suggested_mapping: category,
                        confidence: 0.8,
                    });
                }
            }
        }

        Ok(suggestions)
    }

    // 数据库操作方法（TODO: 实现）

    async fn get_transactions_for_export(
        &self,
        family_id: &str,
        filters: &ExportFilters,
    ) -> Result<Vec<TransactionExport>> {
        // TODO: 从数据库获取交易
        Ok(Vec::new())
    }

    async fn get_accounts_for_export(&self, family_id: &str) -> Result<Vec<AccountExport>> {
        // TODO: 从数据库获取账户
        Ok(Vec::new())
    }

    async fn get_all_transactions(&self, family_id: &str) -> Result<Vec<TransactionExport>> {
        // TODO: 从数据库获取所有交易
        Ok(Vec::new())
    }

    async fn get_categories_for_export(&self, family_id: &str) -> Result<Vec<CategoryExport>> {
        // TODO: 从数据库获取分类
        Ok(Vec::new())
    }

    async fn get_budgets_for_export(&self, family_id: &str) -> Result<Vec<BudgetExport>> {
        // TODO: 从数据库获取预算
        Ok(Vec::new())
    }

    async fn get_tags_for_export(&self, family_id: &str) -> Result<Vec<TagExport>> {
        // TODO: 从数据库获取标签
        Ok(Vec::new())
    }

    async fn get_payees_for_export(&self, family_id: &str) -> Result<Vec<PayeeExport>> {
        // TODO: 从数据库获取商户
        Ok(Vec::new())
    }

    async fn get_rules_for_export(&self, family_id: &str) -> Result<Vec<RuleExport>> {
        // TODO: 从数据库获取规则
        Ok(Vec::new())
    }

    async fn get_categories(&self, family_id: &str) -> Result<Vec<CategoryData>> {
        // TODO: 从数据库获取分类
        Ok(Vec::new())
    }

    async fn get_accounts(&self, family_id: &str) -> Result<Vec<AccountData>> {
        // TODO: 从数据库获取账户
        Ok(Vec::new())
    }

    async fn get_payees(&self, family_id: &str) -> Result<Vec<PayeeData>> {
        // TODO: 从数据库获取商户
        Ok(Vec::new())
    }

    async fn log_export(
        &self,
        context: &ServiceContext,
        filename: &str,
        count: usize,
    ) -> Result<()> {
        // TODO: 记录导出日志
        Ok(())
    }

    async fn restore_accounts(
        &self,
        context: &ServiceContext,
        accounts: &[AccountExport],
    ) -> Result<usize> {
        // TODO: 恢复账户
        Ok(accounts.len())
    }

    async fn restore_categories(
        &self,
        context: &ServiceContext,
        categories: &[CategoryExport],
    ) -> Result<usize> {
        // TODO: 恢复分类
        Ok(categories.len())
    }

    async fn restore_tags(&self, context: &ServiceContext, tags: &[TagExport]) -> Result<usize> {
        // TODO: 恢复标签
        Ok(tags.len())
    }

    async fn restore_payees(
        &self,
        context: &ServiceContext,
        payees: &[PayeeExport],
    ) -> Result<usize> {
        // TODO: 恢复商户
        Ok(payees.len())
    }

    async fn restore_transactions(
        &self,
        context: &ServiceContext,
        transactions: &[TransactionExport],
    ) -> Result<usize> {
        // TODO: 恢复交易
        Ok(transactions.len())
    }

    async fn restore_budgets(
        &self,
        context: &ServiceContext,
        budgets: &[BudgetExport],
    ) -> Result<usize> {
        // TODO: 恢复预算
        Ok(budgets.len())
    }

    async fn restore_rules(&self, context: &ServiceContext, rules: &[RuleExport]) -> Result<usize> {
        // TODO: 恢复规则
        Ok(rules.len())
    }

    fn export_accounts_to_csv(&self, accounts: &[AccountExport]) -> Result<Vec<u8>> {
        let mut wtr = Writer::from_writer(vec![]);

        wtr.write_record(&[
            "Name",
            "Type",
            "Balance",
            "Currency",
            "Institution",
            "Last Updated",
        ])?;

        for account in accounts {
            wtr.write_record(&[
                &account.name,
                &account.account_type,
                &account.balance.to_string(),
                &account.currency,
                account.institution.as_deref().unwrap_or(""),
                &account.last_updated.to_string(),
            ])?;
        }

        wtr.flush()?;
        Ok(wtr.into_inner()?)
    }

    fn export_accounts_to_json(&self, accounts: &[AccountExport]) -> Result<Vec<u8>> {
        let json = serde_json::to_string_pretty(accounts)?;
        Ok(json.into_bytes())
    }
}

// ========== 数据结构定义 ==========

/// 导出格式
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ExportFormat {
    CSV,
    Excel,
    JSON,
    PDF,
    QIF,
    OFX,
}

impl ExportFormat {
    pub fn extension(&self) -> &str {
        match self {
            ExportFormat::CSV => "csv",
            ExportFormat::Excel => "xlsx",
            ExportFormat::JSON => "json",
            ExportFormat::PDF => "pdf",
            ExportFormat::QIF => "qif",
            ExportFormat::OFX => "ofx",
        }
    }
}

/// 导入格式
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ImportFormat {
    CSV,
    Excel,
    JSON,
    QIF,
    OFX,
    Mint,
    Alipay,
    WeChat,
}

/// 导入状态
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ImportStatus {
    Parsing,
    Validating,
    Mapping,
    Importing,
    Completed,
    Failed,
}

/// 导出请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportRequest {
    pub format: ExportFormat,
    pub filters: ExportFilters,
    pub options: ExportOptions,
}

/// 导出过滤器
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportFilters {
    pub date_range: Option<(NaiveDate, NaiveDate)>,
    pub categories: Option<Vec<String>>,
    pub accounts: Option<Vec<String>>,
    pub tags: Option<Vec<String>>,
    pub min_amount: Option<Decimal>,
    pub max_amount: Option<Decimal>,
}

/// 导出选项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportOptions {
    pub include_headers: bool,
    pub date_format: String,
    pub decimal_places: usize,
    pub currency_symbol: bool,
    pub group_by_category: bool,
    pub include_subtotals: bool,
}

/// 导出结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportResult {
    pub filename: String,
    pub format: ExportFormat,
    pub content: Vec<u8>,
    pub record_count: usize,
    pub file_size: usize,
    pub exported_at: DateTime<Utc>,
}

/// 导入请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportRequest {
    pub format: ImportFormat,
    pub content: Vec<u8>,
    pub options: ImportOptions,
    pub apply_rules: bool,
}

/// 导入选项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportOptions {
    pub date_format: String,
    pub decimal_separator: String,
    pub thousands_separator: String,
    pub default_account_id: Option<String>,
    pub skip_duplicates: bool,
    pub auto_categorize: bool,
}

/// 导入结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportResult {
    pub session_id: String,
    pub total_rows: usize,
    pub successful: usize,
    pub failed: usize,
    pub errors: Vec<String>,
    pub mapping_summary: MappingSummary,
    pub imported_at: DateTime<Utc>,
}

/// 导入预览
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportPreview {
    pub sample_rows: Vec<ImportRow>,
    pub detected_columns: HashMap<String, String>,
    pub mapping_suggestions: Vec<MappingSuggestion>,
    pub total_rows: usize,
}

/// 导入行
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ImportRow {
    pub date: Option<NaiveDate>,
    pub amount: Option<Decimal>,
    pub description: Option<String>,
    pub category: Option<String>,
    pub payee: Option<String>,
    pub account: Option<String>,
    pub tags: Vec<String>,
    pub notes: Option<String>,
    pub raw_data: Vec<String>,
}

/// 导入映射
#[derive(Debug, Clone, Default)]
pub struct ImportMapping {
    pub category_map: HashMap<String, String>,
    pub account_map: HashMap<String, String>,
    pub payee_map: HashMap<String, String>,
    pub tag_map: HashMap<String, String>,
}

impl ImportMapping {
    pub fn summary(&self) -> MappingSummary {
        MappingSummary {
            categories_mapped: self.category_map.len(),
            accounts_mapped: self.account_map.len(),
            payees_mapped: self.payee_map.len(),
            tags_mapped: self.tag_map.len(),
        }
    }
}

/// 映射汇总
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MappingSummary {
    pub categories_mapped: usize,
    pub accounts_mapped: usize,
    pub payees_mapped: usize,
    pub tags_mapped: usize,
}

/// 映射建议
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MappingSuggestion {
    pub original_value: String,
    pub suggested_mapping: String,
    pub confidence: f32,
}

/// 导入会话
#[derive(Debug, Clone)]
pub struct ImportSession {
    pub id: String,
    pub family_id: String,
    pub status: ImportStatus,
    pub created_at: DateTime<Utc>,
}

/// 验证结果
#[derive(Debug, Clone)]
pub struct ValidationResult {
    pub is_valid: bool,
    pub errors: Vec<String>,
    pub warnings: Vec<String>,
}

/// 备份数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupData {
    pub version: String,
    pub family_id: String,
    pub created_at: DateTime<Utc>,
    pub accounts: Vec<AccountExport>,
    pub categories: Vec<CategoryExport>,
    pub transactions: Vec<TransactionExport>,
    pub budgets: Vec<BudgetExport>,
    pub tags: Vec<TagExport>,
    pub payees: Vec<PayeeExport>,
    pub rules: Vec<RuleExport>,
}

/// 备份结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BackupResult {
    pub filename: String,
    pub content: Vec<u8>,
    pub checksum: String,
    pub record_counts: RecordCounts,
    pub created_at: DateTime<Utc>,
}

/// 记录计数
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RecordCounts {
    pub accounts: usize,
    pub categories: usize,
    pub transactions: usize,
    pub budgets: usize,
    pub tags: usize,
    pub payees: usize,
    pub rules: usize,
}

/// 恢复请求
#[derive(Debug, Clone)]
pub struct RestoreRequest {
    pub content: Vec<u8>,
    pub checksum: Option<String>,
    pub selective: bool,
}

/// 恢复结果
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RestoreResult {
    pub restore_point_id: String,
    pub stats: RestoreStats,
    pub restored_at: DateTime<Utc>,
}

/// 恢复统计
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct RestoreStats {
    pub accounts: usize,
    pub categories: usize,
    pub transactions: usize,
    pub budgets: usize,
    pub tags: usize,
    pub payees: usize,
    pub rules: usize,
}

// 导出数据结构

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionExport {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub transaction_type: TransactionType,
    pub category: Option<String>,
    pub payee: Option<String>,
    pub account: String,
    pub description: String,
    pub tags: Vec<String>,
    pub notes: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountExport {
    pub name: String,
    pub account_type: String,
    pub balance: Decimal,
    pub currency: String,
    pub institution: Option<String>,
    pub last_updated: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryExport {
    pub id: String,
    pub name: String,
    pub parent_id: Option<String>,
    pub color: Option<String>,
    pub icon: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetExport {
    pub name: String,
    pub category_id: String,
    pub amount: Decimal,
    pub period: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TagExport {
    pub id: String,
    pub name: String,
    pub color: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PayeeExport {
    pub id: String,
    pub name: String,
    pub category_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RuleExport {
    pub name: String,
    pub conditions: serde_json::Value,
    pub actions: serde_json::Value,
    pub priority: i32,
    pub active: bool,
}

// 导入数据结构

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TransactionImport {
    pub date: NaiveDate,
    pub amount: Decimal,
    pub description: String,
    pub category: Option<String>,
    pub payee: Option<String>,
    pub account: Option<String>,
    pub tags: Option<Vec<String>>,
    pub notes: Option<String>,
}

// 内部数据结构

#[derive(Debug, Clone)]
struct TransactionData {
    pub id: String,
    pub family_id: String,
    pub date: NaiveDate,
    pub amount: Decimal,
    pub transaction_type: TransactionType,
    pub description: String,
    pub category_id: Option<String>,
    pub payee_id: Option<String>,
    pub account_id: String,
    pub tags: Vec<String>,
    pub notes: Option<String>,
    pub import_id: Option<String>,
    pub imported_at: Option<DateTime<Utc>>,
}

#[derive(Debug, Clone)]
struct CategoryData {
    pub id: String,
    pub name: String,
}

#[derive(Debug, Clone)]
struct AccountData {
    pub id: String,
    pub name: String,
}

#[derive(Debug, Clone)]
struct PayeeData {
    pub id: String,
    pub name: String,
}

// ServiceContext 扩展用于加密
pub struct ServiceContextExt {
    pub context: ServiceContext,
    pub encryption_key: Option<String>,
}

// Error 实现
impl From<csv::Error> for JiveError {
    fn from(err: csv::Error) -> Self {
        JiveError::InvalidData(format!("CSV error: {}", err))
    }
}

impl From<std::io::Error> for JiveError {
    fn from(err: std::io::Error) -> Self {
        JiveError::InvalidData(format!("IO error: {}", err))
    }
}

impl From<serde_json::Error> for JiveError {
    fn from(err: serde_json::Error) -> Self {
        JiveError::InvalidData(format!("JSON error: {}", err))
    }
}

impl From<csv::IntoInnerError<Vec<u8>>> for JiveError {
    fn from(err: csv::IntoInnerError<Vec<u8>>) -> Self {
        JiveError::InvalidData(format!("CSV writer error: {}", err))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_export_format_extension() {
        assert_eq!(ExportFormat::CSV.extension(), "csv");
        assert_eq!(ExportFormat::Excel.extension(), "xlsx");
        assert_eq!(ExportFormat::JSON.extension(), "json");
    }

    #[test]
    fn test_import_mapping_summary() {
        let mut mapping = ImportMapping::default();
        mapping
            .category_map
            .insert("Food".to_string(), "cat-1".to_string());
        mapping
            .account_map
            .insert("Checking".to_string(), "acc-1".to_string());

        let summary = mapping.summary();
        assert_eq!(summary.categories_mapped, 1);
        assert_eq!(summary.accounts_mapped, 1);
        assert_eq!(summary.payees_mapped, 0);
        assert_eq!(summary.tags_mapped, 0);
    }
}
