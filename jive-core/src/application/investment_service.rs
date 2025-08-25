//! Investment Service - 投资组合管理服务
//! 
//! 基于 Maybe 的投资管理实现，支持股票、基金、债券等多种投资品种

use std::collections::HashMap;
use serde::{Serialize, Deserialize};
use chrono::{DateTime, Utc, NaiveDate};
use rust_decimal::Decimal;
use uuid::Uuid;

use crate::domain::{Account, AccountType, Transaction};
use crate::error::{JiveError, Result};
use crate::application::{ServiceContext, ServiceResponse};

/// 投资服务
pub struct InvestmentService {
    // 依赖注入
}

impl InvestmentService {
    pub fn new() -> Self {
        Self {}
    }
    
    /// 创建投资账户
    pub async fn create_investment_account(
        &self,
        context: ServiceContext,
        request: CreateInvestmentAccountRequest,
    ) -> Result<ServiceResponse<InvestmentAccount>> {
        // 权限检查
        if !context.has_permission_str("create_accounts") {
            return Err(JiveError::Forbidden("No permission to create accounts".into()));
        }
        
        let account = InvestmentAccount {
            id: Uuid::new_v4().to_string(),
            family_id: context.family_id.clone(),
            name: request.name,
            account_type: request.account_type,
            broker: request.broker,
            account_number: request.account_number,
            
            // 余额信息
            cash_balance: request.initial_cash.unwrap_or(Decimal::ZERO),
            total_value: request.initial_cash.unwrap_or(Decimal::ZERO),
            
            // 收益信息
            total_cost: Decimal::ZERO,
            total_gain_loss: Decimal::ZERO,
            total_gain_loss_percent: Decimal::ZERO,
            daily_change: Decimal::ZERO,
            daily_change_percent: Decimal::ZERO,
            
            // 持仓信息
            holdings: Vec::new(),
            
            // 配置
            currency: request.currency,
            tax_advantaged: request.tax_advantaged.unwrap_or(false),
            margin_enabled: request.margin_enabled.unwrap_or(false),
            options_enabled: request.options_enabled.unwrap_or(false),
            
            // 元数据
            created_at: Utc::now(),
            updated_at: Utc::now(),
            last_synced: None,
        };
        
        // TODO: 保存到数据库
        
        Ok(ServiceResponse::success_with_message(
            account,
            "Investment account created successfully".to_string()
        ))
    }
    
    /// 创建证券
    pub async fn create_security(
        &self,
        context: ServiceContext,
        request: CreateSecurityRequest,
    ) -> Result<ServiceResponse<Security>> {
        // 权限检查
        if !context.has_permission_str("manage_investments") {
            return Err(JiveError::Forbidden("No permission to manage investments".into()));
        }
        
        // 检查证券是否已存在
        if self.security_exists(&request.ticker, request.exchange.as_deref()).await? {
            return Err(JiveError::AlreadyExists(format!("Security {} already exists", request.ticker)));
        }
        
        let security = Security {
            id: Uuid::new_v4().to_string(),
            ticker: request.ticker.to_uppercase(),
            name: request.name,
            security_type: request.security_type,
            exchange: request.exchange,
            
            // 价格信息
            current_price: None,
            previous_close: None,
            day_change: None,
            day_change_percent: None,
            
            // 市场数据
            market_cap: request.market_cap,
            pe_ratio: request.pe_ratio,
            dividend_yield: request.dividend_yield,
            beta: request.beta,
            
            // 52周数据
            week_52_high: None,
            week_52_low: None,
            
            // 元数据
            currency: request.currency,
            country_code: request.country_code,
            sector: request.sector,
            industry: request.industry,
            
            logo_url: request.logo_url,
            description: request.description,
            
            is_active: true,
            last_updated: Utc::now(),
        };
        
        // TODO: 保存到数据库
        
        Ok(ServiceResponse::success(security))
    }
    
    /// 执行交易
    pub async fn execute_trade(
        &self,
        context: ServiceContext,
        request: TradeRequest,
    ) -> Result<ServiceResponse<Trade>> {
        // 权限检查
        if !context.has_permission_str("execute_trades") {
            return Err(JiveError::Forbidden("No permission to execute trades".into()));
        }
        
        // 获取账户和证券
        let mut account = self.get_investment_account(&context.family_id, &request.account_id).await?;
        let security = self.get_security(&request.security_id).await?;
        
        // 验证交易
        self.validate_trade(&account, &security, &request)?;
        
        // 计算交易金额
        let trade_amount = request.quantity * request.price;
        let commission = request.commission.unwrap_or(Decimal::ZERO);
        let total_amount = match request.trade_type {
            TradeType::Buy => trade_amount + commission,
            TradeType::Sell => trade_amount - commission,
        };
        
        // 检查买入时的现金余额
        if request.trade_type == TradeType::Buy && total_amount > account.cash_balance {
            return Err(JiveError::ValidationError("Insufficient cash balance".into()));
        }
        
        // 检查卖出时的持仓
        if request.trade_type == TradeType::Sell {
            let holding = account.holdings.iter()
                .find(|h| h.security_id == request.security_id)
                .ok_or_else(|| JiveError::ValidationError("No holdings to sell".into()))?;
            
            if holding.quantity < request.quantity {
                return Err(JiveError::ValidationError("Insufficient holdings".into()));
            }
        }
        
        // 创建交易记录
        let trade = Trade {
            id: Uuid::new_v4().to_string(),
            account_id: request.account_id.clone(),
            security_id: request.security_id.clone(),
            trade_type: request.trade_type.clone(),
            
            quantity: request.quantity,
            price: request.price,
            commission,
            total_amount,
            
            trade_date: request.trade_date.unwrap_or_else(|| Utc::now().date_naive()),
            settlement_date: request.settlement_date.unwrap_or_else(|| {
                // T+2 结算
                Utc::now().date_naive() + chrono::Duration::days(2)
            }),
            
            notes: request.notes,
            
            status: TradeStatus::Executed,
            created_at: Utc::now(),
        };
        
        // 更新账户余额和持仓
        self.update_account_after_trade(&mut account, &trade, &security).await?;
        
        // 更新成本基础
        self.update_cost_basis(&mut account, &trade).await?;
        
        Ok(ServiceResponse::success(trade))
    }
    
    /// 更新证券价格
    pub async fn update_security_price(
        &self,
        context: ServiceContext,
        security_id: String,
        price: Decimal,
    ) -> Result<ServiceResponse<SecurityPrice>> {
        // 权限检查
        if !context.has_permission_str("update_prices") {
            return Err(JiveError::Forbidden("No permission to update prices".into()));
        }
        
        let mut security = self.get_security(&security_id).await?;
        
        // 保存历史价格
        let price_record = SecurityPrice {
            id: Uuid::new_v4().to_string(),
            security_id: security_id.clone(),
            date: Utc::now().date_naive(),
            price,
            volume: None,
            source: PriceSource::Manual,
            created_at: Utc::now(),
        };
        
        // 更新证券当前价格
        let previous_price = security.current_price;
        security.current_price = Some(price);
        security.previous_close = previous_price;
        
        if let Some(prev) = previous_price {
            security.day_change = Some(price - prev);
            security.day_change_percent = Some((price - prev) / prev * Decimal::from(100));
        }
        
        security.last_updated = Utc::now();
        
        // TODO: 保存到数据库
        self.save_security(&security).await?;
        self.save_price_record(&price_record).await?;
        
        // 更新所有持有该证券的账户价值
        self.update_accounts_with_security(&security_id, price).await?;
        
        Ok(ServiceResponse::success(price_record))
    }
    
    /// 获取持仓信息
    pub async fn get_holdings(
        &self,
        context: ServiceContext,
        account_id: String,
    ) -> Result<ServiceResponse<Vec<HoldingDetail>>> {
        // 权限检查
        if !context.has_permission_str("view_investments") {
            return Err(JiveError::Forbidden("No permission to view investments".into()));
        }
        
        let account = self.get_investment_account(&context.family_id, &account_id).await?;
        let mut holdings_detail = Vec::new();
        
        for holding in &account.holdings {
            let security = self.get_security(&holding.security_id).await?;
            let current_price = security.current_price.unwrap_or(holding.avg_cost);
            let current_value = holding.quantity * current_price;
            let cost_basis = holding.quantity * holding.avg_cost;
            let gain_loss = current_value - cost_basis;
            let gain_loss_percent = if cost_basis != Decimal::ZERO {
                (gain_loss / cost_basis * Decimal::from(100)).round_dp(2)
            } else {
                Decimal::ZERO
            };
            
            let detail = HoldingDetail {
                holding: holding.clone(),
                security: security.clone(),
                current_value,
                cost_basis,
                gain_loss,
                gain_loss_percent,
                weight: if account.total_value > Decimal::ZERO {
                    (current_value / account.total_value * Decimal::from(100)).round_dp(2)
                } else {
                    Decimal::ZERO
                },
                day_change: security.day_change.map(|c| c * holding.quantity),
                day_change_percent: security.day_change_percent,
            };
            
            holdings_detail.push(detail);
        }
        
        // 按价值排序
        holdings_detail.sort_by(|a, b| b.current_value.cmp(&a.current_value));
        
        Ok(ServiceResponse::success(holdings_detail))
    }
    
    /// 获取投资组合分析
    pub async fn analyze_portfolio(
        &self,
        context: ServiceContext,
        account_id: String,
    ) -> Result<ServiceResponse<PortfolioAnalysis>> {
        let account = self.get_investment_account(&context.family_id, &account_id).await?;
        let holdings = self.get_holdings(context.clone(), account_id.clone()).await?.data.unwrap();
        
        // 资产配置分析
        let mut asset_allocation = HashMap::new();
        let mut sector_allocation = HashMap::new();
        let mut geographic_allocation = HashMap::new();
        
        for holding in &holdings {
            // 按资产类型
            let asset_type = holding.security.security_type.to_string();
            *asset_allocation.entry(asset_type).or_insert(Decimal::ZERO) += holding.current_value;
            
            // 按行业
            if let Some(sector) = &holding.security.sector {
                *sector_allocation.entry(sector.clone()).or_insert(Decimal::ZERO) += holding.current_value;
            }
            
            // 按地理位置
            if let Some(country) = &holding.security.country_code {
                *geographic_allocation.entry(country.clone()).or_insert(Decimal::ZERO) += holding.current_value;
            }
        }
        
        // 计算百分比
        let total_value = account.total_value;
        let convert_to_percentage = |allocation: HashMap<String, Decimal>| -> Vec<AllocationItem> {
            let mut items: Vec<AllocationItem> = allocation.into_iter()
                .map(|(name, value)| AllocationItem {
                    name,
                    value,
                    percentage: if total_value > Decimal::ZERO {
                        (value / total_value * Decimal::from(100)).round_dp(2)
                    } else {
                        Decimal::ZERO
                    },
                })
                .collect();
            items.sort_by(|a, b| b.value.cmp(&a.value));
            items
        };
        
        // 风险指标计算
        let risk_metrics = self.calculate_risk_metrics(&holdings).await?;
        
        // 性能指标
        let performance_metrics = self.calculate_performance_metrics(&account, &holdings).await?;
        
        // 集中度分析
        let concentration = self.analyze_concentration(&holdings);
        
        let analysis = PortfolioAnalysis {
            account_id: account_id.clone(),
            total_value: account.total_value,
            cash_balance: account.cash_balance,
            invested_value: account.total_value - account.cash_balance,
            
            total_gain_loss: account.total_gain_loss,
            total_gain_loss_percent: account.total_gain_loss_percent,
            
            asset_allocation: convert_to_percentage(asset_allocation),
            sector_allocation: convert_to_percentage(sector_allocation),
            geographic_allocation: convert_to_percentage(geographic_allocation),
            
            risk_metrics,
            performance_metrics,
            concentration,
            
            top_performers: self.get_top_performers(&holdings, 5),
            bottom_performers: self.get_bottom_performers(&holdings, 5),
            
            recommendations: self.generate_recommendations(&analysis_context).await?,
            
            generated_at: Utc::now(),
        };
        
        Ok(ServiceResponse::success(analysis))
    }
    
    /// 获取交易历史
    pub async fn get_trade_history(
        &self,
        context: ServiceContext,
        request: TradeHistoryRequest,
    ) -> Result<ServiceResponse<Vec<TradeDetail>>> {
        // 权限检查
        if !context.has_permission_str("view_trades") {
            return Err(JiveError::Forbidden("No permission to view trades".into()));
        }
        
        let trades = self.get_trades_for_account(
            &context.family_id,
            &request.account_id,
            request.start_date,
            request.end_date,
        ).await?;
        
        let mut trade_details = Vec::new();
        
        for trade in trades {
            let security = self.get_security(&trade.security_id).await?;
            
            let detail = TradeDetail {
                trade: trade.clone(),
                security_name: security.name.clone(),
                security_ticker: security.ticker.clone(),
                current_price: security.current_price,
                realized_gain_loss: self.calculate_realized_gain_loss(&trade).await?,
            };
            
            trade_details.push(detail);
        }
        
        // 按日期排序
        trade_details.sort_by(|a, b| b.trade.trade_date.cmp(&a.trade.trade_date));
        
        Ok(ServiceResponse::success(trade_details))
    }
    
    /// 计算资本利得税
    pub async fn calculate_capital_gains_tax(
        &self,
        context: ServiceContext,
        request: CapitalGainsRequest,
    ) -> Result<ServiceResponse<CapitalGainsReport>> {
        let trades = self.get_trades_for_tax_year(
            &context.family_id,
            &request.account_id,
            request.tax_year,
        ).await?;
        
        let mut short_term_gains = Decimal::ZERO;
        let mut short_term_losses = Decimal::ZERO;
        let mut long_term_gains = Decimal::ZERO;
        let mut long_term_losses = Decimal::ZERO;
        
        for trade in trades {
            if trade.trade_type == TradeType::Sell {
                let gain_loss = self.calculate_realized_gain_loss(&trade).await?;
                let holding_period = self.calculate_holding_period(&trade).await?;
                
                if holding_period < 365 {
                    // 短期资本利得
                    if gain_loss > Decimal::ZERO {
                        short_term_gains += gain_loss;
                    } else {
                        short_term_losses += gain_loss.abs();
                    }
                } else {
                    // 长期资本利得
                    if gain_loss > Decimal::ZERO {
                        long_term_gains += gain_loss;
                    } else {
                        long_term_losses += gain_loss.abs();
                    }
                }
            }
        }
        
        // 计算净值
        let net_short_term = short_term_gains - short_term_losses;
        let net_long_term = long_term_gains - long_term_losses;
        let total_net = net_short_term + net_long_term;
        
        // 估算税额（简化计算）
        let estimated_tax = self.estimate_capital_gains_tax(
            net_short_term,
            net_long_term,
            request.tax_rate,
        )?;
        
        let report = CapitalGainsReport {
            tax_year: request.tax_year,
            account_id: request.account_id.clone(),
            
            short_term_gains,
            short_term_losses,
            net_short_term,
            
            long_term_gains,
            long_term_losses,
            net_long_term,
            
            total_net,
            estimated_tax,
            
            trades: trades.len(),
            generated_at: Utc::now(),
        };
        
        Ok(ServiceResponse::success(report))
    }
    
    /// 股息跟踪
    pub async fn track_dividend(
        &self,
        context: ServiceContext,
        request: DividendRequest,
    ) -> Result<ServiceResponse<Dividend>> {
        // 权限检查
        if !context.has_permission_str("manage_investments") {
            return Err(JiveError::Forbidden("No permission to manage investments".into()));
        }
        
        let dividend = Dividend {
            id: Uuid::new_v4().to_string(),
            account_id: request.account_id.clone(),
            security_id: request.security_id.clone(),
            
            amount_per_share: request.amount_per_share,
            shares_owned: request.shares_owned,
            total_amount: request.amount_per_share * request.shares_owned,
            
            ex_dividend_date: request.ex_dividend_date,
            payment_date: request.payment_date,
            record_date: request.record_date,
            
            dividend_type: request.dividend_type,
            tax_withheld: request.tax_withheld,
            
            created_at: Utc::now(),
        };
        
        // 更新账户现金余额
        let mut account = self.get_investment_account(&context.family_id, &request.account_id).await?;
        account.cash_balance += dividend.total_amount - dividend.tax_withheld.unwrap_or(Decimal::ZERO);
        self.update_account(&account).await?;
        
        // TODO: 保存股息记录
        
        Ok(ServiceResponse::success(dividend))
    }
    
    // 辅助方法
    
    async fn security_exists(&self, ticker: &str, exchange: Option<&str>) -> Result<bool> {
        // TODO: 检查数据库
        Ok(false)
    }
    
    async fn get_investment_account(&self, family_id: &str, account_id: &str) -> Result<InvestmentAccount> {
        // TODO: 从数据库获取
        Err(JiveError::NotImplemented("get_investment_account".into()))
    }
    
    async fn get_security(&self, security_id: &str) -> Result<Security> {
        // TODO: 从数据库获取
        Err(JiveError::NotImplemented("get_security".into()))
    }
    
    fn validate_trade(
        &self,
        account: &InvestmentAccount,
        security: &Security,
        request: &TradeRequest,
    ) -> Result<()> {
        // 验证数量
        if request.quantity <= Decimal::ZERO {
            return Err(JiveError::ValidationError("Quantity must be positive".into()));
        }
        
        // 验证价格
        if request.price <= Decimal::ZERO {
            return Err(JiveError::ValidationError("Price must be positive".into()));
        }
        
        // 验证证券是否活跃
        if !security.is_active {
            return Err(JiveError::ValidationError("Security is not active".into()));
        }
        
        Ok(())
    }
    
    async fn update_account_after_trade(
        &self,
        account: &mut InvestmentAccount,
        trade: &Trade,
        security: &Security,
    ) -> Result<()> {
        match trade.trade_type {
            TradeType::Buy => {
                // 减少现金
                account.cash_balance -= trade.total_amount;
                
                // 更新或添加持仓
                if let Some(holding) = account.holdings.iter_mut()
                    .find(|h| h.security_id == trade.security_id) {
                    // 更新现有持仓
                    let new_quantity = holding.quantity + trade.quantity;
                    let new_cost = holding.quantity * holding.avg_cost + trade.total_amount;
                    holding.avg_cost = new_cost / new_quantity;
                    holding.quantity = new_quantity;
                } else {
                    // 添加新持仓
                    account.holdings.push(Holding {
                        id: Uuid::new_v4().to_string(),
                        account_id: account.id.clone(),
                        security_id: trade.security_id.clone(),
                        quantity: trade.quantity,
                        avg_cost: trade.price,
                        first_purchase_date: Some(trade.trade_date),
                        last_updated: Utc::now(),
                    });
                }
            }
            TradeType::Sell => {
                // 增加现金
                account.cash_balance += trade.total_amount;
                
                // 更新持仓
                if let Some(holding) = account.holdings.iter_mut()
                    .find(|h| h.security_id == trade.security_id) {
                    holding.quantity -= trade.quantity;
                    
                    // 如果全部卖出，移除持仓
                    if holding.quantity <= Decimal::ZERO {
                        account.holdings.retain(|h| h.security_id != trade.security_id);
                    }
                }
            }
        }
        
        // 更新账户总值
        self.update_account_value(account).await?;
        
        Ok(())
    }
    
    async fn update_account_value(&self, account: &mut InvestmentAccount) -> Result<()> {
        let mut total_value = account.cash_balance;
        let mut total_cost = Decimal::ZERO;
        
        for holding in &account.holdings {
            if let Ok(security) = self.get_security(&holding.security_id).await {
                if let Some(price) = security.current_price {
                    total_value += holding.quantity * price;
                } else {
                    total_value += holding.quantity * holding.avg_cost;
                }
                total_cost += holding.quantity * holding.avg_cost;
            }
        }
        
        account.total_value = total_value;
        account.total_cost = total_cost;
        account.total_gain_loss = total_value - total_cost;
        account.total_gain_loss_percent = if total_cost > Decimal::ZERO {
            (account.total_gain_loss / total_cost * Decimal::from(100)).round_dp(2)
        } else {
            Decimal::ZERO
        };
        
        Ok(())
    }
    
    async fn update_cost_basis(&self, account: &mut InvestmentAccount, trade: &Trade) -> Result<()> {
        // TODO: 实现成本基础计算（FIFO/LIFO/Average）
        Ok(())
    }
    
    async fn save_security(&self, security: &Security) -> Result<()> {
        // TODO: 保存到数据库
        Ok(())
    }
    
    async fn save_price_record(&self, price: &SecurityPrice) -> Result<()> {
        // TODO: 保存到数据库
        Ok(())
    }
    
    async fn update_accounts_with_security(&self, security_id: &str, price: Decimal) -> Result<()> {
        // TODO: 更新所有持有该证券的账户
        Ok(())
    }
    
    async fn update_account(&self, account: &InvestmentAccount) -> Result<()> {
        // TODO: 更新数据库
        Ok(())
    }
    
    async fn calculate_risk_metrics(&self, holdings: &[HoldingDetail]) -> Result<RiskMetrics> {
        // TODO: 计算贝塔、标准差等风险指标
        Ok(RiskMetrics {
            portfolio_beta: Decimal::from_str_exact("1.0").unwrap(),
            volatility: Decimal::from_str_exact("0.15").unwrap(),
            sharpe_ratio: Decimal::from_str_exact("1.2").unwrap(),
            max_drawdown: Decimal::from_str_exact("0.10").unwrap(),
        })
    }
    
    async fn calculate_performance_metrics(
        &self,
        account: &InvestmentAccount,
        holdings: &[HoldingDetail],
    ) -> Result<PerformanceMetrics> {
        // TODO: 计算性能指标
        Ok(PerformanceMetrics {
            ytd_return: Decimal::from_str_exact("0.12").unwrap(),
            one_year_return: Decimal::from_str_exact("0.15").unwrap(),
            three_year_return: None,
            five_year_return: None,
            annualized_return: Decimal::from_str_exact("0.14").unwrap(),
        })
    }
    
    fn analyze_concentration(&self, holdings: &[HoldingDetail]) -> ConcentrationAnalysis {
        let total_value: Decimal = holdings.iter().map(|h| h.current_value).sum();
        let top_holding_weight = if !holdings.is_empty() && total_value > Decimal::ZERO {
            (holdings[0].current_value / total_value * Decimal::from(100)).round_dp(2)
        } else {
            Decimal::ZERO
        };
        
        let top_5_weight = if holdings.len() >= 5 && total_value > Decimal::ZERO {
            let top_5_value: Decimal = holdings.iter().take(5).map(|h| h.current_value).sum();
            (top_5_value / total_value * Decimal::from(100)).round_dp(2)
        } else {
            Decimal::from(100)
        };
        
        ConcentrationAnalysis {
            number_of_holdings: holdings.len(),
            top_holding_weight,
            top_5_weight,
            herfindahl_index: self.calculate_herfindahl_index(holdings),
        }
    }
    
    fn calculate_herfindahl_index(&self, holdings: &[HoldingDetail]) -> Decimal {
        let total_value: Decimal = holdings.iter().map(|h| h.current_value).sum();
        if total_value == Decimal::ZERO {
            return Decimal::ZERO;
        }
        
        holdings.iter()
            .map(|h| {
                let weight = h.current_value / total_value;
                weight * weight
            })
            .sum::<Decimal>() * Decimal::from(10000)
    }
    
    fn get_top_performers(&self, holdings: &[HoldingDetail], limit: usize) -> Vec<PerformerInfo> {
        let mut performers: Vec<_> = holdings.iter()
            .map(|h| PerformerInfo {
                ticker: h.security.ticker.clone(),
                name: h.security.name.clone(),
                gain_loss_percent: h.gain_loss_percent,
                current_value: h.current_value,
            })
            .collect();
        
        performers.sort_by(|a, b| b.gain_loss_percent.cmp(&a.gain_loss_percent));
        performers.truncate(limit);
        performers
    }
    
    fn get_bottom_performers(&self, holdings: &[HoldingDetail], limit: usize) -> Vec<PerformerInfo> {
        let mut performers: Vec<_> = holdings.iter()
            .map(|h| PerformerInfo {
                ticker: h.security.ticker.clone(),
                name: h.security.name.clone(),
                gain_loss_percent: h.gain_loss_percent,
                current_value: h.current_value,
            })
            .collect();
        
        performers.sort_by(|a, b| a.gain_loss_percent.cmp(&b.gain_loss_percent));
        performers.truncate(limit);
        performers
    }
    
    async fn generate_recommendations(&self, context: &AnalysisContext) -> Result<Vec<Recommendation>> {
        // TODO: 生成投资建议
        Ok(vec![
            Recommendation {
                category: RecommendationCategory::Diversification,
                title: "Consider diversifying your portfolio".to_string(),
                description: "Your portfolio is concentrated in a few holdings".to_string(),
                priority: RecommendationPriority::Medium,
            },
        ])
    }
    
    async fn get_trades_for_account(
        &self,
        family_id: &str,
        account_id: &str,
        start_date: Option<NaiveDate>,
        end_date: Option<NaiveDate>,
    ) -> Result<Vec<Trade>> {
        // TODO: 从数据库获取
        Ok(Vec::new())
    }
    
    async fn calculate_realized_gain_loss(&self, trade: &Trade) -> Result<Decimal> {
        // TODO: 计算已实现损益
        Ok(Decimal::ZERO)
    }
    
    async fn get_trades_for_tax_year(
        &self,
        family_id: &str,
        account_id: &str,
        tax_year: i32,
    ) -> Result<Vec<Trade>> {
        // TODO: 从数据库获取
        Ok(Vec::new())
    }
    
    async fn calculate_holding_period(&self, trade: &Trade) -> Result<i64> {
        // TODO: 计算持有期
        Ok(365)
    }
    
    fn estimate_capital_gains_tax(
        &self,
        short_term: Decimal,
        long_term: Decimal,
        tax_rate: Option<Decimal>,
    ) -> Result<Decimal> {
        let rate = tax_rate.unwrap_or(Decimal::from_str_exact("0.25").unwrap());
        Ok(short_term * rate + long_term * Decimal::from_str_exact("0.15").unwrap())
    }
}

// ========== 数据结构定义 ==========

/// 投资账户
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InvestmentAccount {
    pub id: String,
    pub family_id: String,
    pub name: String,
    pub account_type: InvestmentAccountType,
    pub broker: Option<String>,
    pub account_number: Option<String>,
    
    // 余额信息
    pub cash_balance: Decimal,
    pub total_value: Decimal,
    
    // 收益信息
    pub total_cost: Decimal,
    pub total_gain_loss: Decimal,
    pub total_gain_loss_percent: Decimal,
    pub daily_change: Decimal,
    pub daily_change_percent: Decimal,
    
    // 持仓
    pub holdings: Vec<Holding>,
    
    // 配置
    pub currency: String,
    pub tax_advantaged: bool,
    pub margin_enabled: bool,
    pub options_enabled: bool,
    
    // 元数据
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
    pub last_synced: Option<DateTime<Utc>>,
}

/// 投资账户类型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum InvestmentAccountType {
    // 国际类型
    Brokerage,      // 经纪账户
    IRA,            // 个人退休账户
    Roth401k,       // 401(k)
    Pension,        // 养老金
    
    // 中国类型
    AShare,         // A股账户
    Fund,           // 基金账户
    Bond,           // 债券账户
    Gold,           // 黄金账户
    Forex,          // 外汇账户
    Futures,        // 期货账户
    BankFinancial,  // 银行理财
    Insurance,      // 保险理财
}

/// 证券
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Security {
    pub id: String,
    pub ticker: String,
    pub name: String,
    pub security_type: SecurityType,
    pub exchange: Option<String>,
    
    // 价格信息
    pub current_price: Option<Decimal>,
    pub previous_close: Option<Decimal>,
    pub day_change: Option<Decimal>,
    pub day_change_percent: Option<Decimal>,
    
    // 市场数据
    pub market_cap: Option<Decimal>,
    pub pe_ratio: Option<Decimal>,
    pub dividend_yield: Option<Decimal>,
    pub beta: Option<Decimal>,
    
    // 52周数据
    pub week_52_high: Option<Decimal>,
    pub week_52_low: Option<Decimal>,
    
    // 元数据
    pub currency: String,
    pub country_code: Option<String>,
    pub sector: Option<String>,
    pub industry: Option<String>,
    
    pub logo_url: Option<String>,
    pub description: Option<String>,
    
    pub is_active: bool,
    pub last_updated: DateTime<Utc>,
}

/// 证券类型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum SecurityType {
    Stock,          // 股票
    ETF,            // ETF
    MutualFund,     // 共同基金
    Bond,           // 债券
    Option,         // 期权
    Cryptocurrency, // 加密货币
    Commodity,      // 商品
    Index,          // 指数
}

impl ToString for SecurityType {
    fn to_string(&self) -> String {
        match self {
            SecurityType::Stock => "Stock",
            SecurityType::ETF => "ETF",
            SecurityType::MutualFund => "Mutual Fund",
            SecurityType::Bond => "Bond",
            SecurityType::Option => "Option",
            SecurityType::Cryptocurrency => "Cryptocurrency",
            SecurityType::Commodity => "Commodity",
            SecurityType::Index => "Index",
        }.to_string()
    }
}

/// 持仓
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Holding {
    pub id: String,
    pub account_id: String,
    pub security_id: String,
    pub quantity: Decimal,
    pub avg_cost: Decimal,
    pub first_purchase_date: Option<NaiveDate>,
    pub last_updated: DateTime<Utc>,
}

/// 交易
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Trade {
    pub id: String,
    pub account_id: String,
    pub security_id: String,
    pub trade_type: TradeType,
    
    pub quantity: Decimal,
    pub price: Decimal,
    pub commission: Decimal,
    pub total_amount: Decimal,
    
    pub trade_date: NaiveDate,
    pub settlement_date: NaiveDate,
    
    pub notes: Option<String>,
    
    pub status: TradeStatus,
    pub created_at: DateTime<Utc>,
}

/// 交易类型
#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum TradeType {
    Buy,
    Sell,
}

/// 交易状态
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum TradeStatus {
    Pending,
    Executed,
    Cancelled,
    Failed,
}

/// 证券价格
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SecurityPrice {
    pub id: String,
    pub security_id: String,
    pub date: NaiveDate,
    pub price: Decimal,
    pub volume: Option<i64>,
    pub source: PriceSource,
    pub created_at: DateTime<Utc>,
}

/// 价格来源
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum PriceSource {
    Manual,
    API,
    Import,
}

/// 股息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Dividend {
    pub id: String,
    pub account_id: String,
    pub security_id: String,
    
    pub amount_per_share: Decimal,
    pub shares_owned: Decimal,
    pub total_amount: Decimal,
    
    pub ex_dividend_date: NaiveDate,
    pub payment_date: NaiveDate,
    pub record_date: Option<NaiveDate>,
    
    pub dividend_type: DividendType,
    pub tax_withheld: Option<Decimal>,
    
    pub created_at: DateTime<Utc>,
}

/// 股息类型
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum DividendType {
    Regular,
    Special,
    Return,
    Stock,
}

/// 持仓详情
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HoldingDetail {
    pub holding: Holding,
    pub security: Security,
    pub current_value: Decimal,
    pub cost_basis: Decimal,
    pub gain_loss: Decimal,
    pub gain_loss_percent: Decimal,
    pub weight: Decimal,
    pub day_change: Option<Decimal>,
    pub day_change_percent: Option<Decimal>,
}

/// 投资组合分析
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PortfolioAnalysis {
    pub account_id: String,
    pub total_value: Decimal,
    pub cash_balance: Decimal,
    pub invested_value: Decimal,
    
    pub total_gain_loss: Decimal,
    pub total_gain_loss_percent: Decimal,
    
    pub asset_allocation: Vec<AllocationItem>,
    pub sector_allocation: Vec<AllocationItem>,
    pub geographic_allocation: Vec<AllocationItem>,
    
    pub risk_metrics: RiskMetrics,
    pub performance_metrics: PerformanceMetrics,
    pub concentration: ConcentrationAnalysis,
    
    pub top_performers: Vec<PerformerInfo>,
    pub bottom_performers: Vec<PerformerInfo>,
    
    pub recommendations: Vec<Recommendation>,
    
    pub generated_at: DateTime<Utc>,
}

/// 配置项
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AllocationItem {
    pub name: String,
    pub value: Decimal,
    pub percentage: Decimal,
}

/// 风险指标
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RiskMetrics {
    pub portfolio_beta: Decimal,
    pub volatility: Decimal,
    pub sharpe_ratio: Decimal,
    pub max_drawdown: Decimal,
}

/// 性能指标
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformanceMetrics {
    pub ytd_return: Decimal,
    pub one_year_return: Decimal,
    pub three_year_return: Option<Decimal>,
    pub five_year_return: Option<Decimal>,
    pub annualized_return: Decimal,
}

/// 集中度分析
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConcentrationAnalysis {
    pub number_of_holdings: usize,
    pub top_holding_weight: Decimal,
    pub top_5_weight: Decimal,
    pub herfindahl_index: Decimal,
}

/// 表现者信息
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PerformerInfo {
    pub ticker: String,
    pub name: String,
    pub gain_loss_percent: Decimal,
    pub current_value: Decimal,
}

/// 推荐
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Recommendation {
    pub category: RecommendationCategory,
    pub title: String,
    pub description: String,
    pub priority: RecommendationPriority,
}

/// 推荐类别
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RecommendationCategory {
    Diversification,
    Rebalancing,
    TaxOptimization,
    CostReduction,
    RiskManagement,
}

/// 推荐优先级
#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum RecommendationPriority {
    High,
    Medium,
    Low,
}

/// 交易详情
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TradeDetail {
    pub trade: Trade,
    pub security_name: String,
    pub security_ticker: String,
    pub current_price: Option<Decimal>,
    pub realized_gain_loss: Decimal,
}

/// 资本利得报告
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CapitalGainsReport {
    pub tax_year: i32,
    pub account_id: String,
    
    pub short_term_gains: Decimal,
    pub short_term_losses: Decimal,
    pub net_short_term: Decimal,
    
    pub long_term_gains: Decimal,
    pub long_term_losses: Decimal,
    pub net_long_term: Decimal,
    
    pub total_net: Decimal,
    pub estimated_tax: Decimal,
    
    pub trades: usize,
    pub generated_at: DateTime<Utc>,
}

// 请求结构

/// 创建投资账户请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateInvestmentAccountRequest {
    pub name: String,
    pub account_type: InvestmentAccountType,
    pub broker: Option<String>,
    pub account_number: Option<String>,
    pub currency: String,
    pub initial_cash: Option<Decimal>,
    pub tax_advantaged: Option<bool>,
    pub margin_enabled: Option<bool>,
    pub options_enabled: Option<bool>,
}

/// 创建证券请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CreateSecurityRequest {
    pub ticker: String,
    pub name: String,
    pub security_type: SecurityType,
    pub exchange: Option<String>,
    pub currency: String,
    pub country_code: Option<String>,
    pub sector: Option<String>,
    pub industry: Option<String>,
    pub market_cap: Option<Decimal>,
    pub pe_ratio: Option<Decimal>,
    pub dividend_yield: Option<Decimal>,
    pub beta: Option<Decimal>,
    pub logo_url: Option<String>,
    pub description: Option<String>,
}

/// 交易请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TradeRequest {
    pub account_id: String,
    pub security_id: String,
    pub trade_type: TradeType,
    pub quantity: Decimal,
    pub price: Decimal,
    pub commission: Option<Decimal>,
    pub trade_date: Option<NaiveDate>,
    pub settlement_date: Option<NaiveDate>,
    pub notes: Option<String>,
}

/// 交易历史请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TradeHistoryRequest {
    pub account_id: String,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
}

/// 资本利得请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CapitalGainsRequest {
    pub account_id: String,
    pub tax_year: i32,
    pub tax_rate: Option<Decimal>,
}

/// 股息请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DividendRequest {
    pub account_id: String,
    pub security_id: String,
    pub amount_per_share: Decimal,
    pub shares_owned: Decimal,
    pub ex_dividend_date: NaiveDate,
    pub payment_date: NaiveDate,
    pub record_date: Option<NaiveDate>,
    pub dividend_type: DividendType,
    pub tax_withheld: Option<Decimal>,
}

// 内部结构
struct AnalysisContext {
    // 分析上下文
}

#[cfg(test)]
mod tests {
    use super::*;
    use rust_decimal_macros::dec;
    
    #[test]
    fn test_herfindahl_index() {
        let service = InvestmentService::new();
        let holdings = vec![
            HoldingDetail {
                holding: Holding {
                    id: "1".to_string(),
                    account_id: "acc1".to_string(),
                    security_id: "sec1".to_string(),
                    quantity: dec!(100),
                    avg_cost: dec!(50),
                    first_purchase_date: None,
                    last_updated: Utc::now(),
                },
                security: Security {
                    id: "sec1".to_string(),
                    ticker: "AAPL".to_string(),
                    name: "Apple Inc.".to_string(),
                    security_type: SecurityType::Stock,
                    exchange: Some("NASDAQ".to_string()),
                    current_price: Some(dec!(150)),
                    previous_close: None,
                    day_change: None,
                    day_change_percent: None,
                    market_cap: None,
                    pe_ratio: None,
                    dividend_yield: None,
                    beta: None,
                    week_52_high: None,
                    week_52_low: None,
                    currency: "USD".to_string(),
                    country_code: Some("US".to_string()),
                    sector: Some("Technology".to_string()),
                    industry: None,
                    logo_url: None,
                    description: None,
                    is_active: true,
                    last_updated: Utc::now(),
                },
                current_value: dec!(15000),
                cost_basis: dec!(5000),
                gain_loss: dec!(10000),
                gain_loss_percent: dec!(200),
                weight: dec!(50),
                day_change: None,
                day_change_percent: None,
            },
            HoldingDetail {
                holding: Holding {
                    id: "2".to_string(),
                    account_id: "acc1".to_string(),
                    security_id: "sec2".to_string(),
                    quantity: dec!(200),
                    avg_cost: dec!(25),
                    first_purchase_date: None,
                    last_updated: Utc::now(),
                },
                security: Security {
                    id: "sec2".to_string(),
                    ticker: "MSFT".to_string(),
                    name: "Microsoft Corp.".to_string(),
                    security_type: SecurityType::Stock,
                    exchange: Some("NASDAQ".to_string()),
                    current_price: Some(dec!(75)),
                    previous_close: None,
                    day_change: None,
                    day_change_percent: None,
                    market_cap: None,
                    pe_ratio: None,
                    dividend_yield: None,
                    beta: None,
                    week_52_high: None,
                    week_52_low: None,
                    currency: "USD".to_string(),
                    country_code: Some("US".to_string()),
                    sector: Some("Technology".to_string()),
                    industry: None,
                    logo_url: None,
                    description: None,
                    is_active: true,
                    last_updated: Utc::now(),
                },
                current_value: dec!(15000),
                cost_basis: dec!(5000),
                gain_loss: dec!(10000),
                gain_loss_percent: dec!(200),
                weight: dec!(50),
                day_change: None,
                day_change_percent: None,
            },
        ];
        
        let hhi = service.calculate_herfindahl_index(&holdings);
        assert_eq!(hhi, dec!(5000)); // 50% + 50% = 0.5^2 + 0.5^2 = 0.5 * 10000 = 5000
    }
}