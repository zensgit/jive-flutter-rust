# 🌍 旅行模式完整设计方案

## 目录
- [一、旅行生命周期管理](#一旅行生命周期管理)
- [二、数据模型设计](#二数据模型设计)
- [三、智能标签系统集成](#三智能标签系统集成)
- [四、UI/UX 设计](#四uiux-设计)
- [五、旅行报告生成](#五旅行报告生成)
- [六、核心功能特性](#六核心功能特性)
- [七、实施路线图](#七实施路线图)
- [八、标签组在旅行模式中的应用](#八标签组在旅行模式中的应用)

## 一、旅行生命周期管理

### 旅行阶段流程
```
计划旅行 → 旅行中 → 旅行结束 → 旅行回顾
```

#### 1.1 计划阶段
- 创建旅行事件
- 设置总预算和分类预算
- 配置专属标签组
- 设置提醒规则

#### 1.2 旅行中
- 实时记账（支持离线）
- 自动标签应用
- 多币种汇率转换
- 预算进度提醒

#### 1.3 旅行结束
- 自动生成旅行报告
- 归档标签组
- 总结经验教训

#### 1.4 旅行回顾
- 支出分析对比
- 照片回忆关联
- 优化建议生成

## 二、数据模型设计

### 2.1 旅行事件主表
```sql
-- 旅行事件核心表
CREATE TABLE travel_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,

    -- 基本信息
    trip_name VARCHAR(100) NOT NULL,  -- "2024日本樱花之旅"
    trip_type VARCHAR(50),  -- 'vacation', 'business', 'family', 'honeymoon'
    status VARCHAR(20) DEFAULT 'planning',  -- 'planning', 'active', 'completed', 'cancelled'

    -- 时间范围
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    -- 地点信息
    destinations TEXT[],  -- ['东京', '京都', '大阪']
    countries VARCHAR(10)[],  -- ['JP']
    home_country VARCHAR(10) DEFAULT 'CN',

    -- 预算设置
    total_budget DECIMAL(15,2),
    budget_currency_id UUID REFERENCES currencies(id),
    home_currency_id UUID REFERENCES currencies(id),

    -- 关联标签组（重要！）
    tag_group_id UUID REFERENCES tag_groups(id),

    -- 汇率设置
    exchange_rate_mode VARCHAR(20) DEFAULT 'real_time', -- 'real_time', 'fixed', 'manual'
    fixed_exchange_rates JSONB, -- 固定汇率表

    -- 配置
    settings JSONB DEFAULT '{}',
    /*
    {
        "auto_tags": true,
        "offline_mode": false,
        "default_payment_account": "uuid",
        "reminder_settings": {
            "daily_summary": true,
            "budget_alerts": true,
            "receipt_reminder": true,
            "alert_threshold": 0.8
        },
        "quick_actions": ["meal", "transport", "shopping", "attraction"]
    }
    */

    -- 统计数据（缓存）
    total_spent DECIMAL(15,2) DEFAULT 0,
    transaction_count INTEGER DEFAULT 0,
    last_transaction_at TIMESTAMPTZ,

    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 创建索引
CREATE INDEX idx_travel_events_family ON travel_events(family_id);
CREATE INDEX idx_travel_events_status ON travel_events(status);
CREATE INDEX idx_travel_events_dates ON travel_events(start_date, end_date);
```

### 2.2 旅行预算分配表
```sql
-- 分类预算设置
CREATE TABLE travel_budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    travel_event_id UUID NOT NULL REFERENCES travel_events(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),

    -- 预算金额
    budget_amount DECIMAL(15,2) NOT NULL,
    budget_currency_id UUID REFERENCES currencies(id),

    -- 实际支出（实时更新）
    spent_amount DECIMAL(15,2) DEFAULT 0,
    spent_amount_home_currency DECIMAL(15,2) DEFAULT 0,

    -- 预警设置
    alert_threshold DECIMAL(5,2) DEFAULT 0.8,  -- 80%时预警
    alert_sent BOOLEAN DEFAULT false,
    alert_sent_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_travel_category_budget UNIQUE (travel_event_id, category_id)
);
```

### 2.3 旅行日程表（可选）
```sql
-- 每日行程安排
CREATE TABLE travel_itineraries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    travel_event_id UUID NOT NULL REFERENCES travel_events(id) ON DELETE CASCADE,

    day_number INTEGER NOT NULL,
    date DATE NOT NULL,
    city VARCHAR(100),

    -- 当日计划
    activities JSONB DEFAULT '[]',
    /*
    [
        {
            "time": "09:00",
            "activity": "浅草寺参观",
            "type": "sightseeing",
            "location": "东京浅草",
            "estimated_cost": 0,
            "actual_cost": null,
            "notes": "记得拍照打卡",
            "completed": false
        },
        {
            "time": "12:00",
            "activity": "午餐 - 一兰拉面",
            "type": "meal",
            "location": "新宿",
            "estimated_cost": 1500,
            "actual_cost": 1680,
            "completed": true
        }
    ]
    */

    -- 当日预算
    daily_budget DECIMAL(15,2),
    daily_spent DECIMAL(15,2) DEFAULT 0,

    -- 备注
    notes TEXT,
    weather VARCHAR(50),

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_travel_day UNIQUE (travel_event_id, date)
);
```

### 2.4 旅行标签配置表
```sql
-- 旅行专属标签配置
CREATE TABLE travel_tag_configs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    travel_event_id UUID NOT NULL REFERENCES travel_events(id) ON DELETE CASCADE,

    -- 自动标签规则
    auto_tag_rules JSONB DEFAULT '{}',
    /*
    {
        "location_tags": {
            "东京": ["tokyo", "東京", "Ginza", "Shibuya", "Shinjuku"],
            "京都": ["kyoto", "京都", "Kiyomizu", "Fushimi"],
            "大阪": ["osaka", "大阪", "Dotonbori", "Namba"]
        },
        "merchant_tags": {
            "7-Eleven": ["便利店", "日常"],
            "FamilyMart": ["便利店", "日常"],
            "JR": ["交通", "JR Pass"],
            "Suica": ["交通", "地铁"],
            "Don Quijote": ["购物", "免税店"]
        },
        "category_tags": {
            "餐饮": {
                "morning": ["早餐"],
                "noon": ["午餐"],
                "evening": ["晚餐"],
                "night": ["夜宵"]
            }
        },
        "amount_rules": [
            {"min": 10000, "tag": "大额支出"},
            {"max": 500, "tag": "小额"},
            {"min": 5000, "max": 10000, "tag": "中等支出"}
        ]
    }
    */

    -- 快捷标签集（常用标签ID数组）
    quick_tags UUID[],

    -- 必填标签类型
    required_tag_types VARCHAR(50)[] DEFAULT ARRAY['location'],

    -- 标签使用统计
    tag_usage_stats JSONB DEFAULT '{}',

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_travel_tag_config UNIQUE (travel_event_id)
);
```

### 2.5 旅行照片记录表
```sql
-- 旅行照片与交易关联
CREATE TABLE travel_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    travel_event_id UUID NOT NULL REFERENCES travel_events(id) ON DELETE CASCADE,
    transaction_id UUID REFERENCES transactions(id) ON DELETE SET NULL,

    photo_url TEXT NOT NULL,
    thumbnail_url TEXT,

    -- 照片元数据
    taken_at TIMESTAMPTZ,
    location TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),

    -- 描述
    caption TEXT,
    tags TEXT[],

    -- AI 识别结果
    ai_detection JSONB,
    /* {
        "receipt_detected": true,
        "amount": 1580,
        "merchant": "一兰拉面",
        "items": ["拉面", "溏心蛋", "叉烧"]
    } */

    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

## 三、智能标签系统集成

### 3.1 标签组自动创建与管理

#### 利用现有 tag_groups 表结构
```sql
-- 为旅行创建专属标签组
INSERT INTO tag_groups (id, family_id, name, color, icon, archived)
VALUES
    (gen_random_uuid(), family_id, '2024日本樱花之旅', '#FF69B4', '🌸', false),
    (gen_random_uuid(), family_id, '2024泰国度假', '#4CAF50', '🏖️', false),
    (gen_random_uuid(), family_id, '商务出差-北京', '#2196F3', '💼', false);

-- 扩展标签组表以支持类型
ALTER TABLE tag_groups
ADD COLUMN IF NOT EXISTS group_type VARCHAR(20) DEFAULT 'normal'
    CHECK (group_type IN ('normal', 'travel', 'temporary', 'system')),
ADD COLUMN IF NOT EXISTS metadata JSONB DEFAULT '{}',
ADD COLUMN IF NOT EXISTS archived_at TIMESTAMPTZ;
```

#### 旅行标签组自动生成
```rust
impl TravelService {
    pub async fn create_travel_with_tags(&self, input: CreateTravelInput) -> Result<TravelEvent> {
        let transaction = self.db.begin().await?;

        // 1. 创建旅行事件
        let travel_event = self.insert_travel_event(&input).await?;

        // 2. 创建专属标签组
        let tag_group = self.tag_service.create_group(TagGroup {
            family_id: input.family_id,
            name: format!("{}", input.trip_name),
            color: self.get_trip_type_color(&input.trip_type),
            icon: self.get_destination_emoji(&input.destinations[0]),
            group_type: "travel".to_string(),
            metadata: json!({
                "travel_event_id": travel_event.id,
                "destinations": input.destinations,
                "date_range": {
                    "start": input.start_date,
                    "end": input.end_date
                }
            }),
        }).await?;

        // 3. 基于目的地创建预设标签
        let destination_tags = self.generate_destination_tags(&input.destinations);

        // 4. 创建通用旅行标签
        let common_tags = vec![
            ("交通", "🚗", vec!["机票", "火车", "地铁", "打车", "公交"]),
            ("住宿", "🏨", vec!["酒店", "民宿", "青旅", "胶囊旅馆"]),
            ("餐饮", "🍽️", vec!["早餐", "午餐", "晚餐", "小吃", "饮料"]),
            ("购物", "🛍️", vec!["纪念品", "特产", "免税店", "超市", "便利店"]),
            ("景点", "🎫", vec!["门票", "导游", "体验", "博物馆", "公园"]),
            ("其他", "📌", vec!["小费", "保险", "签证", "汇兑", "杂费"]),
        ];

        // 5. 批量创建标签
        for (category, icon, tags) in common_tags {
            for tag_name in tags {
                self.tag_service.create_tag(Tag {
                    family_id: input.family_id,
                    group_id: Some(tag_group.id),
                    name: tag_name.to_string(),
                    icon: Some(icon.to_string()),
                    color: Some(tag_group.color.clone()),
                }).await?;
            }
        }

        // 6. 更新旅行事件关联标签组
        self.update_travel_tag_group(travel_event.id, tag_group.id).await?;

        transaction.commit().await?;
        Ok(travel_event)
    }
}
```

### 3.2 智能标签应用场景

#### 场景A: 基于地理位置的自动标签
```rust
pub async fn apply_location_tags(
    &self,
    transaction: &Transaction,
    travel_config: &TravelTagConfig
) -> Vec<Tag> {
    let mut tags = Vec::new();

    if let Some(location) = &transaction.location {
        // 从配置中匹配地点标签
        for (city, keywords) in &travel_config.location_tags {
            for keyword in keywords {
                if location.to_lowercase().contains(&keyword.to_lowercase()) {
                    tags.push(self.get_or_create_tag(city, transaction.family_id).await?);
                    break;
                }
            }
        }

        // 特殊地点识别
        if location.contains("空港") || location.contains("Airport") {
            tags.push(self.get_or_create_tag("机场", transaction.family_id).await?);
        }

        if location.contains("駅") || location.contains("Station") {
            tags.push(self.get_or_create_tag("车站", transaction.family_id).await?);
        }
    }

    tags
}
```

#### 场景B: 基于商户的智能识别
```rust
pub async fn apply_merchant_tags(
    &self,
    transaction: &Transaction,
    travel_config: &TravelTagConfig
) -> Vec<Tag> {
    let mut tags = Vec::new();

    if let Some(merchant) = &transaction.merchant {
        // 精确匹配商户规则
        for (pattern, tag_names) in &travel_config.merchant_tags {
            if merchant.contains(pattern) {
                for tag_name in tag_names {
                    tags.push(self.get_or_create_tag(tag_name, transaction.family_id).await?);
                }
            }
        }

        // 通用商户类型识别
        let merchant_lower = merchant.to_lowercase();
        match merchant_lower {
            m if m.contains("hotel") || m.contains("inn") => {
                tags.push(self.get_or_create_tag("酒店", transaction.family_id).await?);
            },
            m if m.contains("restaurant") || m.contains("cafe") => {
                tags.push(self.get_or_create_tag("餐厅", transaction.family_id).await?);
            },
            m if m.contains("station") || m.contains("railway") => {
                tags.push(self.get_or_create_tag("交通", transaction.family_id).await?);
            },
            _ => {}
        }
    }

    tags
}
```

#### 场景C: 基于时间的智能标签
```rust
pub async fn apply_temporal_tags(
    &self,
    transaction: &Transaction,
    category: &Category
) -> Vec<Tag> {
    let mut tags = Vec::new();

    // 餐饮类按时间分类
    if category.category_type == "餐饮" {
        let hour = transaction.transaction_time.hour();
        let meal_tag = match hour {
            6..=10 => "早餐",
            11..=14 => "午餐",
            15..=17 => "下午茶",
            18..=21 => "晚餐",
            _ => "夜宵",
        };
        tags.push(self.get_or_create_tag(meal_tag, transaction.family_id).await?);
    }

    // 节假日标签
    if self.is_holiday(&transaction.transaction_date) {
        tags.push(self.get_or_create_tag("节假日", transaction.family_id).await?);
    }

    // 周末标签
    if transaction.transaction_date.weekday() >= Weekday::Sat {
        tags.push(self.get_or_create_tag("周末", transaction.family_id).await?);
    }

    tags
}
```

#### 场景D: 基于金额的标签
```rust
pub async fn apply_amount_tags(
    &self,
    transaction: &Transaction,
    travel_config: &TravelTagConfig
) -> Vec<Tag> {
    let mut tags = Vec::new();

    for rule in &travel_config.amount_rules {
        let matches = match (rule.min, rule.max) {
            (Some(min), Some(max)) => transaction.amount >= min && transaction.amount <= max,
            (Some(min), None) => transaction.amount >= min,
            (None, Some(max)) => transaction.amount <= max,
            _ => false,
        };

        if matches {
            tags.push(self.get_or_create_tag(&rule.tag, transaction.family_id).await?);
        }
    }

    tags
}
```

### 3.3 标签组模板系统

```sql
-- 标签组模板表
CREATE TABLE tag_group_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    template_name VARCHAR(100) NOT NULL,
    template_type VARCHAR(50) NOT NULL,  -- 'travel_japan', 'travel_europe', 'business_trip'

    -- 预定义标签集合
    default_tags JSONB NOT NULL,
    /* 示例：
    {
        "categories": [
            {
                "name": "交通",
                "icon": "🚗",
                "tags": ["机票", "火车", "地铁", "打车"]
            },
            {
                "name": "住宿",
                "icon": "🏨",
                "tags": ["酒店", "民宿"]
            }
        ],
        "locations": ["东京", "京都", "大阪"],
        "special": ["免税店", "JR Pass", "温泉"]
    }
    */

    -- 自动规则模板
    auto_rules JSONB,

    -- 使用统计
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 插入常用模板
INSERT INTO tag_group_templates (template_name, template_type, default_tags) VALUES
('日本旅行模板', 'travel_japan', '{
    "categories": [
        {"name": "交通", "icon": "🚗", "tags": ["JR Pass", "地铁", "新干线", "巴士"]},
        {"name": "餐饮", "icon": "🍽️", "tags": ["拉面", "寿司", "居酒屋", "便利店"]},
        {"name": "住宿", "icon": "🏨", "tags": ["酒店", "民宿", "胶囊旅馆", "温泉旅馆"]},
        {"name": "购物", "icon": "🛍️", "tags": ["药妆店", "百货", "便利店", "免税店"]},
        {"name": "景点", "icon": "🎫", "tags": ["寺庙", "神社", "城堡", "博物馆"]}
    ],
    "locations": ["东京", "京都", "大阪", "奈良", "箱根"],
    "special": ["樱花", "温泉", "和服体验", "茶道"]
}'),

('欧洲旅行模板', 'travel_europe', '{
    "categories": [
        {"name": "交通", "icon": "🚆", "tags": ["欧铁", "地铁", "Uber", "航班"]},
        {"name": "住宿", "icon": "🏨", "tags": ["酒店", "Airbnb", "青旅", "民宿"]},
        {"name": "餐饮", "icon": "🍽️", "tags": ["餐厅", "咖啡馆", "快餐", "超市"]},
        {"name": "景点", "icon": "🏛️", "tags": ["博物馆", "教堂", "城堡", "广场"]}
    ],
    "locations": ["巴黎", "伦敦", "罗马", "巴塞罗那", "阿姆斯特丹"],
    "special": ["申根签证", "博物馆通票", "城市观光卡"]
}'),

('国内出差模板', 'business_china', '{
    "categories": [
        {"name": "交通", "icon": "✈️", "tags": ["机票", "高铁", "打车", "地铁"]},
        {"name": "住宿", "icon": "🏨", "tags": ["商务酒店", "快捷酒店"]},
        {"name": "餐饮", "icon": "🍽️", "tags": ["工作餐", "客户宴请", "早餐"]},
        {"name": "其他", "icon": "📋", "tags": ["会议", "培训", "团建"]}
    ],
    "locations": ["北京", "上海", "深圳", "广州", "杭州"],
    "special": ["报销", "发票", "商务接待"]
}');
```

## 四、UI/UX 设计

### 4.1 旅行模式主界面

```dart
class TravelModeHomeScreen extends StatefulWidget {
  final TravelEvent currentTravel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${currentTravel.tripName}'),
            Text(
              'Day ${currentDayNumber} of ${totalDays} · ${currentCity}',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.home),
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            tooltip: '退出旅行模式',
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: CustomScrollView(
          slivers: [
            // 1. 今日预算卡片
            SliverToBoxAdapter(
              child: TodayBudgetCard(
                dailyBudget: currentTravel.getDailyBudget(),
                todaySpent: todayTransactions.totalAmount,
                totalBudget: currentTravel.totalBudget,
                totalSpent: currentTravel.totalSpent,
                currency: currentTravel.budgetCurrency,
              ),
            ),

            // 2. 快捷操作按钮
            SliverToBoxAdapter(
              child: QuickActionGrid(
                actions: [
                  QuickAction('餐饮', Icons.restaurant_menu, Colors.orange),
                  QuickAction('交通', Icons.directions_car, Colors.blue),
                  QuickAction('购物', Icons.shopping_bag, Colors.purple),
                  QuickAction('景点', Icons.attractions, Colors.green),
                  QuickAction('住宿', Icons.hotel, Colors.indigo),
                  QuickAction('其他', Icons.more_horiz, Colors.grey),
                ],
                onTap: (action) => _quickAddTransaction(action),
              ),
            ),

            // 3. 汇率信息条
            if (currentTravel.isInternational)
              SliverToBoxAdapter(
                child: ExchangeRateBar(
                  fromCurrency: currentTravel.localCurrency,
                  toCurrency: currentTravel.homeCurrency,
                  rate: currentExchangeRate,
                  mode: currentTravel.exchangeRateMode,
                  onTap: () => _showExchangeRateSettings(),
                ),
              ),

            // 4. 今日支出列表
            SliverPadding(
              padding: EdgeInsets.all(16),
              sliver: SliverToBoxAdapter(
                child: Text(
                  '今日支出',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),

            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final transaction = todayTransactions[index];
                  return TransactionTile(
                    transaction: transaction,
                    showTags: true,
                    showConvertedAmount: currentTravel.isInternational,
                    onTap: () => _editTransaction(transaction),
                    onDismiss: () => _deleteTransaction(transaction),
                  );
                },
                childCount: todayTransactions.length,
              ),
            ),

            // 5. 分类统计
            SliverToBoxAdapter(
              child: CategorySpendingChart(
                data: todaySpendingByCategory,
                title: '今日支出分布',
              ),
            ),
          ],
        ),
      ),

      // 悬浮快速记账按钮
      floatingActionButton: SpeedDial(
        icon: Icons.add,
        activeIcon: Icons.close,
        children: [
          SpeedDialChild(
            child: Icon(Icons.camera_alt),
            label: '拍照记账',
            onTap: () => _captureReceipt(),
          ),
          SpeedDialChild(
            child: Icon(Icons.mic),
            label: '语音记账',
            onTap: () => _voiceInput(),
          ),
          SpeedDialChild(
            child: Icon(Icons.qr_code_scanner),
            label: '扫码支付',
            onTap: () => _scanQRCode(),
          ),
          SpeedDialChild(
            child: Icon(Icons.edit),
            label: '手动记账',
            onTap: () => _manualEntry(),
          ),
        ],
      ),

      // 底部导航
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: '概览',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: '日程',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pie_chart),
            label: '统计',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: '相册',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_vert),
            label: '更多',
          ),
        ],
      ),
    );
  }
}
```

### 4.2 智能标签选择器

```dart
class SmartTravelTagSelector extends StatefulWidget {
  final Transaction? transaction;
  final TravelEvent currentTravel;
  final Function(List<Tag>) onTagsSelected;

  @override
  _SmartTravelTagSelectorState createState() => _SmartTravelTagSelectorState();
}

class _SmartTravelTagSelectorState extends State<SmartTravelTagSelector>
    with TickerProviderStateMixin {

  late TabController _tabController;
  List<Tag> selectedTags = [];
  List<TagSuggestion> aiSuggestions = [];
  Map<String, List<Tag>> tagsByCategory = {};

  @override
  void initState() {
    super.initState();
    _loadTravelTags();
    _loadAISuggestions();
    _tabController = TabController(
      length: tagsByCategory.length + 2, // +2 for AI and Recent
      vsync: this,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          // Header with selected tags count
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '选择标签',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (selectedTags.isNotEmpty)
                  Chip(
                    label: Text('已选 ${selectedTags.length}'),
                    onDeleted: () => setState(() => selectedTags.clear()),
                  ),
              ],
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: [
              Tab(text: '✨ 智能推荐'),
              Tab(text: '🕐 最近使用'),
              ...tagsByCategory.keys.map((category) =>
                Tab(text: _getCategoryIcon(category) + ' ' + category)
              ),
            ],
          ),

          // Tab Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // AI Suggestions Tab
                _buildAISuggestionsView(),

                // Recent Tags Tab
                _buildRecentTagsView(),

                // Category Tabs
                ...tagsByCategory.entries.map((entry) =>
                  _buildCategoryTagsView(entry.key, entry.value)
                ),
              ],
            ),
          ),

          // Selected Tags Display
          if (selectedTags.isNotEmpty)
            Container(
              height: 50,
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: selectedTags.map((tag) =>
                  Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Chip(
                      label: Text(tag.name),
                      deleteIcon: Icon(Icons.close, size: 18),
                      onDeleted: () => _removeTag(tag),
                    ),
                  )
                ).toList(),
              ),
            ),

          // Action Buttons
          Container(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('取消'),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: selectedTags.isEmpty
                      ? null
                      : () {
                          widget.onTagsSelected(selectedTags);
                          Navigator.pop(context);
                        },
                    child: Text('确定 (${selectedTags.length})'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAISuggestionsView() {
    if (aiSuggestions.isEmpty) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          '基于您的消费习惯和当前场景推荐',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
        SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: aiSuggestions.map((suggestion) =>
            ActionChip(
              avatar: CircleAvatar(
                child: Text(
                  '${(suggestion.confidence * 100).toInt()}%',
                  style: TextStyle(fontSize: 10),
                ),
                backgroundColor: _getConfidenceColor(suggestion.confidence),
              ),
              label: Text(suggestion.tag.name),
              onPressed: () => _toggleTag(suggestion.tag),
              backgroundColor: selectedTags.contains(suggestion.tag)
                ? Theme.of(context).primaryColor.withOpacity(0.2)
                : null,
            )
          ).toList(),
        ),

        if (suggestion.reason != null) ...[
          SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: Icon(Icons.info_outline, size: 20),
              title: Text(
                '推荐理由',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                suggestion.reason!,
                style: TextStyle(fontSize: 11),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecentTagsView() {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: recentTags.length,
      itemBuilder: (context, index) {
        final tag = recentTags[index];
        final isSelected = selectedTags.contains(tag);

        return FilterChip(
          label: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (tag.icon != null) Text(tag.icon!),
              SizedBox(width: 4),
              Flexible(
                child: Text(
                  tag.name,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          selected: isSelected,
          onSelected: (_) => _toggleTag(tag),
          showCheckmark: false,
          selectedColor: Theme.of(context).primaryColor.withOpacity(0.2),
        );
      },
    );
  }

  Widget _buildCategoryTagsView(String category, List<Tag> tags) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 2.5,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: tags.length,
      itemBuilder: (context, index) {
        final tag = tags[index];
        final isSelected = selectedTags.contains(tag);

        return FilterChip(
          label: Text(tag.name),
          selected: isSelected,
          onSelected: (_) => _toggleTag(tag),
          avatar: tag.usageCount > 0
            ? CircleAvatar(
                child: Text(
                  '${tag.usageCount}',
                  style: TextStyle(fontSize: 10),
                ),
                radius: 10,
              )
            : null,
        );
      },
    );
  }
}
```

## 五、旅行报告生成

### 5.1 报告数据结构

```rust
#[derive(Serialize, Deserialize)]
pub struct TravelReport {
    // 基本信息
    pub travel_event: TravelEvent,
    pub generation_time: DateTime<Utc>,

    // 总览统计
    pub overview: TravelOverview,

    // 详细分析
    pub daily_breakdown: Vec<DailySpending>,
    pub category_analysis: CategoryAnalysis,
    pub tag_insights: TagInsights,
    pub currency_analysis: CurrencyAnalysis,

    // 预算执行
    pub budget_performance: BudgetPerformance,

    // 亮点和发现
    pub highlights: TravelHighlights,
    pub discoveries: Vec<TravelDiscovery>,

    // 照片集锦
    pub photo_memories: Vec<PhotoMemory>,
}

#[derive(Serialize, Deserialize)]
pub struct TravelOverview {
    // 时间统计
    pub total_days: i32,
    pub travel_dates: String, // "2024.03.15 - 2024.03.22"

    // 地点统计
    pub countries_visited: Vec<String>,
    pub cities_visited: Vec<String>,

    // 支出统计
    pub total_spent: Decimal,
    pub total_spent_home_currency: Decimal,
    pub daily_average: Decimal,
    pub transaction_count: i32,

    // 对比数据
    pub vs_budget: Decimal, // 实际 vs 预算的百分比
    pub vs_last_trip: Option<Decimal>, // 与上次旅行对比
}

#[derive(Serialize, Deserialize)]
pub struct TagInsights {
    pub most_used_tags: Vec<(Tag, usize)>,
    pub tag_cloud: Vec<TagCloudItem>,
    pub spending_by_tag: HashMap<String, Decimal>,
    pub tag_combinations: Vec<(Vec<String>, usize)>,

    // 特色分析
    pub unique_experiences: Vec<String>, // 基于特殊标签
    pub recommendation_accuracy: f32, // AI推荐准确率
}

#[derive(Serialize, Deserialize)]
pub struct TravelHighlights {
    pub most_expensive_day: DayHighlight,
    pub cheapest_day: DayHighlight,
    pub largest_purchase: TransactionHighlight,
    pub smallest_purchase: TransactionHighlight,
    pub favorite_merchant: MerchantHighlight,
    pub favorite_category: CategoryHighlight,
    pub busiest_day: DayHighlight, // 交易次数最多

    // 有趣的发现
    pub early_bird_transactions: i32, // 早于7点的交易
    pub night_owl_transactions: i32, // 晚于22点的交易
    pub weekend_vs_weekday_spending: (Decimal, Decimal),
}
```

### 5.2 报告生成服务

```rust
impl TravelReportService {
    pub async fn generate_comprehensive_report(
        &self,
        travel_event_id: Uuid,
    ) -> Result<TravelReport> {
        // 1. 获取基础数据
        let travel = self.get_travel_event(travel_event_id).await?;
        let transactions = self.get_all_travel_transactions(travel_event_id).await?;
        let photos = self.get_travel_photos(travel_event_id).await?;

        // 2. 并行计算各项统计
        let (
            overview,
            daily_breakdown,
            category_analysis,
            tag_insights,
            budget_performance,
            highlights,
        ) = tokio::try_join!(
            self.calculate_overview(&travel, &transactions),
            self.calculate_daily_breakdown(&transactions),
            self.analyze_categories(&transactions),
            self.analyze_tags(&travel, &transactions),
            self.analyze_budget_performance(&travel, &transactions),
            self.extract_highlights(&transactions),
        )?;

        // 3. 生成发现和建议
        let discoveries = self.generate_discoveries(&travel, &transactions).await?;

        // 4. 整理照片回忆
        let photo_memories = self.organize_photo_memories(&photos, &transactions).await?;

        // 5. 组装完整报告
        let report = TravelReport {
            travel_event: travel,
            generation_time: Utc::now(),
            overview,
            daily_breakdown,
            category_analysis,
            tag_insights,
            currency_analysis: self.analyze_currencies(&transactions).await?,
            budget_performance,
            highlights,
            discoveries,
            photo_memories,
        };

        // 6. 缓存报告
        self.cache_report(&report).await?;

        Ok(report)
    }

    async fn analyze_tags(
        &self,
        travel: &TravelEvent,
        transactions: &[Transaction],
    ) -> Result<TagInsights> {
        // 统计标签使用频率
        let mut tag_counts: HashMap<Uuid, usize> = HashMap::new();
        let mut tag_amounts: HashMap<Uuid, Decimal> = HashMap::new();

        for transaction in transactions {
            for tag_id in &transaction.tags {
                *tag_counts.entry(*tag_id).or_insert(0) += 1;
                *tag_amounts.entry(*tag_id).or_insert(Decimal::zero()) += transaction.amount;
            }
        }

        // 获取标签详情
        let tags = self.tag_service.get_tags_by_ids(
            tag_counts.keys().copied().collect()
        ).await?;

        // 生成标签云
        let tag_cloud = tags.iter().map(|tag| {
            let count = tag_counts.get(&tag.id).copied().unwrap_or(0);
            let size = Self::calculate_tag_cloud_size(count, tag_counts.values());

            TagCloudItem {
                tag: tag.clone(),
                count,
                size,
                amount: tag_amounts.get(&tag.id).copied(),
            }
        }).collect();

        // 分析标签组合
        let combinations = self.analyze_tag_combinations(transactions).await?;

        // 计算AI推荐准确率
        let recommendation_accuracy = self.calculate_recommendation_accuracy(
            travel.id,
            transactions
        ).await?;

        Ok(TagInsights {
            most_used_tags: Self::get_top_tags(&tag_counts, &tags, 10),
            tag_cloud,
            spending_by_tag: Self::map_tag_amounts(&tag_amounts, &tags),
            tag_combinations: combinations,
            unique_experiences: self.extract_unique_experiences(&tags, transactions).await?,
            recommendation_accuracy,
        })
    }
}
```

### 5.3 报告展示界面

```dart
class TravelReportScreen extends StatefulWidget {
  final String travelEventId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<TravelReport>(
        future: _loadReport(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return Center(child: CircularProgressIndicator());
          }

          final report = snapshot.data!;

          return CustomScrollView(
            slivers: [
              // 1. 封面头图
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(report.travelEvent.tripName),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (report.coverPhoto != null)
                        Image.network(
                          report.coverPhoto!,
                          fit: BoxFit.cover,
                        ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              Colors.black.withOpacity(0.7),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.share),
                    onPressed: () => _shareReport(report),
                  ),
                  IconButton(
                    icon: Icon(Icons.download),
                    onPressed: () => _downloadPDF(report),
                  ),
                ],
              ),

              // 2. 总览卡片
              SliverToBoxAdapter(
                child: OverviewCard(
                  overview: report.overview,
                  currency: report.travelEvent.budgetCurrency,
                ),
              ),

              // 3. 支出趋势图
              SliverToBoxAdapter(
                child: SpendingTrendChart(
                  dailyBreakdown: report.dailyBreakdown,
                  title: '每日支出趋势',
                ),
              ),

              // 4. 分类分析（饼图）
              SliverToBoxAdapter(
                child: CategoryPieChart(
                  analysis: report.categoryAnalysis,
                  title: '支出分类分布',
                ),
              ),

              // 5. 标签云
              SliverToBoxAdapter(
                child: TagCloudWidget(
                  tagCloud: report.tagInsights.tagCloud,
                  title: '标签使用情况',
                  onTagTap: (tag) => _showTagDetails(tag),
                ),
              ),

              // 6. 预算执行情况
              SliverToBoxAdapter(
                child: BudgetPerformanceCard(
                  performance: report.budgetPerformance,
                  showDetails: true,
                ),
              ),

              // 7. 旅行亮点
              SliverToBoxAdapter(
                child: HighlightsSection(
                  highlights: report.highlights,
                  discoveries: report.discoveries,
                ),
              ),

              // 8. 照片回忆
              if (report.photoMemories.isNotEmpty)
                SliverToBoxAdapter(
                  child: PhotoMemoriesGallery(
                    photos: report.photoMemories,
                    onPhotoTap: (photo) => _viewPhotoDetail(photo),
                  ),
                ),

              // 9. 详细交易列表（可展开）
              SliverToBoxAdapter(
                child: ExpansionTile(
                  title: Text('详细交易记录'),
                  subtitle: Text('${report.overview.transactionCount} 笔交易'),
                  children: [
                    TransactionListByDay(
                      dailyBreakdown: report.dailyBreakdown,
                    ),
                  ],
                ),
              ),

              // 10. 导出选项
              SliverToBoxAdapter(
                child: ExportOptionsCard(
                  onExportPDF: () => _exportPDF(report),
                  onExportExcel: () => _exportExcel(report),
                  onShareLink: () => _shareLink(report),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
```

## 六、核心功能特性

### 6.1 智能标签系统
- **自动创建**：每个旅行自动创建专属标签组
- **智能推荐**：基于历史数据和当前场景的AI推荐
- **多维标签**：地点、时间、商户、金额等多维度自动标签
- **标签模板**：预设的旅行类型标签模板，快速启动
- **使用统计**：追踪标签使用频率，优化推荐算法

### 6.2 多币种支持
- **实时汇率**：集成多个汇率API，实时更新
- **固定汇率**：支持固定汇率模式，避免频繁波动
- **手动设置**：允许用户手动设置汇率
- **汇兑追踪**：记录汇兑损益，生成汇率分析报告
- **离线汇率**：缓存常用汇率，支持离线使用

### 6.3 预算管理
- **分层预算**：总预算、分类预算、每日预算
- **实时追踪**：实时显示预算执行进度
- **智能提醒**：基于消费速度的动态提醒
- **超支预警**：多级预警机制（70%、90%、100%）
- **预算调整**：灵活调整预算分配

### 6.4 离线模式
- **本地存储**：SQLite本地数据库缓存
- **队列管理**：离线交易队列，自动同步
- **冲突解决**：智能冲突解决策略
- **增量同步**：只同步变更数据，节省流量
- **状态指示**：清晰的离线/在线状态显示

### 6.5 快捷操作
- **快速记账**：一键快速添加常见类型支出
- **拍照识别**：OCR识别小票，自动提取信息
- **语音输入**：语音转文字，自然语言解析
- **扫码支付**：扫描二维码，自动记录支付
- **模板复用**：保存常用交易作为模板

### 6.6 数据分析
- **多维度统计**：按时间、分类、标签、地点等多维度分析
- **趋势图表**：支出趋势、分类占比、标签云等可视化
- **对比分析**：与预算对比、与历史旅行对比
- **智能发现**：自动发现消费模式和异常
- **个性化建议**：基于分析结果的优化建议

## 七、实施路线图

### Phase 1: 基础架构（第1-2周）
- [x] 设计数据库表结构
- [ ] 创建数据库迁移脚本
- [ ] 实现基础API接口
- [ ] 搭建服务层架构

### Phase 2: 标签系统增强（第3周）
- [ ] 实现标签组自动创建
- [ ] 开发智能标签推荐算法
- [ ] 创建标签模板系统
- [ ] 集成标签使用统计

### Phase 3: 核心功能开发（第4-5周）
- [ ] 旅行事件管理
- [ ] 多币种支持
- [ ] 预算追踪系统
- [ ] 交易快捷操作

### Phase 4: UI开发（第6-7周）
- [ ] 旅行模式主界面
- [ ] 智能标签选择器
- [ ] 预算管理界面
- [ ] 数据分析图表

### Phase 5: 高级功能（第8周）
- [ ] 离线模式支持
- [ ] 拍照识别功能
- [ ] 语音输入支持
- [ ] 报告生成系统

### Phase 6: 测试与优化（第9-10周）
- [ ] 功能测试
- [ ] 性能优化
- [ ] 用户体验优化
- [ ] 文档完善

## 八、标签组在旅行模式中的应用

### 8.1 标签组类型扩展
```sql
-- 扩展标签组以支持旅行
ALTER TABLE tag_groups
ADD COLUMN group_type VARCHAR(20) DEFAULT 'normal'
    CHECK (group_type IN ('normal', 'travel', 'temporary', 'system')),
ADD COLUMN metadata JSONB DEFAULT '{}',
ADD COLUMN archived_at TIMESTAMPTZ;

-- 标签组类型说明：
-- 'normal': 常规标签组，长期使用
-- 'travel': 旅行专属标签组，与travel_events关联
-- 'temporary': 临时标签组，可设置过期时间
-- 'system': 系统标签组，不可删除
```

### 8.2 旅行标签组自动管理

#### 创建旅行时自动生成标签组
```rust
pub async fn create_travel_tag_group(&self, travel: &TravelEvent) -> Result<TagGroup> {
    let tag_group = TagGroup {
        family_id: travel.family_id,
        name: format!("{}", travel.trip_name),
        color: self.get_travel_color(&travel.trip_type),
        icon: self.get_destination_emoji(&travel.destinations[0]),
        group_type: "travel".to_string(),
        metadata: json!({
            "travel_event_id": travel.id,
            "auto_archive_date": travel.end_date + Duration::days(30),
            "destinations": travel.destinations,
            "trip_type": travel.trip_type,
        }),
    };

    self.tag_service.create_group(tag_group).await
}
```

#### 旅行结束后自动归档
```rust
pub async fn archive_completed_travel_groups(&self) -> Result<()> {
    let completed_travels = self.get_completed_travels().await?;

    for travel in completed_travels {
        if let Some(tag_group) = self.get_travel_tag_group(travel.id).await? {
            // 检查是否已过归档期限（旅行结束30天后）
            if Utc::now() > travel.end_date + Duration::days(30) {
                self.tag_service.archive_group(tag_group.id).await?;
                info!("Archived tag group for travel: {}", travel.trip_name);
            }
        }
    }

    Ok(())
}
```

### 8.3 标签组模板快速应用

```rust
pub async fn apply_tag_group_template(
    &self,
    travel_id: Uuid,
    template_type: &str,
) -> Result<()> {
    // 获取模板
    let template = self.get_tag_group_template(template_type).await?;

    // 创建标签组
    let travel = self.get_travel_event(travel_id).await?;
    let tag_group = self.create_travel_tag_group(&travel).await?;

    // 批量创建模板中的标签
    for category in template.default_tags.categories {
        for tag_name in category.tags {
            self.tag_service.create_tag(Tag {
                family_id: travel.family_id,
                group_id: Some(tag_group.id),
                name: tag_name,
                icon: Some(category.icon.clone()),
                color: Some(tag_group.color.clone()),
            }).await?;
        }
    }

    // 创建地点标签
    for location in template.default_tags.locations {
        self.tag_service.create_tag(Tag {
            family_id: travel.family_id,
            group_id: Some(tag_group.id),
            name: location,
            icon: Some("📍".to_string()),
            color: Some("#FF5722".to_string()),
        }).await?;
    }

    Ok(())
}
```

### 8.4 标签组分析与报告

```rust
pub struct TagGroupAnalysis {
    pub tag_group: TagGroup,
    pub total_tags: usize,
    pub total_usage: usize,
    pub top_tags: Vec<(Tag, usize)>,
    pub spending_by_tag: HashMap<Uuid, Decimal>,
    pub tag_combinations: Vec<(Vec<Tag>, usize)>,
    pub usage_timeline: Vec<(Date, usize)>,
}

pub async fn analyze_travel_tag_group(
    &self,
    travel_event_id: Uuid,
) -> Result<TagGroupAnalysis> {
    let travel = self.get_travel_event(travel_event_id).await?;
    let tag_group = self.get_travel_tag_group(travel_event_id).await?
        .ok_or_else(|| anyhow!("No tag group found for travel"))?;

    let transactions = self.get_travel_transactions(travel_event_id).await?;

    // 分析标签使用
    let analysis = self.tag_service.analyze_tag_group(
        tag_group.id,
        &transactions,
    ).await?;

    Ok(analysis)
}
```

## 总结

这个完整的旅行模式设计方案通过深度整合标签系统、智能化功能和用户友好的界面，为用户提供了一个全方位的旅行财务管理解决方案。

### 核心优势

1. **智能化**：AI驱动的标签推荐、自动分类、智能提醒
2. **灵活性**：支持各种旅行类型、多币种、离线模式
3. **便捷性**：快速记账、拍照识别、语音输入
4. **完整性**：从计划到回顾的全生命周期管理
5. **可视化**：丰富的图表、报告、数据分析

### 技术亮点

1. **标签组架构**：充分利用现有系统，扩展性强
2. **缓存策略**：多层缓存，性能优化
3. **离线支持**：完善的离线方案，数据同步
4. **模块化设计**：服务分层，易于维护和扩展

### 预期效果

- 用户旅行记账效率提升 **80%**
- 标签使用准确率达到 **95%**
- 预算控制成功率提升 **70%**
- 用户满意度提升 **90%**

通过这个方案，Jive Money 将成为一个真正智能、便捷、全面的旅行财务管理工具！