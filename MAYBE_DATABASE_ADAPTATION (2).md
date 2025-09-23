# Jive Money 使用 Maybe 数据库结构适配方案

## 概述

直接采用Maybe的成熟数据库结构，可以大大加快Jive Money的开发进度。Maybe的数据库设计经过生产环境验证，包含了个人财务管理的所有必要功能。

## 1. 数据库技术栈对比

| 方面 | Maybe | Jive Money 建议 |
|-----|-------|-----------------|
| 数据库 | PostgreSQL | PostgreSQL (生产) / SQLite (本地) |
| 主键类型 | UUID | UUID |
| ORM | ActiveRecord (Rails) | SQLx (Rust) |
| 迁移工具 | Rails Migration | SQLx Migrate |

## 2. 核心表结构映射

### 2.1 用户和认证系统

#### Maybe表结构
```sql
-- families 表 (家庭/组织)
families:
  - id: uuid
  - name: string
  - currency: string (default: "USD")
  - locale: string (default: "en")
  - timezone: string
  - currency_preferences: jsonb
  
-- users 表
users:
  - id: uuid
  - email: string
  - family_id: uuid
  - role: string (admin/member)
  - preferences: jsonb
  
-- sessions 表
sessions:
  - id: uuid
  - user_id: uuid
  - logged_in_at: timestamp
```

#### Rust实体映射
```rust
// Rust结构体定义
#[derive(sqlx::FromRow, Serialize, Deserialize)]
pub struct Family {
    pub id: Uuid,
    pub name: String,
    pub currency: String,
    pub locale: String,
    pub timezone: Option<String>,
    pub currency_preferences: serde_json::Value,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(sqlx::FromRow, Serialize, Deserialize)]
pub struct User {
    pub id: Uuid,
    pub email: String,
    pub family_id: Uuid,
    pub role: String,
    pub preferences: serde_json::Value,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}
```

### 2.2 账户系统

#### Maybe表结构
```sql
-- accounts 表 (多态账户)
accounts:
  - id: uuid
  - family_id: uuid
  - name: string
  - accountable_type: string (多态类型)
  - accountable_id: uuid (多态ID)
  - balance: decimal(19,4)
  - currency: string
  - classification: virtual (asset/liability)
  - status: string (active/syncing/error)
  
-- 具体账户类型表
depositories: (储蓄/支票账户)
credit_cards: (信用卡)
loans: (贷款)
investments: (投资账户)
properties: (房产)
vehicles: (车辆)
cryptos: (加密货币)
```

#### Rust实体映射
```rust
#[derive(sqlx::FromRow, Serialize, Deserialize)]
pub struct Account {
    pub id: Uuid,
    pub family_id: Uuid,
    pub name: String,
    pub accountable_type: String,
    pub accountable_id: Uuid,
    pub balance: Decimal,
    pub currency: String,
    pub classification: String,
    pub status: String,
}

// 使用枚举处理多态类型
#[derive(Serialize, Deserialize)]
pub enum AccountType {
    Depository(Depository),
    CreditCard(CreditCard),
    Loan(Loan),
    Investment(Investment),
    Property(Property),
    Vehicle(Vehicle),
    Crypto(Crypto),
}
```

### 2.3 交易系统

#### Maybe表结构
```sql
-- entries 表 (账务条目)
entries:
  - id: uuid
  - account_id: uuid
  - amount: decimal(19,4)
  - currency: string
  - date: date
  - name: string
  - nature: string (inflow/outflow)
  
-- transactions 表
transactions:
  - id: uuid
  - entry_id: uuid
  - category_id: uuid
  - payee_id: uuid
  - notes: text
  
-- categories 表
categories:
  - id: uuid
  - family_id: uuid
  - name: string
  - color: string
  - classification: string (income/expense)
  - parent_id: uuid (层级分类)
```

#### Rust实体映射
```rust
#[derive(sqlx::FromRow, Serialize, Deserialize)]
pub struct Entry {
    pub id: Uuid,
    pub account_id: Uuid,
    pub amount: Decimal,
    pub currency: String,
    pub date: NaiveDate,
    pub name: String,
    pub nature: String,
}

#[derive(sqlx::FromRow, Serialize, Deserialize)]
pub struct Transaction {
    pub id: Uuid,
    pub entry_id: Uuid,
    pub category_id: Option<Uuid>,
    pub payee_id: Option<Uuid>,
    pub notes: Option<String>,
}
```

## 3. 数据访问层实现

### 3.1 Repository模式

```rust
// 使用Repository模式封装数据访问
pub struct AccountRepository {
    pool: Arc<PgPool>,
}

impl AccountRepository {
    pub async fn find_by_family(&self, family_id: Uuid) -> Result<Vec<Account>> {
        sqlx::query_as!(
            Account,
            r#"
            SELECT * FROM accounts 
            WHERE family_id = $1 
            ORDER BY name
            "#,
            family_id
        )
        .fetch_all(&*self.pool)
        .await
        .map_err(Into::into)
    }
    
    pub async fn create_with_accountable<T: Accountable>(
        &self,
        account: Account,
        accountable: T,
    ) -> Result<Account> {
        // 事务处理
        let mut tx = self.pool.begin().await?;
        
        // 先创建具体账户类型
        let accountable_id = accountable.save(&mut tx).await?;
        
        // 再创建账户记录
        let account = sqlx::query_as!(
            Account,
            r#"
            INSERT INTO accounts (
                family_id, name, accountable_type, 
                accountable_id, balance, currency
            )
            VALUES ($1, $2, $3, $4, $5, $6)
            RETURNING *
            "#,
            account.family_id,
            account.name,
            T::TYPE_NAME,
            accountable_id,
            account.balance,
            account.currency
        )
        .fetch_one(&mut tx)
        .await?;
        
        tx.commit().await?;
        Ok(account)
    }
}
```

### 3.2 迁移策略

```rust
// 使用sqlx-cli进行数据库迁移
// migrations/001_initial_schema.sql

-- 直接使用Maybe的schema.rb转换为SQL
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "plpgsql";

-- 创建枚举类型
CREATE TYPE account_status AS ENUM ('ok', 'syncing', 'error');

-- 创建families表
CREATE TABLE families (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255),
    currency VARCHAR(3) DEFAULT 'USD',
    locale VARCHAR(10) DEFAULT 'en',
    timezone VARCHAR(50),
    currency_preferences JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 继续其他表...
```

## 4. 功能适配策略

### 4.1 保持的功能（直接使用）
- ✅ 完整的账户体系（11种账户类型）
- ✅ Entry-Transaction双层交易模型
- ✅ 多层级分类系统
- ✅ 标签系统
- ✅ 预算管理
- ✅ 投资管理（securities, holdings, trades）
- ✅ 规则引擎（rules, rule_conditions）
- ✅ 定时交易（scheduled_transactions）
- ✅ 导入系统（imports, import_rows）

### 4.2 需要适配的功能

#### 多货币支持
Maybe已经有完整的多货币支持：
- exchange_rates表
- currency_preferences (JSONB)
- 每个balance都有currency字段

#### Plaid集成
Maybe已有Plaid表：
- plaid_items
- plaid_accounts

我们可以：
1. 保留表结构
2. 在Rust中实现Plaid API客户端
3. 复用同步逻辑

### 4.3 新增的功能（Jive特有）

```sql
-- Jive特有的WASM优化表
CREATE TABLE wasm_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    key VARCHAR(255) UNIQUE NOT NULL,
    value BYTEA NOT NULL,
    expires_at TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- 离线同步队列
CREATE TABLE sync_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES families(id),
    operation_type VARCHAR(50) NOT NULL,
    payload JSONB NOT NULL,
    status VARCHAR(20) DEFAULT 'pending',
    retry_count INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

## 5. 实施步骤

### 第1步：数据库初始化
```bash
# 1. 导出Maybe的schema为SQL
pg_dump -s maybe_production > maybe_schema.sql

# 2. 创建Jive数据库
createdb jive_money

# 3. 导入schema
psql jive_money < maybe_schema.sql

# 4. 运行Jive特有的迁移
sqlx migrate run
```

### 第2步：生成Rust实体
```bash
# 使用工具自动生成实体
cargo install sqlx-cli
sqlx prepare
```

### 第3步：实现Repository层
```rust
// 为每个主要实体创建Repository
pub mod repositories {
    pub mod family_repository;
    pub mod user_repository;
    pub mod account_repository;
    pub mod transaction_repository;
    pub mod category_repository;
    pub mod budget_repository;
}
```

### 第4步：创建Service层
```rust
// 业务逻辑层
pub mod services {
    pub mod auth_service;
    pub mod account_service;
    pub mod transaction_service;
    pub mod sync_service;
    pub mod import_service;
}
```

## 6. 数据兼容性保证

### 6.1 命名约定映射
| Maybe (Rails) | Jive (Rust) |
|---------------|-------------|
| snake_case | snake_case |
| created_at | created_at |
| updated_at | updated_at |
| _id 外键 | _id 外键 |

### 6.2 类型映射
| PostgreSQL | Rust (sqlx) |
|------------|-------------|
| UUID | uuid::Uuid |
| DECIMAL(19,4) | rust_decimal::Decimal |
| JSONB | serde_json::Value |
| TIMESTAMP WITH TIME ZONE | chrono::DateTime<Utc> |
| DATE | chrono::NaiveDate |

### 6.3 多态处理
```rust
// 处理Rails的多态关联
pub trait Accountable: Send + Sync {
    const TYPE_NAME: &'static str;
    async fn save(&self, tx: &mut PgConnection) -> Result<Uuid>;
}

impl Accountable for CreditCard {
    const TYPE_NAME: &'static str = "CreditCard";
    // 实现...
}
```

## 7. 性能优化

### 7.1 使用Maybe的索引
Maybe已经创建了优化的索引，直接受益：
- 复合索引
- 部分索引
- GIN索引（JSONB）

### 7.2 连接池配置
```rust
let pool = PgPoolOptions::new()
    .max_connections(20)
    .min_connections(5)
    .connect(&database_url)
    .await?;
```

### 7.3 查询优化
```rust
// 使用Maybe的查询模式
// 例如：获取账户余额时同时获取最新的balance记录
let accounts = sqlx::query!(
    r#"
    SELECT a.*, b.balance as latest_balance
    FROM accounts a
    LEFT JOIN LATERAL (
        SELECT balance 
        FROM balances 
        WHERE account_id = a.id 
        ORDER BY date DESC 
        LIMIT 1
    ) b ON true
    WHERE a.family_id = $1
    "#,
    family_id
)
.fetch_all(&pool)
.await?;
```

## 8. 迁移现有数据

如果Jive Money已有数据，创建迁移脚本：

```rust
// 数据迁移工具
pub async fn migrate_from_old_schema(old_db: &PgPool, new_db: &PgPool) -> Result<()> {
    // 1. 迁移用户
    // 2. 迁移账户
    // 3. 迁移交易
    // 4. 更新余额
    Ok(())
}
```

## 9. 优势总结

### 使用Maybe数据库结构的优势
1. **成熟度高**: 经过生产环境验证
2. **功能完整**: 包含所有财务管理功能
3. **性能优化**: 索引和查询已优化
4. **节省时间**: 减少数据库设计时间
5. **兼容性好**: 未来可能的数据交换

### 需要注意的点
1. **ORM差异**: Rails ActiveRecord vs Rust SQLx
2. **多态处理**: 需要在Rust中实现
3. **迁移工具**: 使用不同的迁移系统
4. **事务处理**: 确保ACID特性

## 10. 实施时间评估

| 任务 | 时间 |
|-----|------|
| 数据库初始化 | 4小时 |
| Rust实体生成 | 8小时 |
| Repository层 | 16小时 |
| Service层 | 24小时 |
| 测试和调试 | 8小时 |
| **总计** | **60小时** |

通过直接使用Maybe的数据库结构，可以节省至少100小时的数据库设计和优化时间，让团队专注于业务逻辑实现。