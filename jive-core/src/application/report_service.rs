//! Report service - 报表分析服务
//!
//! 基于 Maybe 的报表功能转换而来，提供财务分析、趋势分析、预算对比等功能

use chrono::{DateTime, Datelike, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

use super::{ServiceContext, ServiceResponse};
use crate::domain::{Account, Category, Transaction};
use crate::error::{JiveError, Result};

/// 报表类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum ReportType {
    IncomeStatement,  // 收支报表
    BalanceSheet,     // 资产负债表
    CashFlow,         // 现金流量表
    BudgetComparison, // 预算对比
    CategoryAnalysis, // 分类分析
    TrendAnalysis,    // 趋势分析
    AccountSummary,   // 账户汇总
    TagAnalysis,      // 标签分析
    MerchantAnalysis, // 商户分析
    Custom,           // 自定义报表
}

/// 报表周期
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum ReportPeriod {
    Daily,
    Weekly,
    Monthly,
    Quarterly,
    Yearly,
    Custom,
}

/// 报表请求
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ReportRequest {
    report_type: ReportType,
    period: ReportPeriod,
    date_from: NaiveDate,
    date_to: NaiveDate,
    ledger_ids: Vec<String>,
    account_ids: Vec<String>,
    category_ids: Vec<String>,
    tag_ids: Vec<String>,
    group_by: Option<GroupBy>,
    include_subcategories: bool,
    compare_period: bool,
    currency: String,
}

/// 分组方式
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub enum GroupBy {
    Day,
    Week,
    Month,
    Quarter,
    Year,
    Category,
    Account,
    Tag,
    Merchant,
}

/// 报表结果
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ReportResult {
    id: String,
    report_type: ReportType,
    title: String,
    description: String,
    period: ReportPeriod,
    date_from: NaiveDate,
    date_to: NaiveDate,
    generated_at: DateTime<Utc>,
    data: ReportData,
    summary: ReportSummary,
    charts: Vec<ChartData>,
}

/// 报表数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ReportData {
    IncomeStatement(IncomeStatementData),
    BalanceSheet(BalanceSheetData),
    CashFlow(CashFlowData),
    BudgetComparison(BudgetComparisonData),
    CategoryAnalysis(CategoryAnalysisData),
    TrendAnalysis(TrendAnalysisData),
    AccountSummary(AccountSummaryData),
    Custom(HashMap<String, serde_json::Value>),
}

/// 收支报表数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IncomeStatementData {
    pub total_income: Decimal,
    pub total_expense: Decimal,
    pub net_income: Decimal,
    pub income_by_category: Vec<CategoryAmount>,
    pub expense_by_category: Vec<CategoryAmount>,
    pub income_by_month: Vec<PeriodAmount>,
    pub expense_by_month: Vec<PeriodAmount>,
}

/// 资产负债表数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalanceSheetData {
    pub total_assets: Decimal,
    pub total_liabilities: Decimal,
    pub net_worth: Decimal,
    pub assets: Vec<AccountBalance>,
    pub liabilities: Vec<AccountBalance>,
    pub equity: Decimal,
}

/// 现金流量表数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CashFlowData {
    pub opening_balance: Decimal,
    pub closing_balance: Decimal,
    pub cash_inflow: Decimal,
    pub cash_outflow: Decimal,
    pub net_cash_flow: Decimal,
    pub operating_activities: Decimal,
    pub investing_activities: Decimal,
    pub financing_activities: Decimal,
    pub daily_cash_flow: Vec<DailyCashFlow>,
}

/// 预算对比数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetComparisonData {
    pub budgeted_amount: Decimal,
    pub actual_amount: Decimal,
    pub variance: Decimal,
    pub variance_percentage: Decimal,
    pub categories: Vec<BudgetCategoryComparison>,
    pub over_budget_categories: Vec<String>,
    pub under_budget_categories: Vec<String>,
}

/// 分类分析数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryAnalysisData {
    pub total_amount: Decimal,
    pub categories: Vec<CategoryStat>,
    pub top_categories: Vec<CategoryAmount>,
    pub category_trends: Vec<CategoryTrend>,
}

/// 趋势分析数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrendAnalysisData {
    pub periods: Vec<String>,
    pub income_trend: Vec<Decimal>,
    pub expense_trend: Vec<Decimal>,
    pub net_income_trend: Vec<Decimal>,
    pub growth_rate: Decimal,
    pub average_income: Decimal,
    pub average_expense: Decimal,
    pub forecast: Option<ForecastData>,
}

/// 账户汇总数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountSummaryData {
    pub total_balance: Decimal,
    pub accounts: Vec<AccountInfo>,
    pub account_types: Vec<AccountTypeBalance>,
    pub currency_breakdown: Vec<CurrencyBalance>,
}

/// 分类金额
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryAmount {
    pub category_id: String,
    pub category_name: String,
    pub amount: Decimal,
    pub percentage: Decimal,
    pub transaction_count: u32,
}

/// 期间金额
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PeriodAmount {
    pub period: String,
    pub amount: Decimal,
    pub transaction_count: u32,
}

/// 账户余额
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountBalance {
    pub account_id: String,
    pub account_name: String,
    pub account_type: String,
    pub balance: Decimal,
    pub currency: String,
}

/// 每日现金流
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DailyCashFlow {
    pub date: NaiveDate,
    pub inflow: Decimal,
    pub outflow: Decimal,
    pub net_flow: Decimal,
    pub balance: Decimal,
}

/// 预算分类对比
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetCategoryComparison {
    pub category_id: String,
    pub category_name: String,
    pub budgeted: Decimal,
    pub actual: Decimal,
    pub variance: Decimal,
    pub variance_percentage: Decimal,
}

/// 分类统计
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryStat {
    pub category_id: String,
    pub category_name: String,
    pub total_amount: Decimal,
    pub average_amount: Decimal,
    pub transaction_count: u32,
    pub percentage: Decimal,
}

/// 分类趋势
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryTrend {
    pub category_id: String,
    pub category_name: String,
    pub trend: Vec<Decimal>,
    pub growth_rate: Decimal,
}

/// 预测数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ForecastData {
    pub next_period_income: Decimal,
    pub next_period_expense: Decimal,
    pub confidence: Decimal,
    pub method: String,
}

/// 账户信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountInfo {
    pub account_id: String,
    pub account_name: String,
    pub account_type: String,
    pub balance: Decimal,
    pub last_transaction_date: Option<NaiveDate>,
    pub transaction_count: u32,
}

/// 账户类型余额
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountTypeBalance {
    pub account_type: String,
    pub total_balance: Decimal,
    pub account_count: u32,
}

/// 货币余额
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CurrencyBalance {
    pub currency: String,
    pub balance: Decimal,
    pub converted_balance: Decimal,
    pub exchange_rate: Decimal,
}

/// 报表摘要
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ReportSummary {
    key_metrics: Vec<KeyMetric>,
    insights: Vec<String>,
    recommendations: Vec<String>,
}

/// 关键指标
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct KeyMetric {
    pub name: String,
    pub value: String,
    pub change: Option<Decimal>,
    pub change_percentage: Option<Decimal>,
    pub trend: Option<String>,
}

/// 图表数据
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChartData {
    pub chart_type: ChartType,
    pub title: String,
    pub data: serde_json::Value,
    pub options: ChartOptions,
}

/// 图表类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ChartType {
    Line,
    Bar,
    Pie,
    Donut,
    Area,
    Scatter,
    Heatmap,
    Treemap,
}

/// 图表选项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChartOptions {
    pub width: u32,
    pub height: u32,
    pub colors: Vec<String>,
    pub legend: bool,
    pub animations: bool,
}

/// 报表模板
#[derive(Debug, Clone, Serialize, Deserialize)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ReportTemplate {
    id: String,
    name: String,
    description: String,
    report_type: ReportType,
    default_period: ReportPeriod,
    filters: ReportFilters,
    charts: Vec<ChartConfig>,
    created_at: DateTime<Utc>,
    updated_at: DateTime<Utc>,
}

/// 报表过滤器
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ReportFilters {
    pub ledger_ids: Vec<String>,
    pub account_ids: Vec<String>,
    pub category_ids: Vec<String>,
    pub tag_ids: Vec<String>,
    pub exclude_transfers: bool,
    pub exclude_internal: bool,
}

/// 图表配置
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ChartConfig {
    pub chart_type: ChartType,
    pub data_source: String,
    pub options: ChartOptions,
}

/// 报表服务
#[derive(Debug, Clone)]
#[cfg_attr(feature = "wasm", wasm_bindgen)]
pub struct ReportService {}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
impl ReportService {
    pub fn new() -> Self { Self {} }
    #[wasm_bindgen(constructor)]
    pub fn new() -> Self {
        Self {}
    }

    /// 生成报表
    #[wasm_bindgen]
    pub async fn generate_report(
        &self,
        request: ReportRequest,
        context: ServiceContext,
    ) -> ServiceResponse<ReportResult> {
        let result = self._generate_report(request, context).await;
        result.into()
    }

    /// 生成收支报表
    #[wasm_bindgen]
    pub async fn generate_income_statement(
        &self,
        date_from: NaiveDate,
        date_to: NaiveDate,
        context: ServiceContext,
    ) -> ServiceResponse<IncomeStatementData> {
        let result = self
            ._generate_income_statement(date_from, date_to, context)
            .await;
        result.into()
    }

    /// 生成资产负债表
    #[wasm_bindgen]
    pub async fn generate_balance_sheet(
        &self,
        as_of_date: NaiveDate,
        context: ServiceContext,
    ) -> ServiceResponse<BalanceSheetData> {
        let result = self._generate_balance_sheet(as_of_date, context).await;
        result.into()
    }

    /// 生成现金流量表
    #[wasm_bindgen]
    pub async fn generate_cash_flow(
        &self,
        date_from: NaiveDate,
        date_to: NaiveDate,
        context: ServiceContext,
    ) -> ServiceResponse<CashFlowData> {
        let result = self._generate_cash_flow(date_from, date_to, context).await;
        result.into()
    }

    /// 生成预算对比报表
    #[wasm_bindgen]
    pub async fn generate_budget_comparison(
        &self,
        budget_id: String,
        period: ReportPeriod,
        context: ServiceContext,
    ) -> ServiceResponse<BudgetComparisonData> {
        let result = self
            ._generate_budget_comparison(budget_id, period, context)
            .await;
        result.into()
    }

    /// 生成分类分析报表
    #[wasm_bindgen]
    pub async fn generate_category_analysis(
        &self,
        date_from: NaiveDate,
        date_to: NaiveDate,
        context: ServiceContext,
    ) -> ServiceResponse<CategoryAnalysisData> {
        let result = self
            ._generate_category_analysis(date_from, date_to, context)
            .await;
        result.into()
    }

    /// 生成趋势分析报表
    #[wasm_bindgen]
    pub async fn generate_trend_analysis(
        &self,
        periods: u32,
        period_type: ReportPeriod,
        context: ServiceContext,
    ) -> ServiceResponse<TrendAnalysisData> {
        let result = self
            ._generate_trend_analysis(periods, period_type, context)
            .await;
        result.into()
    }

    /// 获取报表历史
    #[wasm_bindgen]
    pub async fn get_report_history(
        &self,
        limit: u32,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ReportResult>> {
        let result = self._get_report_history(limit, context).await;
        result.into()
    }

    /// 保存报表模板
    #[wasm_bindgen]
    pub async fn save_report_template(
        &self,
        template: ReportTemplate,
        context: ServiceContext,
    ) -> ServiceResponse<ReportTemplate> {
        let result = self._save_report_template(template, context).await;
        result.into()
    }

    /// 获取报表模板
    #[wasm_bindgen]
    pub async fn get_report_templates(
        &self,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<ReportTemplate>> {
        let result = self._get_report_templates(context).await;
        result.into()
    }

    /// 导出报表为 PDF
    #[wasm_bindgen]
    pub async fn export_report_to_pdf(
        &self,
        report_id: String,
        context: ServiceContext,
    ) -> ServiceResponse<Vec<u8>> {
        let result = self._export_report_to_pdf(report_id, context).await;
        result.into()
    }

    /// 安排定期报表
    #[wasm_bindgen]
    pub async fn schedule_report(
        &self,
        template_id: String,
        schedule: String,
        context: ServiceContext,
    ) -> ServiceResponse<String> {
        let result = self._schedule_report(template_id, schedule, context).await;
        result.into()
    }
}

impl ReportService {
    /// 生成报表的内部实现
    async fn _generate_report(
        &self,
        request: ReportRequest,
        context: ServiceContext,
    ) -> Result<ReportResult> {
        let data = match request.report_type {
            ReportType::IncomeStatement => {
                let income_data = self
                    ._generate_income_statement(request.date_from, request.date_to, context.clone())
                    .await?;
                ReportData::IncomeStatement(income_data)
            }
            ReportType::BalanceSheet => {
                let balance_data = self
                    ._generate_balance_sheet(request.date_to, context.clone())
                    .await?;
                ReportData::BalanceSheet(balance_data)
            }
            ReportType::CashFlow => {
                let cash_flow_data = self
                    ._generate_cash_flow(request.date_from, request.date_to, context.clone())
                    .await?;
                ReportData::CashFlow(cash_flow_data)
            }
            _ => ReportData::Custom(HashMap::new()),
        };

        let summary = self.generate_summary(&data);
        let charts = self.generate_charts(&data, &request);

        Ok(ReportResult {
            id: Uuid::new_v4().to_string(),
            report_type: request.report_type,
            title: self.get_report_title(&request),
            description: self.get_report_description(&request),
            period: request.period,
            date_from: request.date_from,
            date_to: request.date_to,
            generated_at: Utc::now(),
            data,
            summary,
            charts,
        })
    }

    /// 生成收支报表的内部实现
    async fn _generate_income_statement(
        &self,
        date_from: NaiveDate,
        date_to: NaiveDate,
        _context: ServiceContext,
    ) -> Result<IncomeStatementData> {
        // 在实际实现中，从数据库获取交易数据并计算
        let total_income = Decimal::from(10000);
        let total_expense = Decimal::from(7500);
        let net_income = total_income - total_expense;

        let income_by_category = vec![
            CategoryAmount {
                category_id: "cat-1".to_string(),
                category_name: "Salary".to_string(),
                amount: Decimal::from(8000),
                percentage: Decimal::from(80),
                transaction_count: 1,
            },
            CategoryAmount {
                category_id: "cat-2".to_string(),
                category_name: "Investment".to_string(),
                amount: Decimal::from(2000),
                percentage: Decimal::from(20),
                transaction_count: 5,
            },
        ];

        let expense_by_category = vec![
            CategoryAmount {
                category_id: "cat-3".to_string(),
                category_name: "Food".to_string(),
                amount: Decimal::from(2000),
                percentage: Decimal::from(27),
                transaction_count: 50,
            },
            CategoryAmount {
                category_id: "cat-4".to_string(),
                category_name: "Transport".to_string(),
                amount: Decimal::from(1500),
                percentage: Decimal::from(20),
                transaction_count: 30,
            },
        ];

        Ok(IncomeStatementData {
            total_income,
            total_expense,
            net_income,
            income_by_category,
            expense_by_category,
            income_by_month: self.generate_monthly_amounts(date_from, date_to, true),
            expense_by_month: self.generate_monthly_amounts(date_from, date_to, false),
        })
    }

    /// 生成资产负债表的内部实现
    async fn _generate_balance_sheet(
        &self,
        as_of_date: NaiveDate,
        _context: ServiceContext,
    ) -> Result<BalanceSheetData> {
        // 在实际实现中，从数据库获取账户余额
        let assets = vec![
            AccountBalance {
                account_id: "acc-1".to_string(),
                account_name: "Checking Account".to_string(),
                account_type: "Checking".to_string(),
                balance: Decimal::from(5000),
                currency: "USD".to_string(),
            },
            AccountBalance {
                account_id: "acc-2".to_string(),
                account_name: "Savings Account".to_string(),
                account_type: "Savings".to_string(),
                balance: Decimal::from(15000),
                currency: "USD".to_string(),
            },
        ];

        let liabilities = vec![AccountBalance {
            account_id: "acc-3".to_string(),
            account_name: "Credit Card".to_string(),
            account_type: "CreditCard".to_string(),
            balance: Decimal::from(2000),
            currency: "USD".to_string(),
        }];

        let total_assets = assets.iter().map(|a| a.balance).sum();
        let total_liabilities = liabilities.iter().map(|l| l.balance).sum();
        let net_worth = total_assets - total_liabilities;

        Ok(BalanceSheetData {
            total_assets,
            total_liabilities,
            net_worth,
            assets,
            liabilities,
            equity: net_worth,
        })
    }

    /// 生成现金流量表的内部实现
    async fn _generate_cash_flow(
        &self,
        date_from: NaiveDate,
        date_to: NaiveDate,
        _context: ServiceContext,
    ) -> Result<CashFlowData> {
        let opening_balance = Decimal::from(10000);
        let cash_inflow = Decimal::from(8000);
        let cash_outflow = Decimal::from(6000);
        let net_cash_flow = cash_inflow - cash_outflow;
        let closing_balance = opening_balance + net_cash_flow;

        let daily_cash_flow = self.generate_daily_cash_flow(date_from, date_to);

        Ok(CashFlowData {
            opening_balance,
            closing_balance,
            cash_inflow,
            cash_outflow,
            net_cash_flow,
            operating_activities: Decimal::from(1500),
            investing_activities: Decimal::from(500),
            financing_activities: Decimal::from(0),
            daily_cash_flow,
        })
    }

    /// 生成预算对比的内部实现
    async fn _generate_budget_comparison(
        &self,
        _budget_id: String,
        _period: ReportPeriod,
        _context: ServiceContext,
    ) -> Result<BudgetComparisonData> {
        let budgeted_amount = Decimal::from(5000);
        let actual_amount = Decimal::from(4800);
        let variance = actual_amount - budgeted_amount;
        let variance_percentage = (variance / budgeted_amount) * Decimal::from(100);

        let categories = vec![BudgetCategoryComparison {
            category_id: "cat-1".to_string(),
            category_name: "Food".to_string(),
            budgeted: Decimal::from(1000),
            actual: Decimal::from(1200),
            variance: Decimal::from(200),
            variance_percentage: Decimal::from(20),
        }];

        Ok(BudgetComparisonData {
            budgeted_amount,
            actual_amount,
            variance,
            variance_percentage,
            categories,
            over_budget_categories: vec!["Food".to_string()],
            under_budget_categories: vec!["Transport".to_string()],
        })
    }

    /// 生成分类分析的内部实现
    async fn _generate_category_analysis(
        &self,
        _date_from: NaiveDate,
        _date_to: NaiveDate,
        _context: ServiceContext,
    ) -> Result<CategoryAnalysisData> {
        let categories = vec![CategoryStat {
            category_id: "cat-1".to_string(),
            category_name: "Food".to_string(),
            total_amount: Decimal::from(2000),
            average_amount: Decimal::from(40),
            transaction_count: 50,
            percentage: Decimal::from(25),
        }];

        Ok(CategoryAnalysisData {
            total_amount: Decimal::from(8000),
            categories: categories.clone(),
            top_categories: vec![CategoryAmount {
                category_id: "cat-1".to_string(),
                category_name: "Food".to_string(),
                amount: Decimal::from(2000),
                percentage: Decimal::from(25),
                transaction_count: 50,
            }],
            category_trends: vec![],
        })
    }

    /// 生成趋势分析的内部实现
    async fn _generate_trend_analysis(
        &self,
        periods: u32,
        _period_type: ReportPeriod,
        _context: ServiceContext,
    ) -> Result<TrendAnalysisData> {
        let mut income_trend = Vec::new();
        let mut expense_trend = Vec::new();
        let mut periods_list = Vec::new();

        for i in 0..periods {
            periods_list.push(format!("Period {}", i + 1));
            income_trend.push(Decimal::from(8000 + i * 100));
            expense_trend.push(Decimal::from(6000 + i * 50));
        }

        let net_income_trend: Vec<Decimal> = income_trend
            .iter()
            .zip(expense_trend.iter())
            .map(|(i, e)| i - e)
            .collect();

        Ok(TrendAnalysisData {
            periods: periods_list,
            income_trend: income_trend.clone(),
            expense_trend: expense_trend.clone(),
            net_income_trend,
            growth_rate: Decimal::from(5),
            average_income: Decimal::from(8500),
            average_expense: Decimal::from(6250),
            forecast: Some(ForecastData {
                next_period_income: Decimal::from(9000),
                next_period_expense: Decimal::from(6500),
                confidence: Decimal::from(85),
                method: "Linear Regression".to_string(),
            }),
        })
    }

    /// 获取报表历史的内部实现
    async fn _get_report_history(
        &self,
        limit: u32,
        context: ServiceContext,
    ) -> Result<Vec<ReportResult>> {
        // 在实际实现中，从数据库获取报表历史
        Ok(Vec::new())
    }

    /// 保存报表模板的内部实现
    async fn _save_report_template(
        &self,
        mut template: ReportTemplate,
        _context: ServiceContext,
    ) -> Result<ReportTemplate> {
        template.id = Uuid::new_v4().to_string();
        template.created_at = Utc::now();
        template.updated_at = Utc::now();
        Ok(template)
    }

    /// 获取报表模板的内部实现
    async fn _get_report_templates(&self, _context: ServiceContext) -> Result<Vec<ReportTemplate>> {
        Ok(Vec::new())
    }

    /// 导出报表为 PDF 的内部实现
    async fn _export_report_to_pdf(
        &self,
        _report_id: String,
        _context: ServiceContext,
    ) -> Result<Vec<u8>> {
        // 在实际实现中，生成 PDF 文件
        Ok(Vec::new())
    }

    /// 安排定期报表的内部实现
    async fn _schedule_report(
        &self,
        _template_id: String,
        _schedule: String,
        _context: ServiceContext,
    ) -> Result<String> {
        Ok(Uuid::new_v4().to_string())
    }

    // 辅助方法

    fn generate_monthly_amounts(
        &self,
        date_from: NaiveDate,
        date_to: NaiveDate,
        is_income: bool,
    ) -> Vec<PeriodAmount> {
        let mut amounts = Vec::new();
        let mut current = date_from;

        while current <= date_to {
            let month = format!("{}-{:02}", current.year(), current.month());
            let base_amount = if is_income { 8000 } else { 6000 };

            amounts.push(PeriodAmount {
                period: month,
                amount: Decimal::from(base_amount),
                transaction_count: if is_income { 2 } else { 50 },
            });

            // Move to next month
            current = if current.month() == 12 {
                NaiveDate::from_ymd_opt(current.year() + 1, 1, 1).unwrap()
            } else {
                NaiveDate::from_ymd_opt(current.year(), current.month() + 1, 1).unwrap()
            };
        }

        amounts
    }

    fn generate_daily_cash_flow(
        &self,
        date_from: NaiveDate,
        date_to: NaiveDate,
    ) -> Vec<DailyCashFlow> {
        let mut cash_flows = Vec::new();
        let mut current = date_from;
        let mut balance = Decimal::from(10000);

        while current <= date_to {
            let inflow = Decimal::from(300);
            let outflow = Decimal::from(200);
            let net_flow = inflow - outflow;
            balance += net_flow;

            cash_flows.push(DailyCashFlow {
                date: current,
                inflow,
                outflow,
                net_flow,
                balance,
            });

            current = current.succ_opt().unwrap_or(current);
        }

        cash_flows
    }

    fn generate_summary(&self, data: &ReportData) -> ReportSummary {
        let mut key_metrics = Vec::new();
        let mut insights = Vec::new();
        let mut recommendations = Vec::new();

        match data {
            ReportData::IncomeStatement(income_data) => {
                key_metrics.push(KeyMetric {
                    name: "Net Income".to_string(),
                    value: income_data.net_income.to_string(),
                    change: Some(Decimal::from(500)),
                    change_percentage: Some(Decimal::from(25)),
                    trend: Some("up".to_string()),
                });

                insights.push("Your income exceeds expenses by 25%".to_string());
                recommendations.push("Consider increasing savings allocation".to_string());
            }
            _ => {}
        }

        ReportSummary {
            key_metrics,
            insights,
            recommendations,
        }
    }

    fn generate_charts(&self, data: &ReportData, request: &ReportRequest) -> Vec<ChartData> {
        let mut charts = Vec::new();

        match data {
            ReportData::IncomeStatement(_) => {
                charts.push(ChartData {
                    chart_type: ChartType::Pie,
                    title: "Income by Category".to_string(),
                    data: serde_json::json!({}),
                    options: ChartOptions {
                        width: 400,
                        height: 300,
                        colors: vec!["#FF6384".to_string(), "#36A2EB".to_string()],
                        legend: true,
                        animations: true,
                    },
                });
            }
            _ => {}
        }

        charts
    }

    fn get_report_title(&self, request: &ReportRequest) -> String {
        match request.report_type {
            ReportType::IncomeStatement => "Income Statement".to_string(),
            ReportType::BalanceSheet => "Balance Sheet".to_string(),
            ReportType::CashFlow => "Cash Flow Statement".to_string(),
            ReportType::BudgetComparison => "Budget Comparison".to_string(),
            ReportType::CategoryAnalysis => "Category Analysis".to_string(),
            ReportType::TrendAnalysis => "Trend Analysis".to_string(),
            ReportType::AccountSummary => "Account Summary".to_string(),
            _ => "Financial Report".to_string(),
        }
    }

    fn get_report_description(&self, request: &ReportRequest) -> String {
        format!(
            "{} from {} to {}",
            self.get_report_title(request),
            request.date_from,
            request.date_to
        )
    }
}

impl Default for ReportService {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_generate_income_statement() {
        let service = ReportService::new();
        let context = ServiceContext::new("user-123".to_string());
        let date_from = NaiveDate::from_ymd_opt(2024, 1, 1).unwrap();
        let date_to = NaiveDate::from_ymd_opt(2024, 12, 31).unwrap();

        let result = service
            ._generate_income_statement(date_from, date_to, context)
            .await;
        assert!(result.is_ok());

        let data = result.unwrap();
        assert_eq!(data.total_income, Decimal::from(10000));
        assert_eq!(data.total_expense, Decimal::from(7500));
        assert_eq!(data.net_income, Decimal::from(2500));
    }

    #[tokio::test]
    async fn test_generate_balance_sheet() {
        let service = ReportService::new();
        let context = ServiceContext::new("user-123".to_string());
        let as_of_date = NaiveDate::from_ymd_opt(2024, 12, 31).unwrap();

        let result = service._generate_balance_sheet(as_of_date, context).await;
        assert!(result.is_ok());

        let data = result.unwrap();
        assert!(data.total_assets > Decimal::ZERO);
        assert_eq!(data.net_worth, data.total_assets - data.total_liabilities);
    }

    #[tokio::test]
    async fn test_generate_cash_flow() {
        let service = ReportService::new();
        let context = ServiceContext::new("user-123".to_string());
        let date_from = NaiveDate::from_ymd_opt(2024, 1, 1).unwrap();
        let date_to = NaiveDate::from_ymd_opt(2024, 1, 31).unwrap();

        let result = service
            ._generate_cash_flow(date_from, date_to, context)
            .await;
        assert!(result.is_ok());

        let data = result.unwrap();
        assert_eq!(data.net_cash_flow, data.cash_inflow - data.cash_outflow);
        assert_eq!(
            data.closing_balance,
            data.opening_balance + data.net_cash_flow
        );
    }

    #[test]
    fn test_report_types() {
        assert_eq!(ReportType::IncomeStatement as i32, 0);
        assert_eq!(ReportType::BalanceSheet as i32, 1);
        assert_eq!(ReportType::CashFlow as i32, 2);
    }

    #[test]
    fn test_report_periods() {
        assert_eq!(ReportPeriod::Daily as i32, 0);
        assert_eq!(ReportPeriod::Monthly as i32, 2);
        assert_eq!(ReportPeriod::Yearly as i32, 4);
    }
}
