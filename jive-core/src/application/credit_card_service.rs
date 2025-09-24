//! Credit Card Service - 信用卡管理服务
//!
//! 基于 Maybe 的完整信用卡管理实现，包括账单周期、还款管理、多币种、奖励等功能

use chrono::{DateTime, Datelike, Duration, NaiveDate, Utc};
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

use crate::application::{ServiceContext, ServiceResponse};
use crate::domain::{Account, AccountType, Transaction, TransactionType};
use crate::error::{JiveError, Result};

/// 信用卡服务
pub struct CreditCardService {
    // 依赖注入
}

impl CreditCardService {
    pub fn new() -> Self {
        Self {}
    }

    /// 创建信用卡账户
    pub async fn create_credit_card(
        &self,
        context: ServiceContext,
        request: CreateCreditCardRequest,
    ) -> Result<ServiceResponse<CreditCard>> {
        // 权限检查
        if !context.has_permission_str("create_accounts") {
            return Err(JiveError::Forbidden(
                "No permission to create accounts".into(),
            ));
        }

        let credit_card = CreditCard {
            id: Uuid::new_v4().to_string(),
            family_id: context.family_id.clone(),
            name: request.name,
            card_number_last4: request.card_number_last4,

            // 银行信息
            bank_code: request.bank_code,
            bank_name: request.bank_name,
            card_type: request.card_type.unwrap_or(CardType::Standard),
            card_network: request.card_network.unwrap_or(CardNetwork::Visa),

            // 额度管理
            credit_limit_type: request
                .credit_limit_type
                .unwrap_or(CreditLimitType::Individual),
            credit_limit: request.credit_limit,
            shared_limit_group_id: request.shared_limit_group_id,
            shared_limit_total: request.shared_limit_total,

            // 账单周期
            bill_date: request.bill_date,
            payment_date_type: request
                .payment_date_type
                .unwrap_or(PaymentDateType::FixedDate),
            payment_date: request.payment_date,
            payment_days_after_bill: request.payment_days_after_bill,
            bill_calculation_in_previous_period: request
                .bill_calculation_in_previous_period
                .unwrap_or(false),
            grace_period_days: request.grace_period_days.unwrap_or(21),

            // 利率和费用
            annual_fee: request.annual_fee.unwrap_or(Decimal::ZERO),
            apr: request
                .apr
                .unwrap_or(Decimal::from_str_exact("0.1899").unwrap()),
            cash_advance_apr: request.cash_advance_apr,
            penalty_apr: request.penalty_apr,
            foreign_transaction_fee: request
                .foreign_transaction_fee
                .unwrap_or(Decimal::from_str_exact("0.03").unwrap()),
            late_payment_fee: request.late_payment_fee,

            // 奖励计划
            rewards_program: request.rewards_program,
            base_rewards_rate: request
                .base_rewards_rate
                .unwrap_or(Decimal::from_str_exact("0.01").unwrap()),
            category_rewards: request.category_rewards.unwrap_or_default(),
            rewards_cap: request.rewards_cap,

            // 多币种
            supported_currencies: request
                .supported_currencies
                .unwrap_or_else(|| vec!["USD".to_string()]),
            foreign_balances: HashMap::new(),
            exchange_rates: HashMap::new(),
            auto_convert_currency: request.auto_convert_currency.unwrap_or(false),

            // 余额和状态
            current_balance: Decimal::ZERO,
            available_credit: request.credit_limit,
            minimum_payment: Decimal::ZERO,
            total_rewards_earned: Decimal::ZERO,
            status: CardStatus::Active,

            // 元数据
            created_at: Utc::now(),
            updated_at: Utc::now(),
            activated_at: Some(Utc::now()),
            expires_at: request.expires_at,
        };

        // TODO: 保存到数据库

        Ok(ServiceResponse::success_with_message(
            credit_card,
            "Credit card created successfully".to_string(),
        ))
    }

    /// 计算账单周期
    pub async fn calculate_billing_cycle(
        &self,
        context: ServiceContext,
        card_id: String,
        reference_date: Option<NaiveDate>,
    ) -> Result<ServiceResponse<BillingCycle>> {
        let card = self.get_credit_card(&context.family_id, &card_id).await?;
        let for_date = reference_date.unwrap_or_else(|| Utc::now().date_naive());

        let (start_date, end_date) = if card.bill_calculation_in_previous_period {
            // 账单算在上一期
            if for_date.day() <= card.bill_date {
                // 当前月账单周期：上上月账单日+1 到 上月账单日
                let prev_prev_month = for_date
                    .with_day(1)
                    .unwrap()
                    .pred_opt()
                    .unwrap()
                    .pred_opt()
                    .unwrap();
                let prev_month = for_date.with_day(1).unwrap().pred_opt().unwrap();

                let start = prev_prev_month
                    .with_day(card.bill_date.min(days_in_month(prev_prev_month)))
                    .unwrap()
                    .succ_opt()
                    .unwrap();
                let end = prev_month
                    .with_day(card.bill_date.min(days_in_month(prev_month)))
                    .unwrap();
                (start, end)
            } else {
                // 下月账单周期：上月账单日+1 到 当月账单日
                let prev_month = for_date.with_day(1).unwrap().pred_opt().unwrap();

                let start = prev_month
                    .with_day(card.bill_date.min(days_in_month(prev_month)))
                    .unwrap()
                    .succ_opt()
                    .unwrap();
                let end = for_date
                    .with_day(card.bill_date.min(days_in_month(for_date)))
                    .unwrap();
                (start, end)
            }
        } else {
            // 常规账单周期计算
            if for_date.day() <= card.bill_date {
                // 本月账单周期：上月账单日+1 到 本月账单日
                let prev_month = for_date.with_day(1).unwrap().pred_opt().unwrap();

                let start = prev_month
                    .with_day(card.bill_date.min(days_in_month(prev_month)))
                    .unwrap()
                    .succ_opt()
                    .unwrap();
                let end = for_date
                    .with_day(card.bill_date.min(days_in_month(for_date)))
                    .unwrap();
                (start, end)
            } else {
                // 下月账单周期：本月账单日+1 到 下月账单日
                let next_month = for_date.with_day(1).unwrap().succ_opt().unwrap();

                let start = for_date
                    .with_day(card.bill_date.min(days_in_month(for_date)))
                    .unwrap()
                    .succ_opt()
                    .unwrap();
                let end = next_month
                    .with_day(card.bill_date.min(days_in_month(next_month)))
                    .unwrap();
                (start, end)
            }
        };

        // 计算还款日期
        let payment_due_date = self.calculate_payment_due_date(&card, end)?;

        // 获取周期内的交易
        let transactions = self
            .get_transactions_for_period(&context.family_id, &card_id, start, end)
            .await?;

        // 计算金额
        let purchases = transactions
            .iter()
            .filter(|t| t.transaction_type == TransactionType::Purchase)
            .map(|t| t.amount)
            .sum();

        let payments = transactions
            .iter()
            .filter(|t| t.transaction_type == TransactionType::Payment)
            .map(|t| t.amount)
            .sum();

        let fees = transactions
            .iter()
            .filter(|t| t.transaction_type == TransactionType::Fee)
            .map(|t| t.amount)
            .sum();

        let interest = self.calculate_interest(&card, &transactions)?;

        let cycle = BillingCycle {
            card_id: card_id.clone(),
            start_date,
            end_date,
            statement_date: end_date,
            payment_due_date,

            previous_balance: card.current_balance,
            purchases,
            payments,
            fees,
            interest,

            new_balance: card.current_balance + purchases - payments + fees + interest,
            minimum_payment: self.calculate_minimum_payment(
                card.current_balance + purchases - payments + fees + interest,
                &card,
            )?,

            transactions: transactions.len(),
            grace_period_active: payments >= card.minimum_payment,
        };

        Ok(ServiceResponse::success(cycle))
    }

    /// 计算还款日期
    fn calculate_payment_due_date(
        &self,
        card: &CreditCard,
        bill_date: NaiveDate,
    ) -> Result<NaiveDate> {
        match card.payment_date_type {
            PaymentDateType::FixedDate => {
                // 固定日期
                let payment_day = card.payment_date.min(days_in_month(bill_date));
                if payment_day > bill_date.day() {
                    // 还款日在同月
                    Ok(bill_date.with_day(payment_day).unwrap())
                } else {
                    // 还款日在下月
                    let next_month = bill_date.with_day(1).unwrap().succ_opt().unwrap();
                    Ok(next_month
                        .with_day(payment_day.min(days_in_month(next_month)))
                        .unwrap())
                }
            }
            PaymentDateType::DaysAfterBill => {
                // 出账日后N天
                let days = card.payment_days_after_bill.unwrap_or(25);
                Ok(bill_date + Duration::days(days as i64))
            }
        }
    }

    /// 计算最低还款额
    fn calculate_minimum_payment(&self, balance: Decimal, card: &CreditCard) -> Result<Decimal> {
        if balance <= Decimal::ZERO {
            return Ok(Decimal::ZERO);
        }

        // 一般规则：余额的2%或25美元，取较大值
        let percentage_based = balance * Decimal::from_str_exact("0.02").unwrap();
        let minimum_fixed = Decimal::from(25);

        let minimum = percentage_based.max(minimum_fixed);

        // 如果余额小于最低固定金额，则全额还款
        if balance < minimum_fixed {
            Ok(balance)
        } else {
            Ok(minimum.min(balance))
        }
    }

    /// 计算利息
    fn calculate_interest(
        &self,
        card: &CreditCard,
        transactions: &[CreditCardTransaction],
    ) -> Result<Decimal> {
        // 简化计算：如果有未还清余额且没有在宽限期内全额还款
        if card.current_balance > Decimal::ZERO {
            let daily_rate = card.apr / Decimal::from(365);
            let days_in_cycle = 30; // 简化为30天
            Ok(card.current_balance * daily_rate * Decimal::from(days_in_cycle))
        } else {
            Ok(Decimal::ZERO)
        }
    }

    /// 处理信用卡交易
    pub async fn process_transaction(
        &self,
        context: ServiceContext,
        request: CreditCardTransactionRequest,
    ) -> Result<ServiceResponse<CreditCardTransaction>> {
        let mut card = self
            .get_credit_card(&context.family_id, &request.card_id)
            .await?;

        // 检查卡片状态
        if card.status != CardStatus::Active {
            return Err(JiveError::ValidationError("Card is not active".into()));
        }

        // 处理不同类型的交易
        let transaction = match request.transaction_type {
            TransactionType::Purchase => self.process_purchase(&mut card, &request).await?,
            TransactionType::Payment => self.process_payment(&mut card, &request).await?,
            TransactionType::CashAdvance => self.process_cash_advance(&mut card, &request).await?,
            TransactionType::Refund => self.process_refund(&mut card, &request).await?,
            _ => {
                return Err(JiveError::ValidationError(
                    "Invalid transaction type".into(),
                ));
            }
        };

        // 更新卡片余额
        self.update_card_balance(&mut card).await?;

        // 计算奖励
        if request.transaction_type == TransactionType::Purchase {
            self.calculate_rewards(&mut card, &transaction).await?;
        }

        Ok(ServiceResponse::success(transaction))
    }

    /// 处理购买交易
    async fn process_purchase(
        &self,
        card: &mut CreditCard,
        request: &CreditCardTransactionRequest,
    ) -> Result<CreditCardTransaction> {
        // 检查可用额度
        if request.amount > card.available_credit {
            return Err(JiveError::ValidationError(
                "Insufficient credit limit".into(),
            ));
        }

        // 处理多币种
        let (amount_in_base, exchange_rate) = if let Some(currency) = &request.currency {
            if currency != &card.supported_currencies[0] {
                // 需要货币转换
                let rate = self
                    .get_exchange_rate(currency, &card.supported_currencies[0])
                    .await?;
                let converted = request.amount * rate;
                let fee = converted * card.foreign_transaction_fee;
                (converted + fee, Some(rate))
            } else {
                (request.amount, None)
            }
        } else {
            (request.amount, None)
        };

        let transaction = CreditCardTransaction {
            id: Uuid::new_v4().to_string(),
            card_id: card.id.clone(),
            transaction_type: TransactionType::Purchase,
            amount: request.amount,
            amount_in_base_currency: amount_in_base,
            currency: request.currency.clone(),
            exchange_rate,

            merchant: request.merchant.clone(),
            category: request.category.clone(),
            description: request.description.clone(),

            transaction_date: request
                .transaction_date
                .unwrap_or_else(|| Utc::now().date_naive()),
            post_date: Some(Utc::now().date_naive()),

            rewards_earned: None, // 将在后续计算

            status: TransactionStatus::Posted,
            reference_number: Some(Uuid::new_v4().to_string()),

            created_at: Utc::now(),
        };

        // 更新卡片余额
        card.current_balance += amount_in_base;
        card.available_credit -= amount_in_base;

        // 更新外币余额（如果适用）
        if let Some(currency) = &request.currency {
            if currency != &card.supported_currencies[0] && !card.auto_convert_currency {
                let foreign_balance = card
                    .foreign_balances
                    .entry(currency.clone())
                    .or_insert(Decimal::ZERO);
                *foreign_balance += request.amount;
            }
        }

        Ok(transaction)
    }

    /// 处理付款
    async fn process_payment(
        &self,
        card: &mut CreditCard,
        request: &CreditCardTransactionRequest,
    ) -> Result<CreditCardTransaction> {
        let transaction = CreditCardTransaction {
            id: Uuid::new_v4().to_string(),
            card_id: card.id.clone(),
            transaction_type: TransactionType::Payment,
            amount: request.amount,
            amount_in_base_currency: request.amount,
            currency: None,
            exchange_rate: None,

            merchant: None,
            category: Some("Payment".to_string()),
            description: request
                .description
                .clone()
                .unwrap_or("Payment received".to_string()),

            transaction_date: request
                .transaction_date
                .unwrap_or_else(|| Utc::now().date_naive()),
            post_date: Some(Utc::now().date_naive()),

            rewards_earned: None,

            status: TransactionStatus::Posted,
            reference_number: Some(Uuid::new_v4().to_string()),

            created_at: Utc::now(),
        };

        // 更新余额
        card.current_balance -= request.amount.min(card.current_balance);
        card.available_credit += request.amount;
        if card.available_credit > card.credit_limit {
            card.available_credit = card.credit_limit;
        }

        Ok(transaction)
    }

    /// 处理现金预支
    async fn process_cash_advance(
        &self,
        card: &mut CreditCard,
        request: &CreditCardTransactionRequest,
    ) -> Result<CreditCardTransaction> {
        // 现金预支通常有更高的利率和费用
        let fee = request.amount * Decimal::from_str_exact("0.05").unwrap(); // 5% 费用
        let total_amount = request.amount + fee;

        if total_amount > card.available_credit {
            return Err(JiveError::ValidationError(
                "Insufficient credit for cash advance".into(),
            ));
        }

        let transaction = CreditCardTransaction {
            id: Uuid::new_v4().to_string(),
            card_id: card.id.clone(),
            transaction_type: TransactionType::CashAdvance,
            amount: request.amount,
            amount_in_base_currency: total_amount,
            currency: None,
            exchange_rate: None,

            merchant: None,
            category: Some("Cash Advance".to_string()),
            description: request
                .description
                .clone()
                .unwrap_or("Cash advance".to_string()),

            transaction_date: request
                .transaction_date
                .unwrap_or_else(|| Utc::now().date_naive()),
            post_date: Some(Utc::now().date_naive()),

            rewards_earned: None, // 现金预支通常不获得奖励

            status: TransactionStatus::Posted,
            reference_number: Some(Uuid::new_v4().to_string()),

            created_at: Utc::now(),
        };

        card.current_balance += total_amount;
        card.available_credit -= total_amount;

        Ok(transaction)
    }

    /// 处理退款
    async fn process_refund(
        &self,
        card: &mut CreditCard,
        request: &CreditCardTransactionRequest,
    ) -> Result<CreditCardTransaction> {
        let transaction = CreditCardTransaction {
            id: Uuid::new_v4().to_string(),
            card_id: card.id.clone(),
            transaction_type: TransactionType::Refund,
            amount: request.amount,
            amount_in_base_currency: request.amount,
            currency: request.currency.clone(),
            exchange_rate: None,

            merchant: request.merchant.clone(),
            category: request.category.clone(),
            description: request.description.clone().unwrap_or("Refund".to_string()),

            transaction_date: request
                .transaction_date
                .unwrap_or_else(|| Utc::now().date_naive()),
            post_date: Some(Utc::now().date_naive()),

            rewards_earned: Some(-request.amount * card.base_rewards_rate), // 扣除相应奖励

            status: TransactionStatus::Posted,
            reference_number: Some(Uuid::new_v4().to_string()),

            created_at: Utc::now(),
        };

        card.current_balance -= request.amount;
        if card.current_balance < Decimal::ZERO {
            card.current_balance = Decimal::ZERO;
        }
        card.available_credit += request.amount;
        if card.available_credit > card.credit_limit {
            card.available_credit = card.credit_limit;
        }

        Ok(transaction)
    }

    /// 计算奖励
    async fn calculate_rewards(
        &self,
        card: &mut CreditCard,
        transaction: &CreditCardTransaction,
    ) -> Result<Decimal> {
        if transaction.transaction_type != TransactionType::Purchase {
            return Ok(Decimal::ZERO);
        }

        // 基础奖励率
        let mut rewards_rate = card.base_rewards_rate;

        // 检查类别奖励
        if let Some(category) = &transaction.category {
            if let Some(category_rate) = card.category_rewards.get(category) {
                rewards_rate = rewards_rate.max(*category_rate);
            }
        }

        // 计算奖励
        let mut rewards = transaction.amount * rewards_rate;

        // 应用奖励上限
        if let Some(cap) = card.rewards_cap {
            let monthly_rewards = self.get_monthly_rewards(card).await?;
            if monthly_rewards + rewards > cap {
                rewards = (cap - monthly_rewards).max(Decimal::ZERO);
            }
        }

        // 更新总奖励
        card.total_rewards_earned += rewards;

        Ok(rewards)
    }

    /// 管理共享额度
    pub async fn manage_shared_limit(
        &self,
        context: ServiceContext,
        request: SharedLimitRequest,
    ) -> Result<ServiceResponse<SharedLimitInfo>> {
        // 获取共享组中的所有卡片
        let cards = self
            .get_cards_in_shared_group(&context.family_id, &request.shared_limit_group_id)
            .await?;

        // 计算总使用额度
        let total_used: Decimal = cards.iter().map(|c| c.current_balance).sum();
        let total_limit = cards
            .first()
            .and_then(|c| c.shared_limit_total)
            .unwrap_or(Decimal::ZERO);

        let available = (total_limit - total_used).max(Decimal::ZERO);

        let info = SharedLimitInfo {
            group_id: request.shared_limit_group_id.clone(),
            total_limit,
            total_used,
            available,
            cards: cards
                .into_iter()
                .map(|c| CardSummary {
                    card_id: c.id,
                    card_name: c.name,
                    current_balance: c.current_balance,
                    percentage_used: if total_limit > Decimal::ZERO {
                        (c.current_balance / total_limit * Decimal::from(100)).round_dp(2)
                    } else {
                        Decimal::ZERO
                    },
                })
                .collect(),
            updated_at: Utc::now(),
        };

        Ok(ServiceResponse::success(info))
    }

    /// 获取奖励报告
    pub async fn get_rewards_report(
        &self,
        context: ServiceContext,
        card_id: String,
        period: RewardsPeriod,
    ) -> Result<ServiceResponse<RewardsReport>> {
        let card = self.get_credit_card(&context.family_id, &card_id).await?;

        let (start_date, end_date) = match period {
            RewardsPeriod::CurrentMonth => {
                let now = Utc::now().date_naive();
                (now.with_day(1).unwrap(), now)
            }
            RewardsPeriod::LastMonth => {
                let now = Utc::now().date_naive();
                let last_month = now.with_day(1).unwrap().pred_opt().unwrap();
                (last_month.with_day(1).unwrap(), last_month)
            }
            RewardsPeriod::YearToDate => {
                let now = Utc::now().date_naive();
                (now.with_month(1).unwrap().with_day(1).unwrap(), now)
            }
            RewardsPeriod::Custom(start, end) => (start, end),
        };

        // 获取期间内的交易
        let transactions = self
            .get_transactions_for_period(&context.family_id, &card_id, start_date, end_date)
            .await?;

        // 按类别统计奖励
        let mut rewards_by_category: HashMap<String, Decimal> = HashMap::new();
        let mut total_rewards = Decimal::ZERO;

        for tx in &transactions {
            if let Some(rewards) = tx.rewards_earned {
                total_rewards += rewards;

                let category = tx.category.clone().unwrap_or("Other".to_string());
                *rewards_by_category.entry(category).or_insert(Decimal::ZERO) += rewards;
            }
        }

        // 计算奖励价值（假设1点=1分钱）
        let rewards_value = total_rewards / Decimal::from(100);

        let report = RewardsReport {
            card_id: card_id.clone(),
            period_start: start_date,
            period_end: end_date,

            total_rewards_earned: total_rewards,
            rewards_value,
            rewards_by_category,

            total_purchases: transactions
                .iter()
                .filter(|t| t.transaction_type == TransactionType::Purchase)
                .map(|t| t.amount)
                .sum(),

            average_rewards_rate: if transactions.is_empty() {
                Decimal::ZERO
            } else {
                total_rewards / Decimal::from(transactions.len())
            },

            lifetime_rewards: card.total_rewards_earned,

            generated_at: Utc::now(),
        };

        Ok(ServiceResponse::success(report))
    }

    /// 优化信用卡使用建议
    pub async fn get_optimization_suggestions(
        &self,
        context: ServiceContext,
        card_id: String,
    ) -> Result<ServiceResponse<Vec<OptimizationSuggestion>>> {
        let card = self.get_credit_card(&context.family_id, &card_id).await?;
        let mut suggestions = Vec::new();

        // 1. 利用率建议
        let utilization = card.current_balance / card.credit_limit * Decimal::from(100);
        if utilization > Decimal::from(30) {
            suggestions.push(OptimizationSuggestion {
                category: SuggestionCategory::Utilization,
                title: "High Credit Utilization".to_string(),
                description: format!(
                    "Your credit utilization is {:.1}%. Keep it below 30% for better credit score.",
                    utilization
                ),
                impact: ImpactLevel::High,
                potential_savings: None,
            });
        }

        // 2. 奖励优化
        if card.rewards_program.is_some() {
            suggestions.push(OptimizationSuggestion {
                category: SuggestionCategory::Rewards,
                title: "Maximize Category Rewards".to_string(),
                description:
                    "Use this card for purchases in bonus categories to earn more rewards."
                        .to_string(),
                impact: ImpactLevel::Medium,
                potential_savings: Some(
                    card.total_rewards_earned * Decimal::from_str_exact("0.2").unwrap(),
                ),
            });
        }

        // 3. 年费分析
        if card.annual_fee > Decimal::ZERO {
            let rewards_value = card.total_rewards_earned / Decimal::from(100);
            if rewards_value < card.annual_fee {
                suggestions.push(OptimizationSuggestion {
                    category: SuggestionCategory::Fees,
                    title: "Annual Fee vs Rewards".to_string(),
                    description: format!(
                        "Your rewards value (${}) is less than the annual fee (${}). Consider a no-fee card.",
                        rewards_value, card.annual_fee
                    ),
                    impact: ImpactLevel::High,
                    potential_savings: Some(card.annual_fee - rewards_value),
                });
            }
        }

        // 4. 外币交易建议
        if card.foreign_transaction_fee > Decimal::ZERO {
            suggestions.push(OptimizationSuggestion {
                category: SuggestionCategory::International,
                title: "Foreign Transaction Fees".to_string(),
                description:
                    "Consider a card with no foreign transaction fees for international purchases."
                        .to_string(),
                impact: ImpactLevel::Low,
                potential_savings: None,
            });
        }

        Ok(ServiceResponse::success(suggestions))
    }

    // 辅助方法

    async fn get_credit_card(&self, family_id: &str, card_id: &str) -> Result<CreditCard> {
        // TODO: 从数据库获取信用卡
        Err(JiveError::NotImplemented("get_credit_card".into()))
    }

    async fn update_card_balance(&self, card: &mut CreditCard) -> Result<()> {
        // TODO: 更新数据库中的余额
        Ok(())
    }

    async fn get_transactions_for_period(
        &self,
        family_id: &str,
        card_id: &str,
        start_date: NaiveDate,
        end_date: NaiveDate,
    ) -> Result<Vec<CreditCardTransaction>> {
        // TODO: 从数据库获取期间内的交易
        Ok(Vec::new())
    }

    async fn get_exchange_rate(&self, from: &str, to: &str) -> Result<Decimal> {
        // TODO: 获取实时汇率
        Ok(Decimal::from_str_exact("1.0").unwrap())
    }

    async fn get_monthly_rewards(&self, card: &CreditCard) -> Result<Decimal> {
        // TODO: 获取当月奖励总额
        Ok(Decimal::ZERO)
    }

    async fn get_cards_in_shared_group(
        &self,
        family_id: &str,
        group_id: &str,
    ) -> Result<Vec<CreditCard>> {
        // TODO: 获取共享组中的所有卡片
        Ok(Vec::new())
    }
}

// ========== 数据结构定义 ==========

/// 信用卡
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreditCard {
    pub id: String,
    pub family_id: String,
    pub name: String,
    pub card_number_last4: Option<String>,

    // 银行信息
    pub bank_code: String,
    pub bank_name: Option<String>,
    pub card_type: CardType,
    pub card_network: CardNetwork,

    // 额度管理
    pub credit_limit_type: CreditLimitType,
    pub credit_limit: Decimal,
    pub shared_limit_group_id: Option<String>,
    pub shared_limit_total: Option<Decimal>,

    // 账单周期
    pub bill_date: u32, // 每月的账单日（1-31）
    pub payment_date_type: PaymentDateType,
    pub payment_date: u32,                         // 固定还款日
    pub payment_days_after_bill: Option<u32>,      // 出账后N天
    pub bill_calculation_in_previous_period: bool, // 账单算在上一期
    pub grace_period_days: u32,

    // 利率和费用
    pub annual_fee: Decimal,
    pub apr: Decimal, // 年利率
    pub cash_advance_apr: Option<Decimal>,
    pub penalty_apr: Option<Decimal>,
    pub foreign_transaction_fee: Decimal,
    pub late_payment_fee: Option<Decimal>,

    // 奖励计划
    pub rewards_program: Option<RewardsProgram>,
    pub base_rewards_rate: Decimal,
    pub category_rewards: HashMap<String, Decimal>,
    pub rewards_cap: Option<Decimal>,

    // 多币种支持
    pub supported_currencies: Vec<String>,
    pub foreign_balances: HashMap<String, Decimal>,
    pub exchange_rates: HashMap<String, Decimal>,
    pub auto_convert_currency: bool,

    // 余额和状态
    pub current_balance: Decimal,
    pub available_credit: Decimal,
    pub minimum_payment: Decimal,
    pub total_rewards_earned: Decimal,
    pub status: CardStatus,

    // 元数据
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub activated_at: Option<DateTime<Utc>>,
    pub expires_at: Option<NaiveDate>,
}

/// 卡片类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CardType {
    Standard,
    Gold,
    Platinum,
    Signature,
    Infinite,
    Business,
    Student,
    Secured,
}

/// 卡片网络
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CardNetwork {
    Visa,
    Mastercard,
    AmericanExpress,
    Discover,
    UnionPay,
    JCB,
    DinersClub,
}

/// 额度类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CreditLimitType {
    Individual, // 个人额度
    Shared,     // 共享额度
}

/// 还款日期类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum PaymentDateType {
    FixedDate,     // 固定日期
    DaysAfterBill, // 出账后N天
}

/// 卡片状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum CardStatus {
    Active,
    Frozen,
    Closed,
    Lost,
    Stolen,
}

/// 奖励计划
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RewardsProgram {
    pub name: String,
    pub program_type: RewardsProgramType,
    pub point_value: Decimal, // 每个点的价值
    pub redemption_options: Vec<RedemptionOption>,
}

/// 奖励计划类型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RewardsProgramType {
    CashBack,
    Points,
    Miles,
    Hotel,
}

/// 兑换选项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RedemptionOption {
    pub name: String,
    pub minimum_points: Decimal,
    pub redemption_rate: Decimal,
}

/// 信用卡交易
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreditCardTransaction {
    pub id: String,
    pub card_id: String,
    pub transaction_type: TransactionType,
    pub amount: Decimal,
    pub amount_in_base_currency: Decimal,
    pub currency: Option<String>,
    pub exchange_rate: Option<Decimal>,

    pub merchant: Option<String>,
    pub category: Option<String>,
    pub description: Option<String>,

    pub transaction_date: NaiveDate,
    pub post_date: Option<NaiveDate>,

    pub rewards_earned: Option<Decimal>,

    pub status: TransactionStatus,
    pub reference_number: Option<String>,

    pub created_at: DateTime<Utc>,
}

/// 交易类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TransactionType {
    Purchase,
    Payment,
    CashAdvance,
    BalanceTransfer,
    Fee,
    Interest,
    Refund,
}

/// 交易状态
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TransactionStatus {
    Pending,
    Posted,
    Disputed,
    Reversed,
}

/// 账单周期
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BillingCycle {
    pub card_id: String,
    pub start_date: NaiveDate,
    pub end_date: NaiveDate,
    pub statement_date: NaiveDate,
    pub payment_due_date: NaiveDate,

    pub previous_balance: Decimal,
    pub purchases: Decimal,
    pub payments: Decimal,
    pub fees: Decimal,
    pub interest: Decimal,

    pub new_balance: Decimal,
    pub minimum_payment: Decimal,

    pub transactions: usize,
    pub grace_period_active: bool,
}

/// 共享额度信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedLimitInfo {
    pub group_id: String,
    pub total_limit: Decimal,
    pub total_used: Decimal,
    pub available: Decimal,
    pub cards: Vec<CardSummary>,
    pub updated_at: DateTime<Utc>,
}

/// 卡片摘要
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CardSummary {
    pub card_id: String,
    pub card_name: String,
    pub current_balance: Decimal,
    pub percentage_used: Decimal,
}

/// 奖励报告
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RewardsReport {
    pub card_id: String,
    pub period_start: NaiveDate,
    pub period_end: NaiveDate,

    pub total_rewards_earned: Decimal,
    pub rewards_value: Decimal,
    pub rewards_by_category: HashMap<String, Decimal>,

    pub total_purchases: Decimal,
    pub average_rewards_rate: Decimal,

    pub lifetime_rewards: Decimal,

    pub generated_at: DateTime<Utc>,
}

/// 奖励期间
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RewardsPeriod {
    CurrentMonth,
    LastMonth,
    YearToDate,
    Custom(NaiveDate, NaiveDate),
}

/// 优化建议
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OptimizationSuggestion {
    pub category: SuggestionCategory,
    pub title: String,
    pub description: String,
    pub impact: ImpactLevel,
    pub potential_savings: Option<Decimal>,
}

/// 建议类别
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SuggestionCategory {
    Utilization,
    Rewards,
    Fees,
    International,
    Balance,
}

/// 影响级别
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ImpactLevel {
    High,
    Medium,
    Low,
}

// 请求和响应结构

/// 创建信用卡请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateCreditCardRequest {
    pub name: String,
    pub card_number_last4: Option<String>,

    pub bank_code: String,
    pub bank_name: Option<String>,
    pub card_type: Option<CardType>,
    pub card_network: Option<CardNetwork>,

    pub credit_limit_type: Option<CreditLimitType>,
    pub credit_limit: Decimal,
    pub shared_limit_group_id: Option<String>,
    pub shared_limit_total: Option<Decimal>,

    pub bill_date: u32,
    pub payment_date_type: Option<PaymentDateType>,
    pub payment_date: u32,
    pub payment_days_after_bill: Option<u32>,
    pub bill_calculation_in_previous_period: Option<bool>,
    pub grace_period_days: Option<u32>,

    pub annual_fee: Option<Decimal>,
    pub apr: Option<Decimal>,
    pub cash_advance_apr: Option<Decimal>,
    pub penalty_apr: Option<Decimal>,
    pub foreign_transaction_fee: Option<Decimal>,
    pub late_payment_fee: Option<Decimal>,

    pub rewards_program: Option<RewardsProgram>,
    pub base_rewards_rate: Option<Decimal>,
    pub category_rewards: Option<HashMap<String, Decimal>>,
    pub rewards_cap: Option<Decimal>,

    pub supported_currencies: Option<Vec<String>>,
    pub auto_convert_currency: Option<bool>,

    pub expires_at: Option<NaiveDate>,
}

/// 信用卡交易请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreditCardTransactionRequest {
    pub card_id: String,
    pub transaction_type: TransactionType,
    pub amount: Decimal,
    pub currency: Option<String>,

    pub merchant: Option<String>,
    pub category: Option<String>,
    pub description: Option<String>,

    pub transaction_date: Option<NaiveDate>,
}

/// 共享额度请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SharedLimitRequest {
    pub shared_limit_group_id: String,
}

// 辅助函数
fn days_in_month(date: NaiveDate) -> u32 {
    let year = date.year();
    let month = date.month();

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
    use rust_decimal_macros::dec;

    #[test]
    fn test_billing_cycle_calculation() {
        let card = CreditCard {
            id: "test".to_string(),
            family_id: "family".to_string(),
            name: "Test Card".to_string(),
            card_number_last4: Some("1234".to_string()),
            bank_code: "TEST".to_string(),
            bank_name: None,
            card_type: CardType::Standard,
            card_network: CardNetwork::Visa,
            credit_limit_type: CreditLimitType::Individual,
            credit_limit: dec!(5000),
            shared_limit_group_id: None,
            shared_limit_total: None,
            bill_date: 15,
            payment_date_type: PaymentDateType::FixedDate,
            payment_date: 10,
            payment_days_after_bill: None,
            bill_calculation_in_previous_period: false,
            grace_period_days: 21,
            annual_fee: dec!(0),
            apr: dec!(0.1899),
            cash_advance_apr: None,
            penalty_apr: None,
            foreign_transaction_fee: dec!(0.03),
            late_payment_fee: None,
            rewards_program: None,
            base_rewards_rate: dec!(0.01),
            category_rewards: HashMap::new(),
            rewards_cap: None,
            supported_currencies: vec!["USD".to_string()],
            foreign_balances: HashMap::new(),
            exchange_rates: HashMap::new(),
            auto_convert_currency: false,
            current_balance: dec!(1000),
            available_credit: dec!(4000),
            minimum_payment: dec!(25),
            total_rewards_earned: dec!(100),
            status: CardStatus::Active,
            created_at: Utc::now(),
            updated_at: Utc::now(),
            activated_at: Some(Utc::now()),
            expires_at: None,
        };

        let service = CreditCardService::new();
        let due_date = service
            .calculate_payment_due_date(&card, NaiveDate::from_ymd_opt(2024, 1, 15).unwrap())
            .unwrap();

        assert_eq!(due_date, NaiveDate::from_ymd_opt(2024, 2, 10).unwrap());
    }

    #[test]
    fn test_minimum_payment_calculation() {
        let service = CreditCardService::new();
        let card = CreditCard {
            id: "test".to_string(),
            family_id: "family".to_string(),
            name: "Test Card".to_string(),
            card_number_last4: None,
            bank_code: "TEST".to_string(),
            bank_name: None,
            card_type: CardType::Standard,
            card_network: CardNetwork::Visa,
            credit_limit_type: CreditLimitType::Individual,
            credit_limit: dec!(5000),
            shared_limit_group_id: None,
            shared_limit_total: None,
            bill_date: 15,
            payment_date_type: PaymentDateType::FixedDate,
            payment_date: 10,
            payment_days_after_bill: None,
            bill_calculation_in_previous_period: false,
            grace_period_days: 21,
            annual_fee: dec!(0),
            apr: dec!(0.1899),
            cash_advance_apr: None,
            penalty_apr: None,
            foreign_transaction_fee: dec!(0.03),
            late_payment_fee: None,
            rewards_program: None,
            base_rewards_rate: dec!(0.01),
            category_rewards: HashMap::new(),
            rewards_cap: None,
            supported_currencies: vec!["USD".to_string()],
            foreign_balances: HashMap::new(),
            exchange_rates: HashMap::new(),
            auto_convert_currency: false,
            current_balance: dec!(1000),
            available_credit: dec!(4000),
            minimum_payment: dec!(25),
            total_rewards_earned: dec!(100),
            status: CardStatus::Active,
            created_at: Utc::now(),
            updated_at: Utc::now(),
            activated_at: None,
            expires_at: None,
        };

        // Test with balance > $25
        let min_payment = service
            .calculate_minimum_payment(dec!(1000), &card)
            .unwrap();
        assert_eq!(min_payment, dec!(25)); // Max of 2% (20) or $25

        // Test with small balance
        let min_payment = service.calculate_minimum_payment(dec!(10), &card).unwrap();
        assert_eq!(min_payment, dec!(10)); // Full balance when < $25
    }
}
