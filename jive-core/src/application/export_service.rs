//! Export service - 数据导出服务
//! 
//! 基于 Maybe 的导出功能转换而来，支持多种导出格式和灵活的数据选择

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc, NaiveDate};
use rust_decimal::Decimal;
use uuid::Uuid;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use crate::error::{JiveError, Result};
use crate::domain::{Account, Transaction, Category, Ledger};
use super::{ServiceContext, ServiceResponse, PaginationParams};

/// 导出格式
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum ExportFormat {
    CSV,            // CSV 格式
    Excel,          // Excel 格式
    JSON,           // JSON 格式
    XML,            // XML 格式
    PDF,            // PDF 格式
    QIF,            // Quicken Interchange Format
    OFX,            // Open Financial Exchange
    Markdown,       // Markdown 格式
    HTML,           // HTML 格式
}

/// 导出范围
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum ExportScope {
    All,            // 所有数据
    Ledger,         // 特定账本
    Account,        // 特定账户
    Category,       // 特定分类
    DateRange,      // 日期范围
    Custom,         // 自定义
}

/// 导出选项
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ExportOptions {
    format: ExportFormat,
    scope: ExportScope,
    include_transactions: bool,
    include_accounts: bool,
    include_categories: bool,
    include_budgets: bool,
    include_reports: bool,
    include_attachments: bool,
    date_from: Option<NaiveDate>,
    date_to: Option<NaiveDate>,
    ledger_ids: Vec<String>,
    account_ids: Vec<String>,
    category_ids: Vec<String>,
    tag_ids: Vec<String>,
}

impl Default for ExportOptions {
    fn default() -> Self {
        Self {
            // 默认导出格式：CSV
            format: ExportFormat::CSV,
            scope: ExportScope::All,
            include_transactions: true,
            include_accounts: true,
            include_categories: true,
            include_budgets: false,
            include_reports: false,
            include_attachments: false,
            date_from: None,
            date_to: None,
            ledger_ids: Vec::new(),
            account_ids: Vec::new(),
            category_ids: Vec::new(),
            tag_ids: Vec::new(),
        }
    }
}

/// 导出任务
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ExportTask {
    id: String,
    user_id: String,
    name: String,
    description: Option<String>,
    options: ExportOptions,
    status: ExportStatus,
    progress: u32,
    total_items: u32,
    exported_items: u32,
    file_size: u64,
    file_path: Option<String>,
    download_url: Option<String>,
    error_message: Option<String>,
    started_at: DateTime<Utc>,
    completed_at: Option<DateTime<Utc>>,
}

/// 导出状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum ExportStatus {
    Pending,        // 待处理
    Processing,     // 处理中
    Generating,     // 生成中
    Completed,      // 完成
    Failed,         // 失败
    Cancelled,      // 取消
}

/// 导出模板
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ExportTemplate {
    id: String,
    name: String,
    description: Option<String>,
    format: ExportFormat,
    options: ExportOptions,
    field_mappings: Vec<FieldMapping>,
    is_default: bool,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

/// 字段映射
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FieldMapping {
    source_field: String,
    target_field: String,
    format: Option<String>,
    default_value: Option<String>,
}

/// 导出结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ExportResult {
    task_id: String,
    status: ExportStatus,
    format: ExportFormat,
    total_items: u32,
    exported_items: u32,
    file_size: u64,
    file_name: String,
    download_url: Option<String>,
    expires_at: Option<DateTime<Utc>>,
    metadata: ExportMetadata,
}

/// 导出元数据
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ExportMetadata {
    version: String,
    exported_at: DateTime<Utc>,
    exported_by: String,
    application: String,
    ledger_count: u32,
    account_count: u32,
    transaction_count: u32,
    category_count: u32,
    tag_count: u32,
    date_range: Option<DateRange>,
}

/// 日期范围
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DateRange {
    from: NaiveDate,
    to: NaiveDate,
}

/// CSV 导出配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CsvExportConfig {
    delimiter: char,
    quote_char: char,
    escape_char: char,
    include_header: bool,
    date_format: String,
    decimal_separator: String,
    thousands_separator: String,
    encoding: String,
}

impl Default for CsvExportConfig {
    fn default() -> Self {
        Self {
            delimiter: ',',
            quote_char: '"',
            escape_char: '\\',
            include_header: true,
            date_format: "%Y-%m-%d".to_string(),
            decimal_separator: ".".to_string(),
            thousands_separator: ",".to_string(),
            encoding: "UTF-8".to_string(),
        }
    }
}

impl CsvExportConfig {
    // Allow external crates (API) to toggle header inclusion without exposing fields.
    pub fn with_include_header(mut self, include_header: bool) -> Self {
        self.include_header = include_header;
        self
    }
}

/// 轻量导出行（供服务端快速复用，不依赖内部数据收集）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SimpleTransactionExport {
    pub date: NaiveDate,
    pub description: String,
    pub amount: Decimal,
    pub category: Option<String>,
    pub account: String,
    pub payee: Option<String>,
    pub transaction_type: String,
}

/// Excel 导出配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExcelExportConfig {
    sheet_name: String,
    include_formatting: bool,
    include_charts: bool,
    include_pivot_tables: bool,
    password_protect: bool,
    password: Option<String>,
}

impl Default for ExcelExportConfig {
    fn default() -> Self {
        Self {
            sheet_name: "Transactions".to_string(),
            include_formatting: true,
            include_charts: false,
            include_pivot_tables: false,
            password_protect: false,
            password: None,
        }
    }
}

/// PDF 导出配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PdfExportConfig {
    page_size: String,
    orientation: String,
    margins: PdfMargins,
    include_header: bool,
    include_footer: bool,
    include_logo: bool,
    include_summary: bool,
    password_protect: bool,
    password: Option<String>,
}

/// PDF 页边距
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PdfMargins {
    top: f32,
    bottom: f32,
    left: f32,
    right: f32,
}

impl Default for PdfExportConfig {
    fn default() -> Self {
        Self {
            page_size: "A4".to_string(),
            orientation: "Portrait".to_string(),
            margins: PdfMargins {
                top: 25.0,
                bottom: 25.0,
                left: 25.0,
                right: 25.0,
            },
            include_header: true,
            include_footer: true,
            include_logo: false,
            include_summary: true,
            password_protect: false,
            password: None,
        }
    }
}

/// 导出数据容器
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExportData {
    pub metadata: ExportMetadata,
    pub ledgers: Vec<Ledger>,
    pub accounts: Vec<Account>,
    pub transactions: Vec<Transaction>,
    pub categories: Vec<Category>,
    pub tags: Vec<String>,
    pub budgets: Vec<BudgetData>,
    pub reports: Vec<ReportData>,
}

/// 预算数据（简化版）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetData {
    pub id: String,
    pub name: String,
    pub amount: Decimal,
    pub period: String,
    pub category_id: Option<String>,
}

/// 报表数据（简化版）
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReportData {
    pub id: String,
    pub name: String,
    pub report_type: String,
    pub data: HashMap<String, serde_json::Value>,
}

/// 导出服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ExportService {}

impl ExportService {
    // Lightweight CSV generator usable on server builds
    pub fn generate_csv_simple(
        &self,
        rows: &[SimpleTransactionExport],
        config: Option<&CsvExportConfig>,
    ) -> Result<Vec<u8>> {
        let cfg = config.cloned().unwrap_or_default();
        let mut out = String::new();
        if cfg.include_header {
            out.push_str(&format!(
                "Date{}Description{}Amount{}Category{}Account{}Payee{}Type\n",
                cfg.delimiter, cfg.delimiter, cfg.delimiter, cfg.delimiter, cfg.delimiter, cfg.delimiter
            ));
        }
        for r in rows {
            let amount_str = r.amount.to_string().replace('.', &cfg.decimal_separator);
            out.push_str(&format!(
                "{}{}{}{}{}{}{}{}{}{}{}{}{}\n",
                r.date.format(&cfg.date_format), cfg.delimiter,
                escape_csv_field(&sanitize_csv_cell(&r.description), cfg.delimiter), cfg.delimiter,
                amount_str, cfg.delimiter,
                escape_csv_field(r.category.as_deref().unwrap_or(""), cfg.delimiter), cfg.delimiter,
                escape_csv_field(&r.account, cfg.delimiter), cfg.delimiter,
                escape_csv_field(r.payee.as_deref().unwrap_or(""), cfg.delimiter), cfg.delimiter,
                escape_csv_field(&r.transaction_type, cfg.delimiter),
            ));
        }
        Ok(out.into_bytes())
    }
}

fn escape_csv_field(input: &str, delimiter: char) -> String {
    let needs_quotes = input.contains(delimiter) || input.contains('"') || input.contains('\n');
    if needs_quotes {
        let escaped = input.replace('"', "\"\"");
        format!("\"{}\"", escaped)
    } else {
        input.to_string()
    }
}

fn sanitize_csv_cell(input: &str) -> String {
    if let Some(first) = input.chars().next() {
        if matches!(first, '=' | '+' | '-' | '@') {
            let mut s = String::with_capacity(input.len() + 1);
            s.push('\'');
            s.push_str(input);
            return s;
        }
    }
    input.to_string()
}
#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl ExportService {
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }

    /// 创建导出任务
    #[wasm_bindgen]
    pub async fn create_export_task(
        &self,
        name: String,
        options: ExportOptions,
        context: ServiceContext,
    ) -> ServiceResponse<ExportTask> {
        let result = self._create_export_task(name, options, context).await;
        result.into()
    }

    /// 执行导出
    #[wasm_bindgen]
    pub async fn execute_export(
        &self,
        task_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<ExportResult> {
        let result = self._execute_export(task_id, context).await;
        result.into()
    }

    /// 获取导出任务状态
    #[wasm_bindgen]
    pub async fn get_export_status(
        &self,
        task_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<ExportTask> {
        let result = self._get_export_status(task_id, context).await;
        result.into()
    }

    /// 取消导出任务
    #[wasm_bindgen]
    pub async fn cancel_export(
        &self,
        task_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._cancel_export(task_id, context).await;
        result.into()
    }

    /// 获取导出历史
    #[wasm_bindgen]
    pub async fn get_export_history(
        &self,
        limit: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ExportTask>> {
        let result = self._get_export_history(limit, context).await;
        result.into()
    }

    /// 删除导出文件
    #[wasm_bindgen]
    pub async fn delete_export_file(
        &self,
        task_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._delete_export_file(task_id, context).await;
        result.into()
    }

    /// 保存导出模板
    #[wasm_bindgen]
    pub async fn save_export_template(
        &self,
        template: ExportTemplate,
        context: ServiceContext,
    ) -> ServiceResponse<ExportTemplate> {
        let result = self._save_export_template(template, context).await;
        result.into()
    }

    /// 获取导出模板
    #[wasm_bindgen]
    pub async fn get_export_templates(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ExportTemplate>> {
        let result = self._get_export_templates(context).await;
        result.into()
    }

    /// 删除导出模板
    #[wasm_bindgen]
    pub async fn delete_export_template(
        &self,
        template_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<bool> {
        let result = self._delete_export_template(template_id, context).await;
        result.into()
    }

    /// 导出到 CSV
    #[wasm_bindgen]
    pub async fn export_to_csv(
        &self,
        options: ExportOptions,
        config: CsvExportConfig,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<u8>> {
        let result = self._export_to_csv(options, config, context).await;
        result.into()
    }

    /// 导出到 JSON
    #[wasm_bindgen]
    pub async fn export_to_json(
        &self,
        options: ExportOptions,
        context: ServiceContext,
    ) -> ServiceResponse<String> {
        let result = self._export_to_json(options, context).await;
        result.into()
    }

    /// 批量导出
    #[wasm_bindgen]
    pub async fn batch_export(
        &self,
        tasks: Vec<ExportTask>,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ExportResult>> {
        let result = self._batch_export(tasks, context).await;
        result.into()
    }
}

impl ExportService {
    /// 创建导出任务的内部实现
    async fn _create_export_task(
        &self,
        name: String,
        options: ExportOptions,
        context: ServiceContext,
    ) -> Result<ExportTask> {
        let task = ExportTask {
            id: Uuid::new_v4().to_string(),
            user_id: context.user_id.clone(),
            name,
            description: None,
            options,
            status: ExportStatus::Pending,
            progress: 0,
            total_items: 0,
            exported_items: 0,
            file_size: 0,
            file_path: None,
            download_url: None,
            error_message: None,
            started_at: Utc::now(),
            completed_at: None,
        };

        // 在实际实现中，保存任务到数据库
        Ok(task)
    }

    /// 执行导出的内部实现
    async fn _execute_export(
        &self,
        task_id: String,
        context: ServiceContext,
    ) -> Result<ExportResult> {
        // 获取任务
        let mut task = self._get_export_status(task_id.clone(), context.clone()).await?;
        
        // 更新状态为处理中
        task.status = ExportStatus::Processing;
        
        // 收集数据
        let export_data = self.collect_export_data(&task.options, &context).await?;
        
        // 计算总项数
        task.total_items = export_data.transactions.len() as u32 
            + export_data.accounts.len() as u32 
            + export_data.categories.len() as u32;
        
        // 根据格式导出
        let file_data = match task.options.format {
            ExportFormat::CSV => self.generate_csv(&export_data, &task.options)?,
            ExportFormat::JSON => self.generate_json(&export_data)?,
            ExportFormat::Excel => self.generate_excel(&export_data, &task.options)?,
            _ => {
                return Err(JiveError::ValidationError {
                    message: format!("Unsupported export format: {:?}", task.options.format),
                });
            }
        };
        
        // 保存文件
        let file_name = format!("export_{}_{}.{}", 
            context.user_id, 
            Utc::now().timestamp(),
            self.get_file_extension(&task.options.format)
        );
        
        // 在实际实现中，这里会保存文件到存储服务
        let download_url = format!("/downloads/{}", file_name);
        
        // 更新任务状态
        task.status = ExportStatus::Completed;
        task.exported_items = task.total_items;
        task.file_size = file_data.len() as u64;
        task.file_path = Some(file_name.clone());
        task.download_url = Some(download_url.clone());
        task.completed_at = Some(Utc::now());
        task.progress = 100;
        
        // 创建导出结果
        let metadata = ExportMetadata {
            version: "1.0.0".to_string(),
            exported_at: Utc::now(),
            exported_by: context.user_id.clone(),
            application: "Jive".to_string(),
            ledger_count: export_data.ledgers.len() as u32,
            account_count: export_data.accounts.len() as u32,
            transaction_count: export_data.transactions.len() as u32,
            category_count: export_data.categories.len() as u32,
            tag_count: export_data.tags.len() as u32,
            date_range: None,
        };
        
        Ok(ExportResult {
            task_id: task.id,
            status: task.status,
            format: task.options.format,
            total_items: task.total_items,
            exported_items: task.exported_items,
            file_size: task.file_size,
            file_name,
            download_url: Some(download_url),
            expires_at: Some(Utc::now() + chrono::Duration::days(7)),
            metadata,
        })
    }

    /// 获取导出状态的内部实现
    async fn _get_export_status(
        &self,
        task_id: String,
        _context: ServiceContext,
    ) -> Result<ExportTask> {
        // 在实际实现中，从数据库获取任务状态
        Ok(ExportTask {
            id: task_id,
            user_id: "user-123".to_string(),
            name: "Monthly Export".to_string(),
            description: Some("Export of monthly transactions".to_string()),
            options: ExportOptions::default(),
            status: ExportStatus::Completed,
            progress: 100,
            total_items: 150,
            exported_items: 150,
            file_size: 204800,
            // 统一改为 JSON 示例文件名
            file_path: Some("export_2024_01.json".to_string()),
            download_url: Some("/downloads/export_2024_01.json".to_string()),
            error_message: None,
            started_at: Utc::now() - chrono::Duration::minutes(5),
            completed_at: Some(Utc::now()),
        })
    }

    /// 取消导出的内部实现
    async fn _cancel_export(
        &self,
        _task_id: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 在实际实现中，取消正在进行的导出任务
        Ok(true)
    }

    /// 获取导出历史的内部实现
    async fn _get_export_history(
        &self,
        limit: u32,
        context: ServiceContext,
    ) -> Result<Vec<ExportTask>> {
        // 在实际实现中，从数据库获取导出历史
        let history = vec![
            ExportTask {
                id: Uuid::new_v4().to_string(),
                user_id: context.user_id.clone(),
                name: "Year 2024 Export".to_string(),
                description: Some("Complete export for year 2024".to_string()),
                options: ExportOptions::default(),
                status: ExportStatus::Completed,
                progress: 100,
                total_items: 5000,
                exported_items: 5000,
                file_size: 2048000,
                // 统一改为 JSON 示例文件名
                file_path: Some("export_2024_full.json".to_string()),
                download_url: Some("/downloads/export_2024_full.json".to_string()),
                error_message: None,
                started_at: Utc::now() - chrono::Duration::days(1),
                completed_at: Some(Utc::now() - chrono::Duration::days(1) + chrono::Duration::minutes(10)),
            },
        ];

        Ok(history.into_iter().take(limit as usize).collect())
    }

    /// 删除导出文件的内部实现
    async fn _delete_export_file(
        &self,
        _task_id: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 在实际实现中，删除导出文件
        Ok(true)
    }

    /// 保存导出模板的内部实现
    async fn _save_export_template(
        &self,
        mut template: ExportTemplate,
        _context: ServiceContext,
    ) -> Result<ExportTemplate> {
        template.id = Uuid::new_v4().to_string();
        template.created_at = Utc::now();
        template.updated_at = Utc::now();

        // 在实际实现中，保存到数据库
        Ok(template)
    }

    /// 获取导出模板的内部实现
    async fn _get_export_templates(
        &self,
        _context: ServiceContext,
    ) -> Result<Vec<ExportTemplate>> {
        // 在实际实现中，从数据库获取模板
        Ok(Vec::new())
    }

    /// 删除导出模板的内部实现
    async fn _delete_export_template(
        &self,
        _template_id: String,
        _context: ServiceContext,
    ) -> Result<bool> {
        // 在实际实现中，从数据库删除模板
        Ok(true)
    }

    /// 导出到 CSV 的内部实现
    async fn _export_to_csv(
        &self,
        options: ExportOptions,
        config: CsvExportConfig,
        context: ServiceContext,
    ) -> Result<Vec<u8>> {
        let export_data = self.collect_export_data(&options, &context).await?;
        let csv_data = self.generate_csv_with_config(&export_data, &config)?;
        Ok(csv_data)
    }

    /// 导出到 JSON 的内部实现
    async fn _export_to_json(
        &self,
        options: ExportOptions,
        context: ServiceContext,
    ) -> Result<String> {
        let export_data = self.collect_export_data(&options, &context).await?;
        let json = serde_json::to_string_pretty(&export_data)
            .map_err(|e| JiveError::SerializationError {
                message: e.to_string(),
            })?;
        Ok(json)
    }

    /// 批量导出的内部实现
    async fn _batch_export(
        &self,
        tasks: Vec<ExportTask>,
        context: ServiceContext,
    ) -> Result<Vec<ExportResult>> {
        let mut results = Vec::new();

        for task in tasks {
            match self._execute_export(task.id, context.clone()).await {
                Ok(result) => results.push(result),
                Err(e) => {
                    // 记录错误但继续处理
                    eprintln!("Export task failed: {}", e);
                }
            }
        }

        Ok(results)
    }

    // 辅助方法

    /// 收集导出数据
    async fn collect_export_data(
        &self,
        options: &ExportOptions,
        _context: &ServiceContext,
    ) -> Result<ExportData> {
        // 在实际实现中，从数据库收集数据
        let mut data = ExportData {
            metadata: ExportMetadata {
                version: "1.0.0".to_string(),
                exported_at: Utc::now(),
                exported_by: "user-123".to_string(),
                application: "Jive".to_string(),
                ledger_count: 0,
                account_count: 0,
                transaction_count: 0,
                category_count: 0,
                tag_count: 0,
                date_range: None,
            },
            ledgers: Vec::new(),
            accounts: Vec::new(),
            transactions: Vec::new(),
            categories: Vec::new(),
            tags: Vec::new(),
            budgets: Vec::new(),
            reports: Vec::new(),
        };

        // 根据选项收集数据
        if options.include_transactions {
            // 收集交易数据
            data.transactions = vec![]; // 实际从数据库获取
        }

        if options.include_accounts {
            // 收集账户数据
            data.accounts = vec![]; // 实际从数据库获取
        }

        if options.include_categories {
            // 收集分类数据
            data.categories = vec![]; // 实际从数据库获取
        }

        Ok(data)
    }

    /// 生成 CSV 数据
    fn generate_csv(&self, data: &ExportData, _options: &ExportOptions) -> Result<Vec<u8>> {
        let mut csv = String::new();
        
        // 添加标题行
        csv.push_str("Date,Description,Amount,Category,Account\n");
        
        // 添加交易数据
        for transaction in &data.transactions {
            csv.push_str(&format!(
                "{},{},{},{},{}\n",
                transaction.date,
                transaction.description,
                transaction.amount,
                transaction.category_id.as_deref().unwrap_or(""),
                transaction.account_id
            ));
        }
        
        Ok(csv.into_bytes())
    }

    /// 生成带配置的 CSV 数据
    fn generate_csv_with_config(&self, data: &ExportData, config: &CsvExportConfig) -> Result<Vec<u8>> {
        let mut csv = String::new();
        
        // 添加标题行
        if config.include_header {
            csv.push_str(&format!(
                "Date{}Description{}Amount{}Category{}Account\n",
                config.delimiter, config.delimiter, config.delimiter, config.delimiter
            ));
        }
        
        // 添加交易数据
        for transaction in &data.transactions {
            let amount_str = transaction.amount.to_string()
                .replace('.', &config.decimal_separator);
            
            csv.push_str(&format!(
                "{}{}{}{}{}{}{}{}{}\n",
                transaction.date.format(&config.date_format),
                config.delimiter,
                transaction.description,
                config.delimiter,
                amount_str,
                config.delimiter,
                transaction.category_id.as_deref().unwrap_or(""),
                config.delimiter,
                transaction.account_id
            ));
        }
        
        Ok(csv.into_bytes())
    }

    /// 生成 JSON 数据
    fn generate_json(&self, data: &ExportData) -> Result<Vec<u8>> {
        let json = serde_json::to_vec_pretty(data)
            .map_err(|e| JiveError::SerializationError {
                message: e.to_string(),
            })?;
        Ok(json)
    }

    /// 生成 Excel 数据
    fn generate_excel(&self, _data: &ExportData, _options: &ExportOptions) -> Result<Vec<u8>> {
        // 在实际实现中，使用 Excel 库生成文件
        // 这里返回模拟数据
        Ok(Vec::new())
    }

    /// 获取文件扩展名
    fn get_file_extension(&self, format: &ExportFormat) -> &str {
        match format {
            ExportFormat::CSV => "csv",
            ExportFormat::Excel => "xlsx",
            ExportFormat::JSON => "json",
            ExportFormat::XML => "xml",
            ExportFormat::PDF => "pdf",
            ExportFormat::QIF => "qif",
            ExportFormat::OFX => "ofx",
            ExportFormat::Markdown => "md",
            ExportFormat::HTML => "html",
        }
    }
}

impl Default for ExportService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_export_options_default() {
        let options = ExportOptions::default();
        // 默认改为 CSV
        assert_eq!(options.format, ExportFormat::CSV);
        assert_eq!(options.scope, ExportScope::All);
        assert!(options.include_transactions);
        assert!(options.include_accounts);
    }

    #[test]
    fn test_csv_config_default() {
        let config = CsvExportConfig::default();
        assert_eq!(config.delimiter, ',');
        assert_eq!(config.quote_char, '"');
        assert!(config.include_header);
        assert_eq!(config.date_format, "%Y-%m-%d");
    }

    #[tokio::test]
    async fn test_create_export_task() {
        let service = ExportService::new();
        let context = ServiceContext::new("user-123".to_string());
        let options = ExportOptions::default();

        let result = service._create_export_task(
            "Test Export".to_string(),
            options,
            context
        ).await;

        assert!(result.is_ok());
        let task = result.unwrap();
        assert_eq!(task.name, "Test Export");
        assert_eq!(task.status, ExportStatus::Pending);
    }

    #[test]
    fn test_file_extension() {
        let service = ExportService::new();
        // 仍保留映射，便于兼容历史数据，但功能已禁用
        assert_eq!(service.get_file_extension(&ExportFormat::CSV), "csv");
        assert_eq!(service.get_file_extension(&ExportFormat::Excel), "xlsx");
        assert_eq!(service.get_file_extension(&ExportFormat::JSON), "json");
        assert_eq!(service.get_file_extension(&ExportFormat::PDF), "pdf");
    }
}
