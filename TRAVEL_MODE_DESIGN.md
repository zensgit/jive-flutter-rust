# 旅行模式设计方案

基于 Maybe Finance 的旅行事件系统，结合自动化规则，设计增强的旅行模式

## Maybe Finance 旅行功能分析

### 核心概念
1. **TravelEvent**: 旅行事件，定义时间段和自动标签
2. **TravelEventTemplate**: 分类模板，包含/排除特定分类
3. **自动标签**: 旅行期间的交易自动添加标签
4. **分类过滤**: 只对特定分类的交易应用旅行标签

## Jive Money 旅行模式全面设计

### 核心理念：**上下文感知的财务管理**

旅行模式不仅是简单的标签系统，而是一个完整的上下文切换系统，包括：
- 🌍 **多币种管理**
- 📊 **独立预算追踪**
- 🏷️ **智能分类切换**
- 📱 **离线模式支持**
- 🚨 **实时汇率提醒**
- 📸 **票据快速扫描**

## 数据库设计

```sql
-- 041: 旅行模式系统
-- 旅行计划主表
CREATE TABLE travel_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,

    -- 基本信息
    trip_name VARCHAR(200) NOT NULL,
    description TEXT,
    destination VARCHAR(200), -- 目的地
    trip_type VARCHAR(50), -- 'business', 'leisure', 'mixed'

    -- 时间范围
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    preparation_days INTEGER DEFAULT 7, -- 提前几天激活准备模式

    -- 预算设置
    total_budget DECIMAL(15, 2),
    budget_currency_id UUID REFERENCES currencies(id),
    daily_budget DECIMAL(15, 2), -- 每日预算

    -- 多币种设置
    home_currency_id UUID REFERENCES currencies(id),
    travel_currencies JSONB, -- [{currency_id, exchange_rate, auto_update}]

    -- 状态
    status VARCHAR(20) DEFAULT 'planned' CHECK (status IN ('planned', 'preparing', 'active', 'completed', 'cancelled')),
    is_active BOOLEAN DEFAULT false,

    -- 自动化设置
    auto_activate BOOLEAN DEFAULT true, -- 自动激活旅行模式
    auto_tag BOOLEAN DEFAULT true, -- 自动标签
    auto_categorize BOOLEAN DEFAULT true, -- 自动分类
    auto_convert_currency BOOLEAN DEFAULT true, -- 自动货币转换

    -- 统计数据（缓存）
    total_spent DECIMAL(15, 2) DEFAULT 0,
    total_spent_home_currency DECIMAL(15, 2) DEFAULT 0,
    transaction_count INTEGER DEFAULT 0,

    -- 元数据
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT valid_dates CHECK (end_date >= start_date)
);

-- 旅行预算分类
CREATE TABLE travel_budget_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    travel_plan_id UUID NOT NULL REFERENCES travel_plans(id) ON DELETE CASCADE,

    -- 分类信息
    category_name VARCHAR(100) NOT NULL, -- '交通', '住宿', '餐饮', '购物', '娱乐', '其他'
    category_icon VARCHAR(50),

    -- 预算
    budget_amount DECIMAL(15, 2) NOT NULL,
    budget_currency_id UUID REFERENCES currencies(id),

    -- 实际花费
    spent_amount DECIMAL(15, 2) DEFAULT 0,
    spent_amount_home_currency DECIMAL(15, 2) DEFAULT 0,

    -- 提醒设置
    alert_threshold_percent INTEGER DEFAULT 80,
    alert_sent BOOLEAN DEFAULT false,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 旅行模式规则配置
CREATE TABLE travel_mode_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    travel_plan_id UUID NOT NULL REFERENCES travel_plans(id) ON DELETE CASCADE,

    -- 规则类型
    rule_type VARCHAR(50) NOT NULL, -- 'category_mapping', 'payee_mapping', 'amount_alert'

    -- 触发条件
    trigger_conditions JSONB NOT NULL,
    /*
    示例：
    {
        "type": "payee_contains",
        "value": ["酒店", "Hotel", "Airbnb"],
        "case_sensitive": false
    }
    */

    -- 执行动作
    actions JSONB NOT NULL,
    /*
    示例：
    {
        "set_category": "travel_accommodation",
        "add_tags": ["旅行-住宿"],
        "convert_currency": true
    }
    */

    -- 优先级
    priority INTEGER DEFAULT 100,
    is_active BOOLEAN DEFAULT true,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 旅行交易关联
CREATE TABLE travel_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    travel_plan_id UUID NOT NULL REFERENCES travel_plans(id) ON DELETE CASCADE,
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,

    -- 原始货币信息
    original_amount DECIMAL(15, 2),
    original_currency_id UUID REFERENCES currencies(id),

    -- 转换信息
    exchange_rate DECIMAL(15, 6),
    converted_amount DECIMAL(15, 2),
    conversion_date DATE,

    -- 分类
    travel_category VARCHAR(100), -- 旅行专用分类

    -- 位置信息（可选）
    location_data JSONB, -- {lat, lng, place_name, country}

    -- 票据
    has_receipt BOOLEAN DEFAULT false,
    receipt_url TEXT,

    -- 备注
    travel_notes TEXT,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_travel_transaction UNIQUE (travel_plan_id, transaction_id)
);

-- 旅行日志/时间线
CREATE TABLE travel_timeline_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    travel_plan_id UUID NOT NULL REFERENCES travel_plans(id) ON DELETE CASCADE,

    -- 事件类型
    event_type VARCHAR(50) NOT NULL, -- 'departure', 'arrival', 'activity', 'expense', 'note'
    event_date DATE NOT NULL,
    event_time TIME,

    -- 事件内容
    title VARCHAR(200) NOT NULL,
    description TEXT,
    location VARCHAR(200),

    -- 关联
    transaction_id UUID REFERENCES transactions(id),

    -- 媒体
    photos JSONB, -- 照片URL数组

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 旅行模式模板（预设）
CREATE TABLE travel_mode_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES families(id) ON DELETE CASCADE, -- NULL 为系统模板

    -- 模板信息
    template_name VARCHAR(100) NOT NULL,
    template_type VARCHAR(50), -- 'business', 'leisure', 'backpacking', 'luxury'
    destination_type VARCHAR(50), -- 'domestic', 'international', 'asia', 'europe', 'americas'

    -- 预设配置
    default_categories JSONB, -- 默认预算分类和比例
    default_rules JSONB, -- 默认规则集
    suggested_daily_budget JSONB, -- 不同地区的建议日预算

    -- 使用统计
    usage_count INTEGER DEFAULT 0,
    rating DECIMAL(2, 1),

    is_public BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX idx_travel_plans_family_id ON travel_plans(family_id);
CREATE INDEX idx_travel_plans_dates ON travel_plans(start_date, end_date);
CREATE INDEX idx_travel_plans_status ON travel_plans(status);
CREATE INDEX idx_travel_transactions_plan_id ON travel_transactions(travel_plan_id);
CREATE INDEX idx_travel_transactions_transaction_id ON travel_transactions(transaction_id);
CREATE INDEX idx_travel_timeline_plan_id ON travel_timeline_events(travel_plan_id);
CREATE INDEX idx_travel_timeline_date ON travel_timeline_events(event_date);
```

## 与自动化规则系统的集成

### 1. 旅行模式激活时的规则切换

```rust
// services/travel_mode_service.rs
pub struct TravelModeService {
    rule_engine: Arc<RuleEngineService>,
    notification_service: Arc<NotificationService>,
}

impl TravelModeService {
    /// 激活旅行模式
    pub async fn activate_travel_mode(&self, plan_id: Uuid) -> Result<()> {
        let plan = self.get_travel_plan(plan_id).await?;

        // 1. 创建旅行专用规则集
        self.create_travel_rules(&plan).await?;

        // 2. 调整现有规则优先级（降低日常规则优先级）
        self.rule_engine.adjust_priority_for_context("travel", plan_id).await?;

        // 3. 激活旅行分类映射
        self.activate_category_mappings(&plan).await?;

        // 4. 启动汇率监控
        self.start_exchange_rate_monitoring(&plan).await?;

        // 5. 发送激活通知
        self.notification_service.send_travel_mode_activated(&plan).await?;

        Ok(())
    }

    /// 创建旅行专用规则
    async fn create_travel_rules(&self, plan: &TravelPlan) -> Result<Vec<Uuid>> {
        let mut rule_ids = Vec::new();

        // 规则1：酒店住宿自动分类
        let hotel_rule = Rule {
            name: format!("{}-住宿", plan.trip_name),
            conditions: vec![
                Condition::payee_contains(vec!["Hotel", "酒店", "Airbnb", "民宿"]),
                Condition::date_between(plan.start_date, plan.end_date),
            ],
            actions: vec![
                Action::set_category("travel_accommodation"),
                Action::add_tag(format!("旅行-{}", plan.trip_name)),
                Action::set_travel_category("住宿"),
            ],
            priority: 10, // 高优先级
        };
        rule_ids.push(self.rule_engine.create_rule(hotel_rule).await?);

        // 规则2：交通费用自动分类
        let transport_rule = Rule {
            name: format!("{}-交通", plan.trip_name),
            conditions: vec![
                Condition::any_of(vec![
                    Condition::payee_contains(vec!["Uber", "滴滴", "Taxi", "出租"]),
                    Condition::description_contains(vec!["机票", "火车", "Flight"]),
                ]),
            ],
            actions: vec![
                Action::set_category("travel_transport"),
                Action::add_tag(format!("旅行-{}-交通", plan.trip_name)),
            ],
            priority: 11,
        };
        rule_ids.push(self.rule_engine.create_rule(transport_rule).await?);

        // 规则3：超支提醒
        let overspend_rule = Rule {
            name: format!("{}-预算提醒", plan.trip_name),
            conditions: vec![
                Condition::amount_greater_than(plan.daily_budget * 0.5), // 单笔超过日预算50%
            ],
            actions: vec![
                Action::send_notification("大额支出提醒"),
                Action::require_note(), // 要求添加备注
            ],
            priority: 5,
        };
        rule_ids.push(self.rule_engine.create_rule(overspend_rule).await?);

        Ok(rule_ids)
    }
}
```

### 2. 智能分类映射

```rust
/// 旅行模式下的分类映射服务
pub struct TravelCategoryMapper {
    mappings: HashMap<String, String>,
}

impl TravelCategoryMapper {
    pub fn new() -> Self {
        let mut mappings = HashMap::new();

        // 日常分类 -> 旅行分类 映射
        mappings.insert("餐饮".to_string(), "旅行-餐饮".to_string());
        mappings.insert("交通".to_string(), "旅行-交通".to_string());
        mappings.insert("购物".to_string(), "旅行-购物纪念品".to_string());
        mappings.insert("娱乐".to_string(), "旅行-景点娱乐".to_string());

        Self { mappings }
    }

    pub fn map_category(&self, original: &str, context: &TravelContext) -> String {
        // 根据上下文智能映射
        if context.is_business_trip {
            match original {
                "餐饮" => "差旅-餐饮补贴",
                "交通" => "差旅-交通费",
                "住宿" => "差旅-住宿费",
                _ => original,
            }
        } else {
            self.mappings.get(original)
                .cloned()
                .unwrap_or_else(|| format!("旅行-{}", original))
        }
    }
}
```

### 3. 多币种自动转换

```rust
/// 旅行模式货币服务
pub struct TravelCurrencyService {
    exchange_service: Arc<ExchangeRateService>,
    cache: Arc<Redis>,
}

impl TravelCurrencyService {
    /// 自动检测并转换货币
    pub async fn auto_convert_transaction(
        &self,
        transaction: &mut Transaction,
        travel_plan: &TravelPlan,
    ) -> Result<ConversionResult> {
        // 1. 检测交易货币
        let detected_currency = self.detect_currency(transaction).await?;

        // 2. 获取实时汇率
        let rate = self.exchange_service
            .get_rate(detected_currency, travel_plan.home_currency_id)
            .await?;

        // 3. 转换并记录
        let result = ConversionResult {
            original_amount: transaction.amount,
            original_currency: detected_currency,
            converted_amount: transaction.amount * rate,
            home_currency: travel_plan.home_currency_id,
            exchange_rate: rate,
            conversion_date: Utc::now(),
        };

        // 4. 更新交易记录
        transaction.add_conversion_info(result.clone());

        // 5. 缓存汇率供离线使用
        self.cache_rate_for_offline(detected_currency, rate).await?;

        Ok(result)
    }

    /// 智能货币检测
    async fn detect_currency(&self, transaction: &Transaction) -> Result<Uuid> {
        // 基于多种线索检测货币
        // 1. 商户信息
        // 2. 地理位置
        // 3. 金额模式
        // 4. 描述关键词

        // 实现略...
    }
}
```

### 4. 定时任务集成

```rust
/// 旅行模式定时任务
pub struct TravelModeScheduler {
    travel_service: Arc<TravelModeService>,
}

impl TravelModeScheduler {
    /// 每日定时任务
    pub async fn daily_tasks(&self) -> Result<()> {
        // 1. 检查即将开始的旅行
        let upcoming_trips = self.get_trips_starting_soon().await?;
        for trip in upcoming_trips {
            self.send_preparation_reminder(trip).await?;

            // 自动激活准备模式
            if trip.auto_activate && trip.days_until_start() <= trip.preparation_days {
                self.activate_preparation_mode(trip).await?;
            }
        }

        // 2. 更新活跃旅行的统计
        let active_trips = self.get_active_trips().await?;
        for trip in active_trips {
            self.update_trip_statistics(trip).await?;
            self.check_budget_alerts(trip).await?;

            // 生成每日总结
            self.generate_daily_summary(trip).await?;
        }

        // 3. 自动结束已完成的旅行
        let completed_trips = self.get_completed_trips().await?;
        for trip in completed_trips {
            self.finalize_trip(trip).await?;
            self.generate_trip_report(trip).await?;
        }

        Ok(())
    }
}
```

## Flutter UI 设计

### 1. 旅行模式主界面

```dart
class TravelModeScreen extends StatefulWidget {
  // 旅行模式仪表板
  // - 实时汇率卡片
  // - 今日支出 vs 预算
  // - 分类支出饼图
  // - 快速记账按钮（相机、语音）
}

class TravelBudgetTracker extends StatelessWidget {
  // 可视化预算追踪
  // - 总预算进度条
  // - 分类预算环形图
  // - 每日支出趋势线
}

class TravelTimeline extends StatelessWidget {
  // 旅行时间线
  // - 按日期分组的交易
  // - 照片和位置标记
  // - 事件和备忘
}
```

### 2. 快速记账优化

```dart
class TravelQuickAdd extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () => _showQuickAddSheet(context),
      icon: Icon(Icons.camera_alt),
      label: Text('快速记账'),
      // 长按直接打开相机
      onLongPress: () => _openReceiptScanner(context),
    );
  }

  void _showQuickAddSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => QuickAddSheet(
        options: [
          QuickAddOption(
            icon: Icons.camera_alt,
            label: '扫描票据',
            onTap: () => _scanReceipt(),
          ),
          QuickAddOption(
            icon: Icons.restaurant,
            label: '餐饮',
            preset: TravelPreset.meal(),
          ),
          QuickAddOption(
            icon: Icons.local_taxi,
            label: '交通',
            preset: TravelPreset.transport(),
          ),
          QuickAddOption(
            icon: Icons.shopping_bag,
            label: '购物',
            preset: TravelPreset.shopping(),
          ),
        ],
      ),
    );
  }
}
```

### 3. 离线模式支持

```dart
class OfflineTravelMode {
  // 离线功能：
  // 1. 缓存最近汇率
  // 2. 本地存储待同步交易
  // 3. 离线预算计算
  // 4. 照片本地存储

  Future<void> saveOfflineTransaction(Transaction tx) async {
    await LocalStorage.save('offline_transactions', tx);

    // 注册同步任务
    BackgroundFetch.scheduleTask(
      taskId: 'sync_transactions',
      delay: Duration(minutes: 30),
    );
  }

  Future<void> syncWhenOnline() async {
    if (await Connectivity.isOnline()) {
      final offlineTransactions = await LocalStorage.get('offline_transactions');
      for (final tx in offlineTransactions) {
        await ApiService.syncTransaction(tx);
      }
      await LocalStorage.clear('offline_transactions');
    }
  }
}
```

## 特色功能

### 1. 智能票据识别 (OCR)
- 自动提取金额、商户、日期
- 多语言支持
- 自动分类建议

### 2. 位置感知
- 基于GPS自动切换货币
- 附近商户推荐
- 支出热力图

### 3. 旅行报告生成
- 支出分析报告
- 照片回忆相册
- 分享到社交媒体

### 4. 差旅报销模式
- 自动生成报销单
- 发票管理
- 审批流程集成

## 实施优先级

| 功能模块 | 优先级 | 预计时间 |
|---------|--------|----------|
| 基础旅行计划 CRUD | P0 | 3天 |
| 旅行模式激活/切换 | P0 | 2天 |
| 多币种支持 | P0 | 3天 |
| 自动规则集成 | P1 | 3天 |
| 预算追踪 | P1 | 2天 |
| 票据扫描 | P2 | 4天 |
| 离线模式 | P2 | 3天 |
| 旅行报告 | P3 | 2天 |

## 总结

旅行模式是一个**上下文感知的智能财务管理系统**，通过与自动化规则深度集成，实现：

1. **自动切换财务管理上下文**
   - 规则优先级调整
   - 分类映射切换
   - 预算模式改变

2. **智能化辅助**
   - 自动货币转换
   - 智能分类
   - 实时预算提醒

3. **无缝体验**
   - 离线支持
   - 快速记账
   - 自动报告

4. **与规则系统的协同**
   - 旅行专属规则集
   - 动态规则优先级
   - 上下文感知执行

这个设计充分利用了已有的自动化系统，通过"模式"概念将各个功能有机整合，为用户提供旅行期间的完整财务管理解决方案。