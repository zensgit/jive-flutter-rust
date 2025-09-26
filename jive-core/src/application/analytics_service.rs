//! Analytics Service - 报表分析服务
//!
//! 基于 Maybe 的报表系统实现，提供财务分析、统计报表、图表数据等功能

use chrono::{DateTime, Datelike, Duration, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

use crate::application::{ServiceContext, ServiceResponse};
use crate::domain::{Account, Budget, Category, Transaction, TransactionType};
use crate::error::{JiveError, Result};

/// 报表服务
pub struct AnalyticsService {
    // 依赖注入
}

impl AnalyticsService {
    pub fn new() -> Self {
        Self {}
    }

    /// 生成收支报表
    pub async fn generate_income_statement(
        &self,
        context: ServiceContext,
        request: IncomeStatementRequest,
    ) -> Result<ServiceResponse<IncomeStatement>> {
        // 权限检查
        if !context.has_permission_str("view_reports") {
            return Err(JiveError::Forbidden("No permission to view reports".into()));
        }

        // 获取期间内的交易
        let transactions = self
            .get_transactions_for_period(&context.family_id, &request.period)
            .await?;

        // 计算收入和支出
        let income_total = self.calculate_income(&transactions);
        let expense_total = self.calculate_expense(&transactions);
        let net_income = income_total - expense_total;

        // 按分类汇总
        let income_by_category = self.group_by_category(&transactions, TransactionType::Income);
        let expense_by_category = self.group_by_category(&transactions, TransactionType::Expense);

        // 计算趋势
        let income_trend = self
            .calculate_trend(&context.family_id, TransactionType::Income, &request.period)
            .await?;
        let expense_trend = self
            .calculate_trend(
                &context.family_id,
                TransactionType::Expense,
                &request.period,
            )
            .await?;

        let statement = IncomeStatement {
            period: request.period.clone(),
            currency: request.currency.unwrap_or("USD".to_string()),
            income_total,
            expense_total,
            net_income,
            income_by_category,
            expense_by_category,
            income_trend,
            expense_trend,
            transaction_count: transactions.len(),
            generated_at: Utc::now(),
        };

        Ok(ServiceResponse::success(statement))
    }

    /// 生成资产负债表
    pub async fn generate_balance_sheet(
        &self,
        context: ServiceContext,
        request: BalanceSheetRequest,
    ) -> Result<ServiceResponse<BalanceSheet>> {
        // 权限检查
        if !context.has_permission_str("view_reports") {
            return Err(JiveError::Forbidden("No permission to view reports".into()));
        }

        // 获取所有账户
        let accounts = self.get_accounts(&context.family_id).await?;

        // 分类账户
        let assets = self.filter_assets(&accounts);
        let liabilities = self.filter_liabilities(&accounts);

        // 计算总额
        let total_assets = self.calculate_total_balance(&assets);
        let total_liabilities = self.calculate_total_balance(&liabilities);
        let net_worth = total_assets - total_liabilities;

        // 资产细分
        let asset_breakdown = AssetBreakdown {
            cash_and_equivalents: self.calculate_cash_balance(&assets),
            investments: self.calculate_investment_balance(&assets),
            property: self.calculate_property_balance(&assets),
            other_assets: self.calculate_other_assets(&assets),
        };

        // 负债细分
        let liability_breakdown = LiabilityBreakdown {
            credit_cards: self.calculate_credit_card_balance(&liabilities),
            loans: self.calculate_loan_balance(&liabilities),
            mortgages: self.calculate_mortgage_balance(&liabilities),
            other_liabilities: self.calculate_other_liabilities(&liabilities),
        };

        let balance_sheet = BalanceSheet {
            as_of_date: request.as_of_date.unwrap_or(Utc::now().date_naive()),
            currency: request.currency.unwrap_or("USD".to_string()),
            total_assets,
            total_liabilities,
            net_worth,
            asset_breakdown,
            liability_breakdown,
            accounts: accounts
                .into_iter()
                .map(|a| AccountSummary {
                    id: a.id,
                    name: a.name,
                    account_type: a.account_type,
                    balance: a.balance,
                    last_updated: a.last_updated,
                })
                .collect(),
            generated_at: Utc::now(),
        };

        Ok(ServiceResponse::success(balance_sheet))
    }

    /// 生成现金流报表
    pub async fn generate_cash_flow_statement(
        &self,
        context: ServiceContext,
        request: CashFlowRequest,
    ) -> Result<ServiceResponse<CashFlowStatement>> {
        // 权限检查
        if !context.has_permission_str("view_reports") {
            return Err(JiveError::Forbidden("No permission to view reports".into()));
        }

        // 获取期间内的交易
        let transactions = self
            .get_transactions_for_period(&context.family_id, &request.period)
            .await?;

        // 经营活动现金流
        let operating_activities = self.calculate_operating_cash_flow(&transactions);

        // 投资活动现金流
        let investing_activities = self.calculate_investing_cash_flow(&transactions);

        // 融资活动现金流
        let financing_activities = self.calculate_financing_cash_flow(&transactions);

        // 净现金流
        let net_cash_flow = operating_activities + investing_activities + financing_activities;

        // 期初和期末现金余额
        let beginning_cash = self
            .get_cash_balance_at_date(&context.family_id, &request.period.start_date)
            .await?;

        let ending_cash = beginning_cash + net_cash_flow;

        let statement = CashFlowStatement {
            period: request.period.clone(),
            currency: request.currency.unwrap_or("USD".to_string()),
            operating_activities,
            investing_activities,
            financing_activities,
            net_cash_flow,
            beginning_cash_balance: beginning_cash,
            ending_cash_balance: ending_cash,
            generated_at: Utc::now(),
        };

        Ok(ServiceResponse::success(statement))
    }

    /// 生成支出分析
    pub async fn generate_expense_analysis(
        &self,
        context: ServiceContext,
        request: ExpenseAnalysisRequest,
    ) -> Result<ServiceResponse<ExpenseAnalysis>> {
        // 获取支出交易
        let expenses = self
            .get_expense_transactions(&context.family_id, &request.period)
            .await?;

        // 按分类分组
        let by_category = self.group_expenses_by_category(&expenses);

        // 按商户分组
        let by_payee = self.group_expenses_by_payee(&expenses);

        // 按时间分组（日/周/月）
        let by_time = self.group_expenses_by_time(&expenses, &request.group_by);

        // 计算统计数据
        let total_expense = expenses.iter().map(|t| t.amount).sum();
        let average_expense = if !expenses.is_empty() {
            total_expense / Decimal::from(expenses.len())
        } else {
            Decimal::ZERO
        };

        let median_expense =
            self.calculate_median(&expenses.iter().map(|t| t.amount).collect::<Vec<_>>());

        // 找出最大支出
        let largest_expenses = self.find_largest_expenses(&expenses, 10);

        // 异常支出检测
        let unusual_expenses = self.detect_unusual_expenses(&expenses);

        let analysis = ExpenseAnalysis {
            period: request.period.clone(),
            total_expense,
            average_expense,
            median_expense,
            transaction_count: expenses.len(),
            by_category,
            by_payee,
            by_time,
            largest_expenses,
            unusual_expenses,
            generated_at: Utc::now(),
        };

        Ok(ServiceResponse::success(analysis))
    }

    /// 生成预算vs实际报表
    pub async fn generate_budget_comparison(
        &self,
        context: ServiceContext,
        request: BudgetComparisonRequest,
    ) -> Result<ServiceResponse<BudgetComparison>> {
        // 获取预算
        let budgets = self
            .get_budgets(&context.family_id, &request.period)
            .await?;

        // 获取实际支出
        let actual_expenses = self
            .get_expense_transactions(&context.family_id, &request.period)
            .await?;

        let mut comparisons = Vec::new();

        for budget in budgets {
            let actual = self.calculate_actual_for_budget(&budget, &actual_expenses);
            let variance = actual - budget.amount;
            let variance_percentage = if budget.amount != Decimal::ZERO {
                (variance / budget.amount * Decimal::from(100)).round_dp(2)
            } else {
                Decimal::ZERO
            };

            comparisons.push(BudgetVsActual {
                budget_id: budget.id.clone(),
                budget_name: budget.name.clone(),
                category: budget.category.clone(),
                budgeted_amount: budget.amount,
                actual_amount: actual,
                variance,
                variance_percentage,
                is_over_budget: actual > budget.amount,
            });
        }

        let total_budgeted: Decimal = comparisons.iter().map(|c| c.budgeted_amount).sum();
        let total_actual: Decimal = comparisons.iter().map(|c| c.actual_amount).sum();
        let total_variance = total_actual - total_budgeted;

        let comparison = BudgetComparison {
            period: request.period.clone(),
            comparisons,
            total_budgeted,
            total_actual,
            total_variance,
            overall_performance: if total_actual <= total_budgeted {
                "Under Budget".to_string()
            } else {
                "Over Budget".to_string()
            },
            generated_at: Utc::now(),
        };

        Ok(ServiceResponse::success(comparison))
    }

    /// 生成趋势分析
    pub async fn generate_trend_analysis(
        &self,
        context: ServiceContext,
        request: TrendAnalysisRequest,
    ) -> Result<ServiceResponse<TrendAnalysis>> {
        let mut data_points = Vec::new();
        let mut current_date = request.period.start_date;

        while current_date <= request.period.end_date {
            let period_end = match request.interval {
                TimeInterval::Daily => current_date,
                TimeInterval::Weekly => current_date + Duration::days(6),
                TimeInterval::Monthly => {
                    let days_in_month = days_in_month(current_date.year(), current_date.month());
                    current_date + Duration::days(days_in_month as i64 - 1)
                }
                TimeInterval::Quarterly => current_date + Duration::days(89),
                TimeInterval::Yearly => current_date + Duration::days(364),
            };

            let period = Period {
                start_date: current_date,
                end_date: period_end.min(request.period.end_date),
            };

            let transactions = self
                .get_transactions_for_period(&context.family_id, &period)
                .await?;

            let income = self.calculate_income(&transactions);
            let expense = self.calculate_expense(&transactions);
            let net = income - expense;

            data_points.push(TrendDataPoint {
                date: current_date,
                income,
                expense,
                net,
                transaction_count: transactions.len(),
            });

            // 移动到下一个周期
            current_date = match request.interval {
                TimeInterval::Daily => current_date + Duration::days(1),
                TimeInterval::Weekly => current_date + Duration::days(7),
                TimeInterval::Monthly => {
                    let mut next = current_date;
                    next = next.with_day(1).unwrap();
                    if next.month() == 12 {
                        next.with_year(next.year() + 1)
                            .unwrap()
                            .with_month(1)
                            .unwrap()
                    } else {
                        next.with_month(next.month() + 1).unwrap()
                    }
                }
                TimeInterval::Quarterly => current_date + Duration::days(90),
                TimeInterval::Yearly => current_date + Duration::days(365),
            };
        }

        // 计算趋势线（简单线性回归）
        let income_trend =
            self.calculate_trend_line(&data_points.iter().map(|d| d.income).collect::<Vec<_>>());
        let expense_trend =
            self.calculate_trend_line(&data_points.iter().map(|d| d.expense).collect::<Vec<_>>());

        let analysis = TrendAnalysis {
            period: request.period.clone(),
            interval: request.interval.clone(),
            data_points,
            income_trend,
            expense_trend,
            generated_at: Utc::now(),
        };

        Ok(ServiceResponse::success(analysis))
    }

    /// 生成分类细分报表
    pub async fn generate_category_breakdown(
        &self,
        context: ServiceContext,
        request: CategoryBreakdownRequest,
    ) -> Result<ServiceResponse<CategoryBreakdown>> {
        let transactions = self
            .get_transactions_for_period(&context.family_id, &request.period)
            .await?;

        let mut categories_map: HashMap<String, CategorySummary> = HashMap::new();

        for transaction in transactions {
            let category_id = transaction
                .category_id
                .unwrap_or("uncategorized".to_string());

            let entry = categories_map
                .entry(category_id.clone())
                .or_insert(CategorySummary {
                    category_id: category_id.clone(),
                    category_name: transaction
                        .category_name
                        .unwrap_or("Uncategorized".to_string()),
                    total_amount: Decimal::ZERO,
                    transaction_count: 0,
                    percentage: 0.0,
                    subcategories: Vec::new(),
                });

            entry.total_amount += transaction.amount;
            entry.transaction_count += 1;
        }

        // 计算百分比
        let total: Decimal = categories_map.values().map(|c| c.total_amount).sum();
        for category in categories_map.values_mut() {
            if total != Decimal::ZERO {
                category.percentage = (category.total_amount / total * Decimal::from(100))
                    .to_f64()
                    .unwrap_or(0.0);
            }
        }

        let mut categories: Vec<CategorySummary> = categories_map.into_values().collect();
        categories.sort_by(|a, b| b.total_amount.cmp(&a.total_amount));

        let breakdown = CategoryBreakdown {
            period: request.period.clone(),
            transaction_type: request.transaction_type.clone(),
            categories,
            total_amount: total,
            generated_at: Utc::now(),
        };

        Ok(ServiceResponse::success(breakdown))
    }

    // 辅助方法

    async fn get_transactions_for_period(
        &self,
        family_id: &str,
        period: &Period,
    ) -> Result<Vec<TransactionData>> {
        // TODO: 从数据库获取交易
        Ok(Vec::new())
    }

    async fn get_accounts(&self, family_id: &str) -> Result<Vec<AccountData>> {
        // TODO: 从数据库获取账户
        Ok(Vec::new())
    }

    async fn get_budgets(&self, family_id: &str, period: &Period) -> Result<Vec<BudgetData>> {
        // TODO: 从数据库获取预算
        Ok(Vec::new())
    }

    async fn get_expense_transactions(
        &self,
        family_id: &str,
        period: &Period,
    ) -> Result<Vec<TransactionData>> {
        let all_transactions = self.get_transactions_for_period(family_id, period).await?;
        Ok(all_transactions
            .into_iter()
            .filter(|t| t.transaction_type == TransactionType::Expense)
            .collect())
    }

    async fn get_cash_balance_at_date(&self, family_id: &str, date: &NaiveDate) -> Result<Decimal> {
        // TODO: 从数据库获取特定日期的现金余额
        Ok(Decimal::ZERO)
    }

    async fn calculate_trend(
        &self,
        family_id: &str,
        transaction_type: TransactionType,
        period: &Period,
    ) -> Result<TrendInfo> {
        // TODO: 计算趋势
        Ok(TrendInfo {
            direction: TrendDirection::Stable,
            change_amount: Decimal::ZERO,
            change_percentage: 0.0,
        })
    }

    fn calculate_income(&self, transactions: &[TransactionData]) -> Decimal {
        transactions
            .iter()
            .filter(|t| t.transaction_type == TransactionType::Income)
            .map(|t| t.amount)
            .sum()
    }

    fn calculate_expense(&self, transactions: &[TransactionData]) -> Decimal {
        transactions
            .iter()
            .filter(|t| t.transaction_type == TransactionType::Expense)
            .map(|t| t.amount)
            .sum()
    }

    fn group_by_category(
        &self,
        transactions: &[TransactionData],
        transaction_type: TransactionType,
    ) -> Vec<CategoryAmount> {
        let mut category_map: HashMap<String, Decimal> = HashMap::new();

        for transaction in transactions
            .iter()
            .filter(|t| t.transaction_type == transaction_type)
        {
            let category = transaction
                .category_name
                .clone()
                .unwrap_or("Uncategorized".to_string());
            *category_map.entry(category).or_insert(Decimal::ZERO) += transaction.amount;
        }

        category_map
            .into_iter()
            .map(|(category, amount)| CategoryAmount { category, amount })
            .collect()
    }

    fn filter_assets(&self, accounts: &[AccountData]) -> Vec<AccountData> {
        accounts
            .iter()
            .filter(|a| matches!(a.account_type, AccountType::Asset))
            .cloned()
            .collect()
    }

    fn filter_liabilities(&self, accounts: &[AccountData]) -> Vec<AccountData> {
        accounts
            .iter()
            .filter(|a| matches!(a.account_type, AccountType::Liability))
            .cloned()
            .collect()
    }

    fn calculate_total_balance(&self, accounts: &[AccountData]) -> Decimal {
        accounts.iter().map(|a| a.balance).sum()
    }

    fn calculate_cash_balance(&self, accounts: &[AccountData]) -> Decimal {
        accounts
            .iter()
            .filter(|a| {
                matches!(
                    a.subtype,
                    Some(AccountSubtype::Checking) | Some(AccountSubtype::Savings)
                )
            })
            .map(|a| a.balance)
            .sum()
    }

    fn calculate_investment_balance(&self, accounts: &[AccountData]) -> Decimal {
        accounts
            .iter()
            .filter(|a| matches!(a.subtype, Some(AccountSubtype::Investment)))
            .map(|a| a.balance)
            .sum()
    }

    fn calculate_property_balance(&self, accounts: &[AccountData]) -> Decimal {
        accounts
            .iter()
            .filter(|a| matches!(a.subtype, Some(AccountSubtype::Property)))
            .map(|a| a.balance)
            .sum()
    }

    fn calculate_other_assets(&self, accounts: &[AccountData]) -> Decimal {
        accounts
            .iter()
            .filter(|a| {
                !matches!(
                    a.subtype,
                    Some(AccountSubtype::Checking)
                        | Some(AccountSubtype::Savings)
                        | Some(AccountSubtype::Investment)
                        | Some(AccountSubtype::Property)
                )
            })
            .map(|a| a.balance)
            .sum()
    }

    fn calculate_credit_card_balance(&self, accounts: &[AccountData]) -> Decimal {
        accounts
            .iter()
            .filter(|a| matches!(a.subtype, Some(AccountSubtype::CreditCard)))
            .map(|a| a.balance)
            .sum()
    }

    fn calculate_loan_balance(&self, accounts: &[AccountData]) -> Decimal {
        accounts
            .iter()
            .filter(|a| matches!(a.subtype, Some(AccountSubtype::Loan)))
            .map(|a| a.balance)
            .sum()
    }

    fn calculate_mortgage_balance(&self, accounts: &[AccountData]) -> Decimal {
        accounts
            .iter()
            .filter(|a| matches!(a.subtype, Some(AccountSubtype::Mortgage)))
            .map(|a| a.balance)
            .sum()
    }

    fn calculate_other_liabilities(&self, accounts: &[AccountData]) -> Decimal {
        accounts
            .iter()
            .filter(|a| {
                !matches!(
                    a.subtype,
                    Some(AccountSubtype::CreditCard)
                        | Some(AccountSubtype::Loan)
                        | Some(AccountSubtype::Mortgage)
                )
            })
            .map(|a| a.balance)
            .sum()
    }

    fn calculate_operating_cash_flow(&self, transactions: &[TransactionData]) -> Decimal {
        // 简化计算：收入 - 日常支出
        let income = self.calculate_income(transactions);
        let operating_expense = transactions
            .iter()
            .filter(|t| {
                t.transaction_type == TransactionType::Expense
                    && !self.is_investing_activity(&t)
                    && !self.is_financing_activity(&t)
            })
            .map(|t| t.amount)
            .sum::<Decimal>();

        income - operating_expense
    }

    fn calculate_investing_cash_flow(&self, transactions: &[TransactionData]) -> Decimal {
        transactions
            .iter()
            .filter(|t| self.is_investing_activity(t))
            .map(|t| {
                if t.transaction_type == TransactionType::Income {
                    t.amount
                } else {
                    -t.amount
                }
            })
            .sum()
    }

    fn calculate_financing_cash_flow(&self, transactions: &[TransactionData]) -> Decimal {
        transactions
            .iter()
            .filter(|t| self.is_financing_activity(t))
            .map(|t| {
                if t.transaction_type == TransactionType::Income {
                    t.amount
                } else {
                    -t.amount
                }
            })
            .sum()
    }

    fn is_investing_activity(&self, transaction: &TransactionData) -> bool {
        // 判断是否为投资活动（买卖股票、房产等）
        transaction
            .category_name
            .as_ref()
            .map(|c| c.contains("Investment") || c.contains("Property"))
            .unwrap_or(false)
    }

    fn is_financing_activity(&self, transaction: &TransactionData) -> bool {
        // 判断是否为融资活动（贷款、还款等）
        transaction
            .category_name
            .as_ref()
            .map(|c| c.contains("Loan") || c.contains("Credit") || c.contains("Mortgage"))
            .unwrap_or(false)
    }

    fn group_expenses_by_category(&self, expenses: &[TransactionData]) -> Vec<CategoryAmount> {
        let mut category_map: HashMap<String, Decimal> = HashMap::new();

        for expense in expenses {
            let category = expense
                .category_name
                .clone()
                .unwrap_or("Uncategorized".to_string());
            *category_map.entry(category).or_insert(Decimal::ZERO) += expense.amount;
        }

        let mut result: Vec<CategoryAmount> = category_map
            .into_iter()
            .map(|(category, amount)| CategoryAmount { category, amount })
            .collect();

        result.sort_by(|a, b| b.amount.cmp(&a.amount));
        result
    }

    fn group_expenses_by_payee(&self, expenses: &[TransactionData]) -> Vec<PayeeAmount> {
        let mut payee_map: HashMap<String, Decimal> = HashMap::new();

        for expense in expenses {
            let payee = expense.payee_name.clone().unwrap_or("Unknown".to_string());
            *payee_map.entry(payee).or_insert(Decimal::ZERO) += expense.amount;
        }

        let mut result: Vec<PayeeAmount> = payee_map
            .into_iter()
            .map(|(payee, amount)| PayeeAmount { payee, amount })
            .collect();

        result.sort_by(|a, b| b.amount.cmp(&a.amount));
        result
    }

    fn group_expenses_by_time(
        &self,
        expenses: &[TransactionData],
        interval: &TimeInterval,
    ) -> Vec<TimeAmount> {
        let mut time_map: HashMap<NaiveDate, Decimal> = HashMap::new();

        for expense in expenses {
            let key = match interval {
                TimeInterval::Daily => expense.date,
                TimeInterval::Weekly => {
                    // 获取周的第一天
                    expense.date
                        - Duration::days(expense.date.weekday().num_days_from_monday() as i64)
                }
                TimeInterval::Monthly => expense.date.with_day(1).unwrap(),
                _ => expense.date,
            };

            *time_map.entry(key).or_insert(Decimal::ZERO) += expense.amount;
        }

        let mut result: Vec<TimeAmount> = time_map
            .into_iter()
            .map(|(date, amount)| TimeAmount { date, amount })
            .collect();

        result.sort_by_key(|t| t.date);
        result
    }

    fn find_largest_expenses(
        &self,
        expenses: &[TransactionData],
        limit: usize,
    ) -> Vec<TransactionData> {
        let mut sorted = expenses.to_vec();
        sorted.sort_by(|a, b| b.amount.cmp(&a.amount));
        sorted.into_iter().take(limit).collect()
    }

    fn detect_unusual_expenses(&self, expenses: &[TransactionData]) -> Vec<TransactionData> {
        if expenses.is_empty() {
            return Vec::new();
        }

        let amounts: Vec<Decimal> = expenses.iter().map(|e| e.amount).collect();
        let mean = amounts.iter().sum::<Decimal>() / Decimal::from(amounts.len());

        // 计算标准差
        let variance = amounts.iter().map(|a| (*a - mean).powi(2)).sum::<Decimal>()
            / Decimal::from(amounts.len());

        let std_dev = variance.sqrt().unwrap_or(Decimal::ZERO);

        // 找出超过2个标准差的支出
        let threshold = mean + std_dev * Decimal::from(2);

        expenses
            .iter()
            .filter(|e| e.amount > threshold)
            .cloned()
            .collect()
    }

    fn calculate_median(&self, values: &[Decimal]) -> Decimal {
        if values.is_empty() {
            return Decimal::ZERO;
        }

        let mut sorted = values.to_vec();
        sorted.sort();

        let len = sorted.len();
        if len % 2 == 0 {
            (sorted[len / 2 - 1] + sorted[len / 2]) / Decimal::from(2)
        } else {
            sorted[len / 2]
        }
    }

    fn calculate_actual_for_budget(
        &self,
        budget: &BudgetData,
        expenses: &[TransactionData],
    ) -> Decimal {
        expenses
            .iter()
            .filter(|e| e.category_id.as_ref() == Some(&budget.category_id))
            .map(|e| e.amount)
            .sum()
    }

    fn calculate_trend_line(&self, values: &[Decimal]) -> TrendLine {
        if values.len() < 2 {
            return TrendLine {
                slope: Decimal::ZERO,
                intercept: values.first().cloned().unwrap_or(Decimal::ZERO),
                r_squared: 0.0,
            };
        }

        // 简单线性回归
        let n = Decimal::from(values.len());
        let x_values: Vec<Decimal> = (0..values.len()).map(|i| Decimal::from(i)).collect();

        let sum_x: Decimal = x_values.iter().sum();
        let sum_y: Decimal = values.iter().sum();
        let sum_xy: Decimal = x_values.iter().zip(values.iter()).map(|(x, y)| x * y).sum();
        let sum_x2: Decimal = x_values.iter().map(|x| x * x).sum();

        let slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
        let intercept = (sum_y - slope * sum_x) / n;

        // 计算 R²
        let mean_y = sum_y / n;
        let ss_tot: Decimal = values.iter().map(|y| (*y - mean_y).powi(2)).sum();
        let ss_res: Decimal = x_values
            .iter()
            .zip(values.iter())
            .map(|(x, y)| (*y - (slope * x + intercept)).powi(2))
            .sum();

        let r_squared = if ss_tot != Decimal::ZERO {
            (Decimal::ONE - ss_res / ss_tot).to_f64().unwrap_or(0.0)
        } else {
            0.0
        };

        TrendLine {
            slope,
            intercept,
            r_squared,
        }
    }
}

// 数据结构定义

/// 期间
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Period {
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
}

impl Period {
    pub fn current_month() -> Self {
        let now = Utc::now().date_naive();
        Self {
            start_date: now.with_day(1).unwrap(),
            end_date: now,
        }
    }

    pub fn last_30_days() -> Self {
        let now = Utc::now().date_naive();
        Self {
            start_date: now - Duration::days(30),
            end_date: now,
        }
    }
}

/// 时间间隔
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TimeInterval {
    Daily,
    Weekly,
    Monthly,
    Quarterly,
    Yearly,
}

/// 趋势方向
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TrendDirection {
    Up,
    Down,
    Stable,
}

/// 收支报表请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IncomeStatementRequest {
    pub period: Period,
    pub currency: Option<String>,
}

/// 收支报表
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IncomeStatement {
    pub period: Period,
    pub currency: String,
    pub income_total: Decimal,
    pub expense_total: Decimal,
    pub net_income: Decimal,
    pub income_by_category: Vec<CategoryAmount>,
    pub expense_by_category: Vec<CategoryAmount>,
    pub income_trend: TrendInfo,
    pub expense_trend: TrendInfo,
    pub transaction_count: usize,
    pub generated_at: DateTime<Utc>,
}

/// 资产负债表请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalanceSheetRequest {
    pub as_of_date: Option<NaiveDate>,
    pub currency: Option<String>,
}

/// 资产负债表
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BalanceSheet {
    pub as_of_date: NaiveDate,
    pub currency: String,
    pub total_assets: Decimal,
    pub total_liabilities: Decimal,
    pub net_worth: Decimal,
    pub asset_breakdown: AssetBreakdown,
    pub liability_breakdown: LiabilityBreakdown,
    pub accounts: Vec<AccountSummary>,
    pub generated_at: DateTime<Utc>,
}

/// 资产细分
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AssetBreakdown {
    pub cash_and_equivalents: Decimal,
    pub investments: Decimal,
    pub property: Decimal,
    pub other_assets: Decimal,
}

/// 负债细分
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LiabilityBreakdown {
    pub credit_cards: Decimal,
    pub loans: Decimal,
    pub mortgages: Decimal,
    pub other_liabilities: Decimal,
}

/// 现金流报表请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CashFlowRequest {
    pub period: Period,
    pub currency: Option<String>,
}

/// 现金流报表
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CashFlowStatement {
    pub period: Period,
    pub currency: String,
    pub operating_activities: Decimal,
    pub investing_activities: Decimal,
    pub financing_activities: Decimal,
    pub net_cash_flow: Decimal,
    pub beginning_cash_balance: Decimal,
    pub ending_cash_balance: Decimal,
    pub generated_at: DateTime<Utc>,
}

/// 支出分析请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExpenseAnalysisRequest {
    pub period: Period,
    pub group_by: TimeInterval,
}

/// 支出分析
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExpenseAnalysis {
    pub period: Period,
    pub total_expense: Decimal,
    pub average_expense: Decimal,
    pub median_expense: Decimal,
    pub transaction_count: usize,
    pub by_category: Vec<CategoryAmount>,
    pub by_payee: Vec<PayeeAmount>,
    pub by_time: Vec<TimeAmount>,
    pub largest_expenses: Vec<TransactionData>,
    pub unusual_expenses: Vec<TransactionData>,
    pub generated_at: DateTime<Utc>,
}

/// 预算比较请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetComparisonRequest {
    pub period: Period,
}

/// 预算比较
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetComparison {
    pub period: Period,
    pub comparisons: Vec<BudgetVsActual>,
    pub total_budgeted: Decimal,
    pub total_actual: Decimal,
    pub total_variance: Decimal,
    pub overall_performance: String,
    pub generated_at: DateTime<Utc>,
}

/// 预算vs实际
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BudgetVsActual {
    pub budget_id: String,
    pub budget_name: String,
    pub category: String,
    pub budgeted_amount: Decimal,
    pub actual_amount: Decimal,
    pub variance: Decimal,
    pub variance_percentage: Decimal,
    pub is_over_budget: bool,
}

/// 趋势分析请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrendAnalysisRequest {
    pub period: Period,
    pub interval: TimeInterval,
}

/// 趋势分析
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrendAnalysis {
    pub period: Period,
    pub interval: TimeInterval,
    pub data_points: Vec<TrendDataPoint>,
    pub income_trend: TrendLine,
    pub expense_trend: TrendLine,
    pub generated_at: DateTime<Utc>,
}

/// 趋势数据点
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrendDataPoint {
    pub date: NaiveDate,
    pub income: Decimal,
    pub expense: Decimal,
    pub net: Decimal,
    pub transaction_count: usize,
}

/// 趋势线
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrendLine {
    pub slope: Decimal,
    pub intercept: Decimal,
    pub r_squared: f64,
}

/// 分类细分请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryBreakdownRequest {
    pub period: Period,
    pub transaction_type: Option<TransactionType>,
}

/// 分类细分
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryBreakdown {
    pub period: Period,
    pub transaction_type: Option<TransactionType>,
    pub categories: Vec<CategorySummary>,
    pub total_amount: Decimal,
    pub generated_at: DateTime<Utc>,
}

/// 分类汇总
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategorySummary {
    pub category_id: String,
    pub category_name: String,
    pub total_amount: Decimal,
    pub transaction_count: usize,
    pub percentage: f64,
    pub subcategories: Vec<CategorySummary>,
}

/// 趋势信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TrendInfo {
    pub direction: TrendDirection,
    pub change_amount: Decimal,
    pub change_percentage: f64,
}

/// 分类金额
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryAmount {
    pub category: String,
    pub amount: Decimal,
}

/// 商户金额
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PayeeAmount {
    pub payee: String,
    pub amount: Decimal,
}

/// 时间金额
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TimeAmount {
    pub date: NaiveDate,
    pub amount: Decimal,
}

/// 账户汇总
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountSummary {
    pub id: String,
    pub name: String,
    pub account_type: AccountType,
    pub balance: Decimal,
    pub last_updated: DateTime<Utc>,
}

// 内部数据结构

#[derive(Debug, Clone)]
struct TransactionData {
    pub id: String,
    pub date: NaiveDate,
    pub amount: Decimal,
    pub transaction_type: TransactionType,
    pub category_id: Option<String>,
    pub category_name: Option<String>,
    pub payee_id: Option<String>,
    pub payee_name: Option<String>,
    pub account_id: String,
    pub description: String,
}

#[derive(Debug, Clone)]
struct AccountData {
    pub id: String,
    pub name: String,
    pub account_type: AccountType,
    pub subtype: Option<AccountSubtype>,
    pub balance: Decimal,
    pub last_updated: DateTime<Utc>,
}

#[derive(Debug, Clone)]
struct BudgetData {
    pub id: String,
    pub name: String,
    pub category_id: String,
    pub category: String,
    pub amount: Decimal,
    pub period: Period,
}

#[derive(Debug, Clone)]
enum AccountType {
    Asset,
    Liability,
}

#[derive(Debug, Clone)]
enum AccountSubtype {
    Checking,
    Savings,
    Investment,
    Property,
    CreditCard,
    Loan,
    Mortgage,
}

// 辅助函数
fn days_in_month(year: i32, month: u32) -> u32 {
    match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 => {
            if is_leap_year(year) {
                29
            } else {
                28
            }
        }
        _ => 0,
    }
}

fn is_leap_year(year: i32) -> bool {
    (year % 4 == 0 && year % 100 != 0) || (year % 400 == 0)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_period_creation() {
        let period = Period::current_month();
        assert!(period.start_date.day() == 1);
        assert!(period.end_date <= Utc::now().date_naive());

        let period = Period::last_30_days();
        let days_diff = (period.end_date - period.start_date).num_days();
        assert_eq!(days_diff, 30);
    }

    #[test]
    fn test_days_in_month() {
        assert_eq!(days_in_month(2024, 2), 29); // Leap year
        assert_eq!(days_in_month(2023, 2), 28); // Non-leap year
        assert_eq!(days_in_month(2024, 4), 30);
        assert_eq!(days_in_month(2024, 7), 31);
    }
}
