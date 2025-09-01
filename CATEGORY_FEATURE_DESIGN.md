# Jive Money 分类功能完整设计文档

## 目录
1. [功能概述](#1-功能概述)
2. [系统架构](#2-系统架构)
3. [核心功能模块](#3-核心功能模块)
4. [数据模型](#4-数据模型)
5. [API 接口](#5-api-接口)
6. [用户界面](#6-用户界面)
7. [业务流程](#7-业务流程)
8. [技术实现](#8-技术实现)
9. [部署方案](#9-部署方案)
10. [测试计划](#10-测试计划)

---

## 1. 功能概述

### 1.1 系统定位
Jive Money 分类系统是一个三层架构的财务分类管理系统，支持系统预设、用户自定义和灵活转换。

### 1.2 核心价值
- 📚 **完善的模板库**：提供 50+ 预设分类模板
- 🎯 **灵活的管理**：支持自定义、层级、拖拽排序
- 🔄 **智能转换**：分类可转换为标签
- 📊 **数据洞察**：使用统计和智能推荐

### 1.3 目标用户
- **普通用户**：使用分类记账，管理个人分类
- **管理员**：维护系统模板，查看使用统计

---

## 2. 系统架构

### 2.1 三层分类体系

```
┌────────────────────────────────────────────┐
│         第一层：系统分类模板                │
│   - 管理员维护                              │
│   - 全局共享                                │
│   - 版本控制                                │
└────────────────────────────────────────────┘
                    ↓ 导入
┌────────────────────────────────────────────┐
│         第二层：用户分类                    │
│   - 个人定制                                │
│   - 账本隔离                                │
│   - 层级管理                                │
└────────────────────────────────────────────┘
                    ↓ 转换
┌────────────────────────────────────────────┐
│         第三层：标签系统                    │
│   - 灵活标记                                │
│   - 多对多关系                              │
│   - 自由组合                                │
└────────────────────────────────────────────┘
```

### 2.2 技术架构

```
前端 (Flutter)
    ├── 分类管理页面
    ├── 模板库浏览
    ├── 转换对话框
    └── 批量操作界面
           ↓
API 层 (RESTful)
    ├── 用户 API
    └── 管理 API
           ↓
服务层 (Rust)
    ├── CategoryService
    ├── TemplateService
    └── ConversionService
           ↓
数据层 (PostgreSQL)
    ├── system_category_templates
    ├── user_categories
    └── category_batch_operations
```

---

## 3. 核心功能模块

### 3.1 系统模板管理
| 功能 | 说明 | 权限 |
|-----|------|-----|
| 模板 CRUD | 创建、读取、更新、删除模板 | 管理员 |
| 批量导入 | CSV/JSON 批量导入模板 | 管理员 |
| 版本管理 | 模板版本控制和发布 | 管理员 |
| 使用统计 | 查看模板使用情况 | 管理员 |
| 模板浏览 | 查看可用模板 | 所有用户 |

### 3.2 用户分类管理
| 功能 | 说明 | 特性 |
|-----|------|-----|
| 分类 CRUD | 创建、编辑、删除分类 | 支持自定义颜色、图标 |
| 层级管理 | 父子分类关系 | 最多两层 |
| 拖拽排序 | 调整分类顺序和层级 | 实时保存 |
| 模板导入 | 从系统模板导入 | 支持批量和自定义 |
| 使用统计 | 查看分类使用次数 | 点击查看交易明细 |

### 3.3 分类转换功能
| 功能 | 说明 | 选项 |
|-----|------|-----|
| 转为标签 | 分类转换为标签 | 可选应用到历史交易 |
| 分类合并 | 合并重复分类 | 交易自动迁移 |
| 批量重分类 | 批量更改交易分类 | 支持撤销 |
| 删除验证 | 有交易的分类删除确认 | 提供多种处理方式 |

### 3.4 交互增强功能
| 功能 | 说明 | 用户体验 |
|-----|------|-----|
| 交易明细查看 | 点击数量查看分类下交易 | 支持筛选和排序 |
| 快速切换 | 交易详情页快速更改分类 | 最近使用优先 |
| 智能推荐 | 基于使用习惯推荐分类 | 自动学习 |
| 操作撤销 | 支持撤销最近操作 | 24小时内有效 |

---

## 4. 数据模型

### 4.1 系统分类模板表
```sql
CREATE TABLE system_category_templates (
    id UUID PRIMARY KEY,
    -- 基础信息
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    name_zh VARCHAR(100),
    description TEXT,
    
    -- 分类属性
    classification VARCHAR(20) NOT NULL, -- income/expense/transfer
    color VARCHAR(7) NOT NULL,           -- #RRGGBB
    icon VARCHAR(50),                    -- 图标标识
    category_group VARCHAR(50),          -- 所属分组
    
    -- 元数据
    version VARCHAR(20),
    is_active BOOLEAN DEFAULT true,
    is_featured BOOLEAN DEFAULT false,   -- 是否推荐
    global_usage_count INTEGER DEFAULT 0,
    tags TEXT[],                         -- 标签数组
    
    -- 审计
    created_by UUID,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- 索引
    INDEX idx_group (category_group),
    INDEX idx_classification (classification),
    INDEX idx_featured (is_featured)
);
```

### 4.2 用户分类表
```sql
CREATE TABLE user_categories (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    ledger_id UUID NOT NULL,
    
    -- 基础信息
    name VARCHAR(100) NOT NULL,
    color VARCHAR(7) NOT NULL,
    icon VARCHAR(50),
    classification VARCHAR(20) NOT NULL,
    
    -- 层级关系
    parent_id UUID REFERENCES user_categories(id),
    position INTEGER DEFAULT 0,          -- 排序位置
    
    -- 来源追踪
    source_type VARCHAR(20),             -- system/custom
    template_id UUID REFERENCES system_category_templates(id),
    template_version VARCHAR(20),
    
    -- 统计
    usage_count INTEGER DEFAULT 0,
    last_used_at TIMESTAMP,
    
    -- 状态
    is_active BOOLEAN DEFAULT true,
    is_deleted BOOLEAN DEFAULT false,
    deleted_at TIMESTAMP,
    
    -- 审计
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    -- 约束和索引
    UNIQUE INDEX idx_user_ledger_name (user_id, ledger_id, name),
    INDEX idx_parent (parent_id),
    INDEX idx_usage (usage_count DESC),
    INDEX idx_position (position)
);
```

### 4.3 分类组表
```sql
CREATE TABLE category_groups (
    id UUID PRIMARY KEY,
    key VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    name_en VARCHAR(100),
    name_zh VARCHAR(100),
    description TEXT,
    icon VARCHAR(50),
    display_order INTEGER,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    
    INDEX idx_order (display_order)
);
```

### 4.4 批量操作记录表
```sql
CREATE TABLE category_batch_operations (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    operation_type VARCHAR(20) NOT NULL, -- recategorize/convert/merge
    original_data JSONB,                 -- 原始数据快照
    affected_transactions INTEGER DEFAULT 0,
    can_revert BOOLEAN DEFAULT true,
    reverted_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP,                -- 24小时过期
    
    INDEX idx_user_created (user_id, created_at DESC)
);
```

---

## 5. API 接口

### 5.1 用户端 API

#### 获取模板列表
```http
GET /api/v1/category-templates
Query Parameters:
  - group: string (可选) 按组筛选
  - classification: string (可选) income/expense/transfer
  - featured: boolean (可选) 只获取推荐
  - search: string (可选) 搜索关键词
  - page: number (默认1)
  - limit: number (默认20)

Response:
{
  "data": [
    {
      "id": "uuid",
      "name": "餐饮美食",
      "name_en": "Food & Dining",
      "color": "#eb5429",
      "icon": "utensils",
      "classification": "expense",
      "group": "daily_expense",
      "is_featured": true,
      "tags": ["热门", "必备"]
    }
  ],
  "pagination": {
    "total": 100,
    "page": 1,
    "limit": 20
  }
}
```

#### 导入模板
```http
POST /api/v1/categories/import
Body:
{
  "template_ids": ["uuid1", "uuid2"],
  "ledger_id": "uuid",
  "options": {
    "skip_existing": true,
    "customize": [
      {
        "template_id": "uuid1",
        "custom_name": "外出就餐",
        "custom_color": "#ff0000"
      }
    ]
  }
}

Response:
{
  "imported": 5,
  "skipped": 2,
  "failed": 0,
  "categories": [...]
}
```

#### 分类 CRUD
```http
# 创建分类
POST /api/v1/categories
Body:
{
  "name": "自定义分类",
  "classification": "expense",
  "color": "#6471eb",
  "icon": "tag",
  "parent_id": null,
  "ledger_id": "uuid"
}

# 更新分类
PUT /api/v1/categories/{id}
Body:
{
  "name": "新名称",
  "color": "#4da568",
  "position": 2
}

# 获取分类列表
GET /api/v1/categories
Query: ?ledger_id={uuid}&include_subcategories=true

# 删除分类
DELETE /api/v1/categories/{id}
Body:
{
  "deletion_strategy": "move_to_category",
  "target_category_id": "uuid"
}
```

#### 分类转换
```http
# 转为标签
POST /api/v1/categories/{id}/convert-to-tag
Body:
{
  "tag_name": "餐饮",
  "apply_to_transactions": true,
  "delete_category": false,
  "transaction_date_range": {
    "from": "2024-01-01",
    "to": "2024-12-31"
  }
}

Response:
{
  "tag": {
    "id": "uuid",
    "name": "餐饮",
    "color": "#eb5429"
  },
  "transactions_updated": 150,
  "category_status": "retained"
}
```

#### 获取分类交易
```http
GET /api/v1/categories/{id}/transactions
Query Parameters:
  - date_from: string
  - date_to: string
  - sort_by: date|amount
  - sort_order: asc|desc
  - page: number
  - limit: number

Response:
{
  "transactions": [...],
  "summary": {
    "total_amount": 5000.00,
    "average_amount": 250.00,
    "transaction_count": 20,
    "date_range": {
      "from": "2024-01-01",
      "to": "2024-12-31"
    }
  },
  "pagination": {...}
}
```

#### 批量操作
```http
# 批量重分类
POST /api/v1/transactions/batch-recategorize
Body:
{
  "transaction_ids": ["uuid1", "uuid2"],
  "target_category_id": "uuid",
  "add_tag": "原分类名",
  "create_batch_record": true
}

# 撤销批量操作
POST /api/v1/transactions/batch-undo/{batch_id}

# 层级调整
PUT /api/v1/categories/{id}/hierarchy
Body:
{
  "parent_id": "uuid|null",
  "position": 2
}
```

### 5.2 管理端 API

#### 模板管理
```http
# 创建模板
POST /api/v1/admin/category-templates
Headers: Authorization: Bearer {admin_token}
Body:
{
  "name": "新模板",
  "name_en": "New Template",
  "classification": "expense",
  "color": "#6471eb",
  "icon": "tag",
  "group": "daily_expense",
  "is_featured": true,
  "tags": ["新增"]
}

# 批量导入模板
POST /api/v1/admin/category-templates/bulk-import
Headers: Authorization: Bearer {admin_token}
Body:
{
  "templates": [...],
  "update_existing": true,
  "skip_validation": false
}

# 获取使用统计
GET /api/v1/admin/category-templates/statistics
Response:
{
  "total_templates": 50,
  "active_templates": 45,
  "most_used": [
    {
      "template_id": "uuid",
      "name": "餐饮美食",
      "usage_count": 1250
    }
  ]
}
```

---

## 6. 用户界面

### 6.1 用户端界面结构

#### 分类管理主页
```dart
CategoryManagementPage
├── AppBar
│   ├── 标题: "分类管理"
│   └── 操作: [新建分类按钮]
├── 统计面板
│   ├── 总分类数量
│   ├── 收入分类数量
│   ├── 支出分类数量
│   └── 转账分类数量
├── 搜索栏
│   ├── 搜索输入框
│   └── 筛选按钮
├── Tab 栏 (收入/支出/转账)
├── 分类列表
│   ├── 父分类项
│   │   ├── 分类图标和颜色
│   │   ├── 分类名称
│   │   ├── 使用次数(可点击)
│   │   ├── 拖拽手柄
│   │   └── 操作菜单
│   └── 子分类项 (缩进显示)
└── 浮动操作按钮
    ├── 新建分类
    └── 从模板导入
```

#### 模板库浏览页面
```dart
CategoryLibraryPage
├── AppBar
│   ├── 标题: "分类模板库"
│   ├── 更新时间显示
│   └── 刷新按钮
├── 更新提示条 (如有新模板)
├── 分组标签栏
│   ├── 全部
│   ├── 收入类别
│   ├── 日常消费
│   ├── 居住相关
│   └── ... (其他分组)
├── 模板网格
│   ├── 模板卡片
│   │   ├── 模板图标和颜色
│   │   ├── 模板名称
│   │   ├── 描述信息
│   │   ├── 推荐标识
│   │   ├── 已导入标识
│   │   └── 导入按钮
│   └── 加载更多
└── 下拉刷新支持
```

#### 分类转换对话框
```dart
CategoryToTagDialog
├── 标题: "转换为标签"
├── 分类信息展示
│   ├── 分类图标和颜色
│   ├── 分类名称
│   └── 使用次数
├── 转换选项
│   ├── 标签名称输入框
│   ├── "应用到历史交易" 选择框
│   └── "删除原分类" 选择框
├── 影响范围预览
│   ├── 受影响交易数量
│   └── 时间范围选择
└── 操作按钮
    ├── 取消按钮
    └── 确认转换按钮
```

#### 交易明细页面
```dart
CategoryTransactionsPage
├── AppBar
│   ├── 标题: "分类交易明细"
│   └── 筛选和排序按钮
├── 统计摘要
│   ├── 总金额
│   ├── 平均金额
│   ├── 交易笔数
│   └── 时间范围
├── 筛选栏
│   ├── 日期范围选择器
│   ├── 排序方式选择
│   └── 批量操作按钮
├── 交易列表
│   ├── 交易项
│   │   ├── 交易描述
│   │   ├── 交易金额
│   │   ├── 交易日期
│   │   ├── 选择框 (批量模式)
│   │   └── 快速重分类按钮
│   └── 分页加载
└── 批量操作工具栏 (选中时显示)
    ├── 重新分类
    ├── 添加标签
    └── 取消选择
```

### 6.2 管理端界面结构

#### 管理员控制台
```dart
AdminDashboard
├── AppBar: "管理员控制台"
├── 功能卡片网格
│   ├── 分类模板管理卡片
│   ├── 分类组管理卡片
│   ├── 使用统计卡片
│   └── 系统设置卡片
└── 快捷操作区
    ├── 批量导入按钮
    └── 数据导出按钮
```

#### 模板管理页面
```dart
CategoryTemplateManagementPage
├── AppBar
│   ├── 标题: "系统分类模板管理"
│   └── 操作按钮 [新建, 导入, 菜单]
├── 筛选和搜索栏
│   ├── 搜索输入框
│   ├── 分组筛选器
│   ├── 状态筛选器
│   └── 高级筛选按钮
├── 统计信息栏
│   ├── 总模板数
│   ├── 活跃模板数
│   ├── 推荐模板数
│   └── 使用统计链接
├── Tab 栏 (收入/支出/转账)
├── 模板列表
│   ├── 列表头 (可排序)
│   │   ├── 名称
│   │   ├── 分组
│   │   ├── 使用次数
│   │   ├── 状态
│   │   └── 操作
│   └── 模板行
│       ├── 模板图标和颜色
│       ├── 模板名称和描述
│       ├── 分组信息
│       ├── 使用统计
│       ├── 推荐标识
│       ├── 活跃状态开关
│       └── 操作菜单 [编辑, 复制, 删除]
└── 分页控件
```

#### 模板编辑对话框
```dart
CategoryTemplateEditDialog
├── 标题: "创建/编辑分类模板"
├── 表单字段
│   ├── 基础信息组
│   │   ├── 模板名称 (必填)
│   │   ├── 英文名称
│   │   ├── 中文名称
│   │   └── 描述
│   ├── 分类属性组
│   │   ├── 分类类型选择 (必填)
│   │   └── 所属分组选择 (必填)
│   ├── 视觉设置组
│   │   ├── 颜色选择器
│   │   └── 图标选择器
│   ├── 元数据组
│   │   ├── 标签输入 (可多个)
│   │   └── 设为推荐选择框
│   └── 预览区域
│       └── 实时预览效果
└── 操作按钮
    ├── 取消
    ├── 保存草稿
    └── 发布
```

### 6.3 交互设计要点

#### 拖拽排序
- **视觉反馈**：拖拽时高亮目标区域
- **约束提示**：不符合规则时显示禁止图标
- **实时保存**：拖拽完成后立即保存位置

#### 批量操作
- **多选模式**：长按进入多选模式
- **操作工具栏**：底部显示批量操作选项
- **进度显示**：批量操作时显示进度条

#### 智能提示
- **冲突检测**：同名分类实时提示
- **使用建议**：基于历史推荐分类
- **操作引导**：新用户操作引导

---

## 7. 业务流程

### 7.1 模板导入流程
```mermaid
graph TB
    A[用户打开分类库] --> B[浏览模板]
    B --> C[选择模板]
    C --> D{检查重复}
    D -->|存在重复| E[显示冲突处理选项]
    D -->|无重复| F[显示自定义选项]
    E --> G[用户选择处理方式]
    G --> H{处理方式}
    H -->|跳过| I[跳过该模板]
    H -->|重命名| J[自动重命名]
    H -->|覆盖| K[覆盖现有分类]
    F --> L[用户自定义名称/颜色]
    I --> M[处理下一个模板]
    J --> M
    K --> M
    L --> N[确认导入]
    N --> O[创建用户分类]
    O --> P[更新使用统计]
    P --> Q[导入完成]
    M --> R{还有模板?}
    R -->|是| C
    R -->|否| Q
```

### 7.2 分类转标签流程
```mermaid
graph TB
    A[用户选择分类] --> B[点击转换为标签]
    B --> C[打开转换对话框]
    C --> D[设置转换选项]
    D --> E{分类有交易?}
    E -->|否| F[直接转换]
    E -->|是| G[显示影响范围]
    G --> H[用户选择应用范围]
    H --> I[确认转换]
    I --> J[创建标签记录]
    J --> K{应用到交易?}
    K -->|是| L[批量更新交易标签]
    K -->|否| M[跳过交易更新]
    L --> N[创建批量操作记录]
    M --> O{删除原分类?}
    N --> O
    O -->|是| P[标记分类删除]
    O -->|否| Q[保留分类]
    F --> R[转换完成]
    P --> R
    Q --> R
    R --> S[显示转换结果]
```

### 7.3 分类删除验证流程
```mermaid
graph TB
    A[用户删除分类] --> B{分类有交易?}
    B -->|否| C[直接删除]
    B -->|是| D[显示删除确认对话框]
    D --> E[显示处理选项]
    E --> F{用户选择}
    F -->|移动到其他分类| G[显示分类选择器]
    F -->|转换为标签| H[执行转换流程]
    F -->|设为未分类| I[清除交易分类]
    F -->|取消| J[取消删除]
    G --> K[选择目标分类]
    K --> L[批量更新交易分类]
    H --> M[创建同名标签]
    M --> N[应用标签到交易]
    I --> O[清除分类引用]
    L --> P[创建批量操作记录]
    N --> P
    O --> P
    P --> Q[删除分类]
    Q --> R[删除完成]
    C --> R
    J --> S[操作取消]
```

### 7.4 批量重分类流程
```mermaid
graph TB
    A[进入分类交易页面] --> B[启用多选模式]
    B --> C[选择目标交易]
    C --> D[点击批量重分类]
    D --> E[显示目标分类选择器]
    E --> F[选择新分类]
    F --> G{添加标签选项?}
    G -->|是| H[输入标签名称]
    G -->|否| I[确认批量更改]
    H --> I
    I --> J[创建批量操作记录]
    J --> K[开始批量更新]
    K --> L[更新交易分类]
    L --> M{添加标签?}
    M -->|是| N[为交易添加标签]
    M -->|否| O[更新分类使用统计]
    N --> O
    O --> P[操作完成]
    P --> Q[显示操作结果]
    Q --> R[提供撤销选项]
```

---

## 8. 技术实现

### 8.1 缓存策略

#### 多级缓存架构
```dart
class CategoryCacheManager {
  // 缓存层级
  static const Duration MEMORY_TTL = Duration(minutes: 5);   // L1: 内存
  static const Duration LOCAL_TTL = Duration(hours: 24);     // L2: 本地存储
  static const Duration STALE_TTL = Duration(days: 7);       // L3: 过期缓存
  
  // 缓存键定义
  static const String TEMPLATES_KEY = 'system_templates';
  static const String USER_CATEGORIES_KEY = 'user_categories';
  static const String GROUPS_KEY = 'category_groups';
  
  final MemoryCache _memoryCache = MemoryCache();
  final LocalStorage _localStorage = LocalStorage('category_cache');
  
  /// 智能缓存获取
  Future<T?> get<T>(String key, T Function(Map<String, dynamic>) fromJson) async {
    // L1: 内存缓存
    final memoryData = _memoryCache.get(key);
    if (memoryData != null) {
      return memoryData as T;
    }
    
    // L2: 本地存储
    final localData = await _localStorage.get(key);
    if (localData != null && _isLocalCacheValid(key)) {
      final result = fromJson(localData);
      _memoryCache.set(key, result, MEMORY_TTL);
      return result;
    }
    
    return null;
  }
  
  /// 更新所有缓存层
  Future<void> set<T>(String key, T data) async {
    _memoryCache.set(key, data, MEMORY_TTL);
    await _localStorage.set(key, data);
    await _setMetadata(key, DateTime.now());
  }
  
  /// 缓存失效策略
  bool _isLocalCacheValid(String key) {
    final metadata = _getMetadata(key);
    if (metadata == null) return false;
    
    final age = DateTime.now().difference(metadata);
    return age < LOCAL_TTL;
  }
}
```

#### ETag 支持
```dart
class ETagManager {
  final Map<String, String> _etags = {};
  
  /// 添加 ETag 到请求头
  Map<String, String> getHeaders(String endpoint) {
    final headers = <String, String>{};
    final etag = _etags[endpoint];
    
    if (etag != null) {
      headers['If-None-Match'] = etag;
    }
    
    return headers;
  }
  
  /// 处理响应中的 ETag
  bool handleResponse(String endpoint, http.Response response) {
    final etag = response.headers['etag'];
    if (etag != null) {
      _etags[endpoint] = etag;
    }
    
    // 返回是否有更新
    return response.statusCode != 304;
  }
}
```

### 8.2 拖拽排序实现

```dart
class DraggableCategoryList extends StatefulWidget {
  final List<Category> categories;
  final Function(int oldIndex, int newIndex) onReorder;
  
  @override
  Widget build(BuildContext context) {
    return ReorderableListView.builder(
      itemCount: categories.length,
      onReorder: _handleReorder,
      itemBuilder: (context, index) {
        final category = categories[index];
        return DragTarget<Category>(
          key: ValueKey(category.id),
          onAccept: (draggedCategory) {
            _handleDrop(draggedCategory, category);
          },
          onWillAccept: (draggedCategory) {
            return _canAcceptDrop(draggedCategory, category);
          },
          builder: (context, candidateData, rejectedData) {
            return LongPressDraggable<Category>(
              data: category,
              feedback: CategoryDragFeedback(category: category),
              childWhenDragging: CategoryPlaceholder(category: category),
              child: CategoryListItem(
                category: category,
                isDropTarget: candidateData.isNotEmpty,
                canAcceptDrop: _canAcceptDrop(candidateData.firstOrNull, category),
              ),
            );
          },
        );
      },
    );
  }
  
  bool _canAcceptDrop(Category? dragged, Category target) {
    if (dragged == null) return false;
    
    // 不能拖到自己
    if (dragged.id == target.id) return false;
    
    // 不能拖到自己的子分类
    if (_isDescendant(target, dragged)) return false;
    
    // 分类类型必须一致
    if (dragged.classification != target.classification) return false;
    
    // 层级限制：最多两层
    if (target.isChild && dragged.hasChildren) return false;
    
    return true;
  }
  
  void _handleReorder(int oldIndex, int newIndex) {
    // 防抖处理
    _debouncer.run(() {
      widget.onReorder(oldIndex, newIndex);
    });
  }
}
```

### 8.3 批量操作实现

```dart
class BatchOperationManager {
  final List<BatchOperation> _operationQueue = [];
  final Map<String, Timer> _autoCommitTimers = {};
  
  /// 添加批量操作到队列
  Future<String> addOperation(BatchOperationRequest request) async {
    final operation = BatchOperation(
      id: _generateId(),
      type: request.type,
      userId: request.userId,
      originalData: request.originalData,
      targetData: request.targetData,
      status: BatchOperationStatus.pending,
      createdAt: DateTime.now(),
    );
    
    _operationQueue.add(operation);
    
    // 设置自动提交定时器
    _setAutoCommitTimer(operation.id);
    
    return operation.id;
  }
  
  /// 执行批量操作
  Future<BatchOperationResult> executeOperation(String operationId) async {
    final operation = _operationQueue.firstWhere((op) => op.id == operationId);
    
    operation.status = BatchOperationStatus.executing;
    
    try {
      switch (operation.type) {
        case BatchOperationType.recategorize:
          return await _executeBatchRecategorize(operation);
        case BatchOperationType.convertToTag:
          return await _executeBatchConversion(operation);
        case BatchOperationType.merge:
          return await _executeBatchMerge(operation);
      }
    } catch (e) {
      operation.status = BatchOperationStatus.failed;
      operation.error = e.toString();
      rethrow;
    }
  }
  
  /// 撤销批量操作
  Future<void> revertOperation(String operationId) async {
    final operation = _operationQueue.firstWhere((op) => op.id == operationId);
    
    if (!operation.canRevert) {
      throw Exception('Operation cannot be reverted');
    }
    
    if (operation.isExpired) {
      throw Exception('Operation has expired');
    }
    
    // 根据操作类型执行撤销
    await _revertByType(operation);
    
    operation.status = BatchOperationStatus.reverted;
    operation.revertedAt = DateTime.now();
  }
  
  void _setAutoCommitTimer(String operationId) {
    _autoCommitTimers[operationId] = Timer(Duration(hours: 24), () {
      _expireOperation(operationId);
    });
  }
}
```

### 8.4 实时同步机制

```dart
class CategorySyncManager {
  final StreamController<CategorySyncEvent> _eventController = 
      StreamController<CategorySyncEvent>.broadcast();
  
  Stream<CategorySyncEvent> get events => _eventController.stream;
  
  /// 同步本地更改到服务器
  Future<void> syncToServer(List<CategoryChange> changes) async {
    final syncBatch = SyncBatch(
      changes: changes,
      timestamp: DateTime.now(),
      deviceId: await _getDeviceId(),
    );
    
    try {
      final response = await _api.syncCategories(syncBatch);
      
      // 处理冲突
      if (response.hasConflicts) {
        await _resolveConflicts(response.conflicts);
      }
      
      // 更新本地状态
      await _updateLocalState(response.appliedChanges);
      
      _eventController.add(CategorySyncEvent.success(response));
    } catch (e) {
      _eventController.add(CategorySyncEvent.error(e));
    }
  }
  
  /// 冲突解决策略
  Future<void> _resolveConflicts(List<SyncConflict> conflicts) async {
    for (final conflict in conflicts) {
      switch (conflict.type) {
        case ConflictType.nameCollision:
          // 自动重命名
          await _autoResolveNameCollision(conflict);
          break;
        case ConflictType.deletedOnServer:
          // 询问用户是否恢复
          await _askUserToRestore(conflict);
          break;
        case ConflictType.modifiedOnBothSides:
          // 显示冲突解决界面
          await _showConflictResolutionUI(conflict);
          break;
      }
    }
  }
}
```

### 8.5 性能优化策略

#### 延迟加载
```dart
class LazyLoadingManager {
  final Map<String, Completer<List<Category>>> _loadingCache = {};
  
  /// 分页加载分类
  Future<List<Category>> loadCategories({
    required int page,
    required int pageSize,
    String? parentId,
  }) async {
    final cacheKey = 'categories_${parentId ?? 'root'}_${page}';
    
    // 防止重复请求
    if (_loadingCache.containsKey(cacheKey)) {
      return _loadingCache[cacheKey]!.future;
    }
    
    final completer = Completer<List<Category>>();
    _loadingCache[cacheKey] = completer;
    
    try {
      final categories = await _fetchCategoriesPage(page, pageSize, parentId);
      
      // 预加载下一页
      if (categories.length == pageSize) {
        _preloadNextPage(page + 1, pageSize, parentId);
      }
      
      completer.complete(categories);
      return categories;
    } catch (e) {
      completer.completeError(e);
      rethrow;
    } finally {
      _loadingCache.remove(cacheKey);
    }
  }
  
  void _preloadNextPage(int nextPage, int pageSize, String? parentId) {
    // 在后台预加载，不阻塞当前操作
    Future.microtask(() {
      loadCategories(page: nextPage, pageSize: pageSize, parentId: parentId);
    });
  }
}
```

#### 防抖优化
```dart
class Debouncer {
  final Duration delay;
  Timer? _timer;
  
  Debouncer({this.delay = const Duration(milliseconds: 500)});
  
  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }
  
  void dispose() {
    _timer?.cancel();
  }
}

// 使用示例
class SearchController {
  final Debouncer _searchDebouncer = Debouncer();
  
  void onSearchChanged(String query) {
    _searchDebouncer.run(() {
      _performSearch(query);
    });
  }
}
```

---

## 9. 部署方案

### 9.1 环境要求

#### 开发环境
- **Flutter**: 3.16.0+
- **Dart**: 3.2.0+
- **Rust**: 1.75.0+
- **PostgreSQL**: 15.0+
- **Redis**: 7.0+ (可选，用于缓存)

#### 生产环境
- **CPU**: 2 核心以上
- **内存**: 4GB 以上
- **存储**: 100GB SSD
- **网络**: 10Mbps 以上

### 9.2 数据库初始化

#### 创建数据库和用户
```sql
-- 创建数据库
CREATE DATABASE jive_money_prod;

-- 创建用户
CREATE USER jive_api WITH PASSWORD 'secure_password';

-- 授权
GRANT ALL PRIVILEGES ON DATABASE jive_money_prod TO jive_api;
GRANT USAGE ON SCHEMA public TO jive_api;
GRANT CREATE ON SCHEMA public TO jive_api;
```

#### 执行迁移脚本
```bash
# 运行数据库迁移
cd jive-api
sqlx migrate run --database-url="postgresql://jive_api:password@localhost/jive_money_prod"

# 或使用自定义脚本
psql -U jive_api -d jive_money_prod -f migrations/001_initial_schema.sql
psql -U jive_api -d jive_money_prod -f migrations/002_seed_data.sql
```

#### 种子数据
```sql
-- 插入默认分类组
INSERT INTO category_groups (id, key, name, name_en, name_zh, display_order) VALUES
('550e8400-e29b-41d4-a716-446655440001', 'income', '收入类别', 'Income', '收入类别', 1),
('550e8400-e29b-41d4-a716-446655440002', 'daily_expense', '日常消费', 'Daily Expenses', '日常消费', 2),
('550e8400-e29b-41d4-a716-446655440003', 'housing', '居住相关', 'Housing', '居住相关', 3),
('550e8400-e29b-41d4-a716-446655440004', 'health_education', '健康教育', 'Health & Education', '健康教育', 4),
('550e8400-e29b-41d4-a716-446655440005', 'entertainment_social', '娱乐社交', 'Entertainment & Social', '娱乐社交', 5),
('550e8400-e29b-41d4-a716-446655440006', 'financial', '金融理财', 'Financial', '金融理财', 6),
('550e8400-e29b-41d4-a716-446655440007', 'business', '商务办公', 'Business', '商务办公', 7);

-- 插入系统分类模板 (示例)
INSERT INTO system_category_templates (id, name, name_en, name_zh, classification, color, icon, category_group, is_featured) VALUES
('660e8400-e29b-41d4-a716-446655440001', '工资收入', 'Salary', '工资收入', 'income', '#10B981', 'circle-dollar-sign', 'income', true),
('660e8400-e29b-41d4-a716-446655440002', '餐饮美食', 'Food & Dining', '餐饮美食', 'expense', '#EF4444', 'utensils', 'daily_expense', true),
('660e8400-e29b-41d4-a716-446655440003', '交通出行', 'Transportation', '交通出行', 'expense', '#F97316', 'car', 'daily_expense', true);
```

### 9.3 后端部署

#### Docker 化部署
```dockerfile
# Dockerfile
FROM rust:1.75-slim as builder

WORKDIR /app
COPY . .

RUN apt-get update && apt-get install -y pkg-config libssl-dev
RUN cargo build --release

FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/target/release/jive-api .
COPY --from=builder /app/config ./config

EXPOSE 8080
CMD ["./jive-api"]
```

#### 配置文件
```toml
# config/production.toml
[server]
host = "0.0.0.0"
port = 8080
workers = 4

[database]
url = "postgresql://jive_api:password@postgres:5432/jive_money_prod"
max_connections = 20
min_connections = 5
acquire_timeout = 30

[redis]
url = "redis://redis:6379"
pool_size = 10

[cors]
allowed_origins = ["https://app.jivemoney.com", "https://admin.jivemoney.com"]
allowed_methods = ["GET", "POST", "PUT", "DELETE", "PATCH"]
allowed_headers = ["Content-Type", "Authorization"]

[auth]
jwt_secret = "${JWT_SECRET}"
token_expiry = 86400  # 24 hours

[logging]
level = "info"
format = "json"

[cache]
enabled = true
default_ttl = 3600
```

#### Docker Compose
```yaml
version: '3.8'

services:
  api:
    build: .
    ports:
      - "8080:8080"
    environment:
      - RUST_ENV=production
      - JWT_SECRET=${JWT_SECRET}
    depends_on:
      - postgres
      - redis
    restart: unless-stopped
    
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: jive_money_prod
      POSTGRES_USER: jive_api
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./migrations:/docker-entrypoint-initdb.d
    restart: unless-stopped
    
  redis:
    image: redis:7-alpine
    restart: unless-stopped
    
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - /etc/letsencrypt:/etc/letsencrypt
    depends_on:
      - api
    restart: unless-stopped

volumes:
  postgres_data:
```

### 9.4 前端构建

#### Android 构建
```bash
# 生产构建
flutter build apk --release --target-platform android-arm64

# 生成签名 APK
flutter build apk --release --target-platform android-arm64 \
  --key-store=key.jks \
  --key-store-password=$KEYSTORE_PASSWORD \
  --key-alias=jive-money \
  --key-password=$KEY_PASSWORD
```

#### iOS 构建
```bash
# 生产构建
flutter build ios --release

# Archive (需要在 macOS 上执行)
cd ios && xcodebuild -workspace Runner.xcworkspace \
  -scheme Runner -archivePath build/Runner.xcarchive archive

# 导出 IPA
xcodebuild -exportArchive -archivePath build/Runner.xcarchive \
  -exportPath build/ios -exportOptionsPlist ExportOptions.plist
```

#### Web 构建
```bash
# Web 构建
flutter build web --release --web-renderer html

# 优化构建
flutter build web --release \
  --web-renderer html \
  --dart-define=FLUTTER_WEB_USE_SKIA=false \
  --source-maps
```

### 9.5 CI/CD 配置

#### GitHub Actions
```yaml
name: Build and Deploy

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
          
      - name: Setup Rust
        uses: actions-rs/toolchain@v1
        with:
          toolchain: 1.75.0
          
      - name: Run Flutter tests
        run: |
          cd jive-flutter
          flutter test
          
      - name: Run Rust tests
        run: |
          cd jive-api
          cargo test

  build-android:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        
      - name: Build APK
        run: |
          cd jive-flutter
          flutter build apk --release
          
      - name: Upload APK
        uses: actions/upload-artifact@v3
        with:
          name: app-release.apk
          path: jive-flutter/build/app/outputs/flutter-apk/app-release.apk

  deploy-api:
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v3
      
      - name: Build and push Docker image
        env:
          DOCKER_REGISTRY: ${{ secrets.DOCKER_REGISTRY }}
        run: |
          docker build -t $DOCKER_REGISTRY/jive-api:latest ./jive-api
          docker push $DOCKER_REGISTRY/jive-api:latest
          
      - name: Deploy to production
        uses: appleboy/ssh-action@v0.1.7
        with:
          host: ${{ secrets.PRODUCTION_HOST }}
          username: ${{ secrets.PRODUCTION_USER }}
          key: ${{ secrets.PRODUCTION_SSH_KEY }}
          script: |
            cd /opt/jive-money
            docker-compose pull api
            docker-compose up -d api
```

---

## 10. 测试计划

### 10.1 测试策略

#### 测试金字塔
```
        /\
       /UI\      <- 少量 UI 测试（10%）
      /____\
     /      \
    / Widget \    <- 中等 Widget 测试（30%）
   /__________\
  /            \
 /     Unit     \ <- 大量单元测试（60%）
/________________\
```

### 10.2 单元测试

#### Rust 后端测试
```rust
#[cfg(test)]
mod tests {
    use super::*;
    
    #[tokio::test]
    async fn test_create_category_template() {
        let service = CategoryTemplateService::new_for_test();
        
        let template = CreateTemplateRequest {
            name: "Test Template".to_string(),
            classification: Classification::Expense,
            color: "#FF0000".to_string(),
            icon: "test-icon".to_string(),
            group: "test_group".to_string(),
        };
        
        let result = service.create_template(template).await;
        
        assert!(result.is_ok());
        let created = result.unwrap();
        assert_eq!(created.name, "Test Template");
        assert_eq!(created.color, "#FF0000");
    }
    
    #[tokio::test]
    async fn test_import_template_with_conflict() {
        let service = CategoryService::new_for_test();
        
        // 创建现有分类
        let existing = service.create_category(CreateCategoryRequest {
            name: "Existing Category".to_string(),
            // ...
        }).await.unwrap();
        
        // 尝试导入同名模板
        let import_request = ImportTemplateRequest {
            template_ids: vec!["template_id".to_string()],
            options: ImportOptions {
                skip_existing: true,
                // ...
            },
        };
        
        let result = service.import_templates(import_request).await;
        
        assert!(result.is_ok());
        let import_result = result.unwrap();
        assert_eq!(import_result.skipped, 1);
        assert_eq!(import_result.imported, 0);
    }
    
    #[tokio::test]
    async fn test_convert_category_to_tag() {
        let service = CategoryConversionService::new_for_test();
        
        // 创建分类和交易
        let category = create_test_category().await;
        let transactions = create_test_transactions(&category.id, 5).await;
        
        let conversion_request = ConversionRequest {
            category_id: category.id,
            tag_name: Some("Test Tag".to_string()),
            apply_to_transactions: true,
            delete_category: true,
        };
        
        let result = service.convert_to_tag(conversion_request).await;
        
        assert!(result.is_ok());
        let conversion_result = result.unwrap();
        assert_eq!(conversion_result.transactions_updated, 5);
        assert_eq!(conversion_result.category_status, CategoryStatus::Deleted);
        
        // 验证标签是否创建
        let tag = service.get_tag(conversion_result.tag.id).await;
        assert!(tag.is_ok());
        assert_eq!(tag.unwrap().name, "Test Tag");
    }
}
```

#### Flutter 前端测试
```dart
void main() {
  group('CategoryProvider Tests', () {
    late CategoryProvider provider;
    late MockCategoryService mockService;
    
    setUp(() {
      mockService = MockCategoryService();
      provider = CategoryProvider(mockService);
    });
    
    testWidgets('should load categories successfully', (tester) async {
      // Arrange
      final categories = [
        Category(id: '1', name: 'Test Category', classification: CategoryClassification.expense),
      ];
      when(mockService.getCategories(any)).thenAnswer((_) async => categories);
      
      // Act
      await provider.loadCategories('ledger_id');
      
      // Assert
      expect(provider.categories, equals(categories));
      expect(provider.isLoading, false);
      verify(mockService.getCategories('ledger_id')).called(1);
    });
    
    testWidgets('should handle import template', (tester) async {
      // Arrange
      final template = SystemCategoryTemplate(
        id: 'template_1',
        name: 'Template Category',
        classification: CategoryClassification.expense,
      );
      final importOptions = ImportOptions(skipExisting: true);
      
      when(mockService.importTemplate(any, any))
          .thenAnswer((_) async => ImportResult(imported: 1, skipped: 0));
      
      // Act
      final result = await provider.importTemplate(template, importOptions);
      
      // Assert
      expect(result.imported, 1);
      expect(result.skipped, 0);
      verify(mockService.importTemplate(template, importOptions)).called(1);
    });
    
    testWidgets('should convert category to tag', (tester) async {
      // Arrange
      final category = Category(id: '1', name: 'Test Category');
      final conversionOptions = ConversionOptions(
        tagName: 'Test Tag',
        applyToTransactions: true,
      );
      
      when(mockService.convertToTag(any, any))
          .thenAnswer((_) async => ConversionResult(
            tag: Tag(id: 'tag_1', name: 'Test Tag'),
            transactionsUpdated: 10,
          ));
      
      // Act
      final result = await provider.convertToTag(category, conversionOptions);
      
      // Assert
      expect(result.tag.name, 'Test Tag');
      expect(result.transactionsUpdated, 10);
    });
  });
  
  group('CategoryManagementPage Widget Tests', () {
    testWidgets('should display categories in list', (tester) async {
      // Arrange
      final categories = [
        Category(id: '1', name: 'Food', classification: CategoryClassification.expense),
        Category(id: '2', name: 'Transport', classification: CategoryClassification.expense),
      ];
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: CategoryManagementPage(),
        ),
      );
      
      // Mock provider data
      final provider = Provider.of<CategoryProvider>(tester.element(find.byType(CategoryManagementPage)), listen: false);
      provider.setCategories(categories);
      await tester.pump();
      
      // Assert
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Transport'), findsOneWidget);
    });
    
    testWidgets('should show import dialog when template library button tapped', (tester) async {
      // Arrange
      await tester.pumpWidget(MaterialApp(home: CategoryManagementPage()));
      
      // Act
      await tester.tap(find.byIcon(Icons.library_books));
      await tester.pumpAndSettle();
      
      // Assert
      expect(find.byType(CategoryLibraryPage), findsOneWidget);
    });
  });
}
```

### 10.3 集成测试

#### API 端到端测试
```rust
#[cfg(test)]
mod integration_tests {
    use super::*;
    use rocket::local::blocking::Client;
    use rocket::http::{Status, ContentType};
    
    #[test]
    fn test_create_and_get_template() {
        let client = Client::tracked(rocket()).expect("valid rocket instance");
        
        // Create template
        let template_data = json!({
            "name": "Integration Test Template",
            "classification": "expense",
            "color": "#FF0000",
            "icon": "test-icon",
            "group": "test_group"
        });
        
        let response = client
            .post("/api/v1/admin/category-templates")
            .header(ContentType::JSON)
            .header(Header::new("Authorization", "Bearer admin_token"))
            .body(template_data.to_string())
            .dispatch();
        
        assert_eq!(response.status(), Status::Created);
        
        let created_template: SystemCategoryTemplate = response.into_json().expect("valid json");
        
        // Get template
        let get_response = client
            .get(format!("/api/v1/category-templates/{}", created_template.id))
            .dispatch();
        
        assert_eq!(get_response.status(), Status::Ok);
        
        let retrieved_template: SystemCategoryTemplate = get_response.into_json().expect("valid json");
        assert_eq!(retrieved_template.name, "Integration Test Template");
    }
    
    #[test]
    fn test_import_template_workflow() {
        let client = Client::tracked(rocket()).expect("valid rocket instance");
        
        // Create user and ledger first
        let user_token = create_test_user(&client);
        let ledger_id = create_test_ledger(&client, &user_token);
        
        // Create system template
        let template_id = create_test_template(&client).id;
        
        // Import template
        let import_data = json!({
            "template_ids": [template_id],
            "ledger_id": ledger_id,
            "options": {
                "skip_existing": false
            }
        });
        
        let response = client
            .post("/api/v1/categories/import")
            .header(ContentType::JSON)
            .header(Header::new("Authorization", format!("Bearer {}", user_token)))
            .body(import_data.to_string())
            .dispatch();
        
        assert_eq!(response.status(), Status::Ok);
        
        let import_result: ImportResult = response.into_json().expect("valid json");
        assert_eq!(import_result.imported, 1);
        assert_eq!(import_result.skipped, 0);
        
        // Verify category was created
        let categories_response = client
            .get(format!("/api/v1/categories?ledger_id={}", ledger_id))
            .header(Header::new("Authorization", format!("Bearer {}", user_token)))
            .dispatch();
        
        assert_eq!(categories_response.status(), Status::Ok);
        
        let categories: Vec<UserCategory> = categories_response.into_json().expect("valid json");
        assert_eq!(categories.len(), 1);
        assert_eq!(categories[0].source_type, Some("system".to_string()));
    }
}
```

#### Flutter 集成测试
```dart
void main() {
  group('Category Management Integration Tests', () {
    late IntegrationTestWidgetsFlutterBinding binding;
    
    setUpAll(() {
      binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
    });
    
    testWidgets('complete category import workflow', (tester) async {
      // Launch app
      await tester.pumpWidget(JiveMoneyApp());
      await tester.pumpAndSettle();
      
      // Navigate to category management
      await tester.tap(find.byIcon(Icons.category));
      await tester.pumpAndSettle();
      
      // Open template library
      await tester.tap(find.text('从模板导入'));
      await tester.pumpAndSettle();
      
      // Select a template
      await tester.tap(find.text('餐饮美食').first);
      await tester.pumpAndSettle();
      
      // Confirm import
      await tester.tap(find.text('导入'));
      await tester.pumpAndSettle();
      
      // Verify category was imported
      expect(find.text('餐饮美食'), findsOneWidget);
      
      // Take screenshot
      await binding.takeScreenshot('category_imported');
    });
    
    testWidgets('category to tag conversion workflow', (tester) async {
      // Setup test data
      await setupTestCategories();
      
      await tester.pumpWidget(JiveMoneyApp());
      await tester.pumpAndSettle();
      
      // Navigate to category management
      await tester.tap(find.byIcon(Icons.category));
      await tester.pumpAndSettle();
      
      // Open category menu
      await tester.tap(find.byIcon(Icons.more_vert).first);
      await tester.pumpAndSettle();
      
      // Select convert to tag
      await tester.tap(find.text('转换为标签'));
      await tester.pumpAndSettle();
      
      // Configure conversion options
      await tester.enterText(find.byType(TextField), '美食标签');
      await tester.tap(find.byType(Checkbox));
      
      // Confirm conversion
      await tester.tap(find.text('确认转换'));
      await tester.pumpAndSettle();
      
      // Verify conversion completed
      expect(find.text('转换成功'), findsOneWidget);
      
      await binding.takeScreenshot('conversion_completed');
    });
  });
}
```

### 10.4 性能测试

#### 负载测试脚本
```bash
#!/bin/bash
# load_test.sh

# 测试模板列表 API
echo "Testing category templates API..."
wrk -t12 -c400 -d30s --timeout 10s \
    -H "Accept: application/json" \
    http://localhost:8080/api/v1/category-templates

# 测试用户分类 API
echo "Testing user categories API..."
wrk -t12 -c400 -d30s --timeout 10s \
    -H "Accept: application/json" \
    -H "Authorization: Bearer test_token" \
    http://localhost:8080/api/v1/categories?ledger_id=test_ledger

# 测试分类导入 API
echo "Testing category import API..."
wrk -t8 -c200 -d30s --timeout 10s \
    -s scripts/import_test.lua \
    http://localhost:8080/api/v1/categories/import
```

#### K6 性能测试
```javascript
import http from 'k6/http';
import { check, sleep } from 'k6';

export let options = {
  stages: [
    { duration: '2m', target: 100 }, // 上升到100个用户
    { duration: '5m', target: 100 }, // 保持100个用户
    { duration: '2m', target: 200 }, // 上升到200个用户
    { duration: '5m', target: 200 }, // 保持200个用户
    { duration: '2m', target: 0 },   // 降到0个用户
  ],
  thresholds: {
    http_req_duration: ['p(99)<1500'], // 99%的请求在1.5秒内完成
    http_req_failed: ['rate<0.1'],     // 错误率小于10%
  },
};

const BASE_URL = 'http://localhost:8080/api/v1';

export default function () {
  let response;
  
  // 测试获取模板列表
  response = http.get(`${BASE_URL}/category-templates`);
  check(response, {
    'get templates status is 200': (r) => r.status === 200,
    'get templates response time < 500ms': (r) => r.timings.duration < 500,
  });
  
  sleep(1);
  
  // 测试获取用户分类
  response = http.get(`${BASE_URL}/categories?ledger_id=test_ledger`, {
    headers: {
      'Authorization': 'Bearer test_token',
    },
  });
  check(response, {
    'get categories status is 200': (r) => r.status === 200,
    'get categories response time < 300ms': (r) => r.timings.duration < 300,
  });
  
  sleep(1);
}
```

### 10.5 测试覆盖率目标

| 测试类型 | 覆盖率目标 | 验证工具 |
|---------|-----------|----------|
| 单元测试 | 90%+ | `cargo tarpaulin`, `flutter test --coverage` |
| 集成测试 | 80%+ | 自定义测试报告 |
| API 测试 | 95%+ | Postman/Newman |
| UI 测试 | 70%+ | Flutter Integration Tests |

#### 覆盖率检查脚本
```bash
#!/bin/bash
# coverage_check.sh

echo "Checking Rust test coverage..."
cd jive-api
cargo tarpaulin --out Html --output-dir coverage

echo "Checking Flutter test coverage..."
cd ../jive-flutter
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html

echo "Coverage reports generated:"
echo "- Rust: jive-api/coverage/tarpaulin-report.html"
echo "- Flutter: jive-flutter/coverage/html/index.html"
```

---

## 附录

### A. 默认分类模板数据
```yaml
# 完整的 50+ 预设模板
category_templates:
  income:
    - name: "工资收入"
      name_en: "Salary"
      color: "#10B981"
      icon: "circle-dollar-sign"
      featured: true
    # ... 其他收入类别
  
  daily_expense:
    - name: "餐饮美食"
      name_en: "Food & Dining"
      color: "#EF4444"
      icon: "utensils"
      featured: true
    # ... 其他日常支出
  
  # ... 其他分组
```

### B. API 错误码规范
```yaml
error_codes:
  # 4xxx: 客户端错误
  4001: "分类名称重复"
  4002: "分类层级超限（最多两层）"
  4003: "分类正在使用，无法删除"
  4004: "模板不存在或已失效"
  4005: "权限不足，无法执行操作"
  4006: "账本不存在或无权访问"
  4007: "分类类型不匹配"
  4008: "批量操作已过期"
  
  # 5xxx: 服务器错误
  5001: "数据库连接失败"
  5002: "缓存服务不可用"
  5003: "文件上传失败"
  5004: "外部服务调用超时"
  5005: "数据同步失败"
```

### C. 性能基准
```yaml
performance_benchmarks:
  api_response_time:
    get_templates: "< 100ms (P95)"
    get_categories: "< 50ms (P95)"
    import_template: "< 200ms (P95)"
    convert_to_tag: "< 500ms (P95)"
  
  throughput:
    concurrent_users: 1000
    requests_per_second: 2000
    
  resource_usage:
    memory: "< 512MB (idle), < 1GB (peak)"
    cpu: "< 50% (normal load)"
    disk_io: "< 100 IOPS"
    
  mobile_app:
    cold_start: "< 3s"
    category_list_load: "< 1s"
    template_library_load: "< 2s"
    category_import: "< 5s (100 templates)"
```

### D. 安全检查清单
- [ ] SQL 注入防护
- [ ] XSS 攻击防护
- [ ] CSRF 保护
- [ ] 权限验证完整性
- [ ] 敏感数据加密
- [ ] API 限流机制
- [ ] 输入数据验证
- [ ] 日志脱敏处理

---

**文档版本**: 3.0  
**最后更新**: 2025-01-01  
**维护者**: Jive Money Team  
**状态**: ✅ 设计完成，待实施  
**下一步**: 开始 Phase 1 开发（数据模型和基础架构）