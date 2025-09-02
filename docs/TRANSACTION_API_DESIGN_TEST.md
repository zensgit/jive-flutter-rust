# 交易管理API设计与测试文档

## 1. 设计概述

### 1.1 功能范围
交易管理API提供完整的财务交易管理功能：
- 交易的创建、查询、更新和删除（CRUD）
- 高级搜索和过滤功能
- 批量操作支持
- 交易统计和分析
- 自动账户余额更新
- 软删除和数据恢复

### 1.2 数据模型

```sql
transactions表结构：
- id: UUID (主键)
- account_id: UUID (账户ID)
- ledger_id: UUID (账本ID)
- amount: DECIMAL(19,4) (金额)
- transaction_type: VARCHAR(50) (类型: income/expense/transfer)
- transaction_date: DATE (交易日期)
- category_id: UUID (分类ID)
- payee_id: UUID (收款人ID)
- payee_name: VARCHAR(255) (收款人名称)
- description: TEXT (描述)
- notes: TEXT (备注)
- tags: JSONB (标签数组)
- location: VARCHAR(255) (位置)
- receipt_url: TEXT (收据URL)
- status: VARCHAR(50) (状态: pending/cleared/reconciled)
- is_recurring: BOOLEAN (是否循环)
- recurring_rule: TEXT (循环规则)
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
- deleted_at: TIMESTAMPTZ (软删除)
```

### 1.3 API端点

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /api/v1/transactions | 获取交易列表 |
| GET | /api/v1/transactions/:id | 获取交易详情 |
| POST | /api/v1/transactions | 创建交易 |
| PUT | /api/v1/transactions/:id | 更新交易 |
| DELETE | /api/v1/transactions/:id | 删除交易 |
| POST | /api/v1/transactions/bulk | 批量操作 |
| GET | /api/v1/transactions/statistics | 获取统计信息 |

## 2. 核心特性

### 2.1 高级查询功能
- **多条件过滤**: 账户、日期范围、金额范围、分类、收款人等
- **全文搜索**: 在描述、备注、收款人名称中搜索
- **灵活排序**: 支持多字段排序
- **分页支持**: 可配置每页数量

### 2.2 自动余额管理
- 创建交易时自动更新账户余额
- 删除交易时自动回滚余额变化
- 事务保证数据一致性

### 2.3 批量操作
- 批量删除交易
- 批量更新分类
- 批量更新状态

### 2.4 统计分析
- 收入/支出汇总
- 按分类统计
- 按月度趋势分析
- 平均交易金额计算

## 3. 测试计划

### 3.1 数据库准备

```sql
-- 创建交易表
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL,
    ledger_id UUID NOT NULL,
    amount DECIMAL(19,4) NOT NULL,
    transaction_type VARCHAR(50) NOT NULL,
    transaction_date DATE NOT NULL,
    category_id UUID,
    payee_id UUID,
    payee_name VARCHAR(255),
    description TEXT,
    notes TEXT,
    tags JSONB,
    location VARCHAR(255),
    receipt_url TEXT,
    status VARCHAR(50) NOT NULL DEFAULT 'pending',
    is_recurring BOOLEAN DEFAULT false,
    recurring_rule TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 创建索引
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_ledger_id ON transactions(ledger_id);
CREATE INDEX idx_transactions_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_category_id ON transactions(category_id);
CREATE INDEX idx_transactions_payee_id ON transactions(payee_id);
CREATE INDEX idx_transactions_type ON transactions(transaction_type);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_deleted_at ON transactions(deleted_at);

-- 创建分类表（如果不存在）
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    parent_id UUID,
    icon VARCHAR(50),
    color VARCHAR(7),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 创建收款人表（如果不存在）
CREATE TABLE IF NOT EXISTS payees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    category_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 3.2 测试数据准备

```sql
-- 插入测试账本和账户
INSERT INTO ledgers (id, name) VALUES 
('550e8400-e29b-41d4-a716-446655440001', 'Test Ledger');

INSERT INTO accounts (id, ledger_id, name, account_type, current_balance) VALUES
('660e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', 'Test Account', 'checking', 10000.00);

-- 插入测试分类
INSERT INTO categories (id, ledger_id, name, type) VALUES
('770e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '餐饮', 'expense'),
('770e8400-e29b-41d4-a716-446655440002', '550e8400-e29b-41d4-a716-446655440001', '工资', 'income');

-- 插入测试收款人
INSERT INTO payees (id, ledger_id, name) VALUES
('880e8400-e29b-41d4-a716-446655440001', '550e8400-e29b-41d4-a716-446655440001', '星巴克');
```

### 3.3 功能测试

#### 3.3.1 创建交易测试

```bash
# 创建支出交易
curl -X POST http://localhost:8080/api/v1/transactions \
  -H "Content-Type: application/json" \
  -d '{
    "account_id": "660e8400-e29b-41d4-a716-446655440001",
    "ledger_id": "550e8400-e29b-41d4-a716-446655440001",
    "amount": 35.50,
    "transaction_type": "expense",
    "transaction_date": "2025-09-01",
    "category_id": "770e8400-e29b-41d4-a716-446655440001",
    "payee_name": "星巴克",
    "description": "咖啡",
    "tags": ["日常", "饮料"],
    "location": "北京市朝阳区"
  }'

# 预期响应
{
  "id": "generated-uuid",
  "amount": 35.50,
  "transaction_type": "expense",
  "transaction_date": "2025-09-01",
  "category_name": "餐饮",
  "payee_name": "星巴克",
  "status": "pending",
  "tags": ["日常", "饮料"]
}
```

#### 3.3.2 查询交易列表测试

```bash
# 按日期范围查询
curl -X GET "http://localhost:8080/api/v1/transactions?ledger_id=550e8400-e29b-41d4-a716-446655440001&start_date=2025-09-01&end_date=2025-09-30"

# 按分类查询
curl -X GET "http://localhost:8080/api/v1/transactions?category_id=770e8400-e29b-41d4-a716-446655440001"

# 全文搜索
curl -X GET "http://localhost:8080/api/v1/transactions?search=咖啡"

# 分页查询
curl -X GET "http://localhost:8080/api/v1/transactions?page=1&per_page=20&sort_by=transaction_date&sort_order=DESC"
```

#### 3.3.3 更新交易测试

```bash
curl -X PUT http://localhost:8080/api/v1/transactions/{transaction_id} \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 40.00,
    "notes": "加了蛋糕",
    "status": "cleared"
  }'
```

#### 3.3.4 批量操作测试

```bash
# 批量更新分类
curl -X POST http://localhost:8080/api/v1/transactions/bulk \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_ids": ["id1", "id2", "id3"],
    "operation": "update_category",
    "category_id": "770e8400-e29b-41d4-a716-446655440001"
  }'

# 批量删除
curl -X POST http://localhost:8080/api/v1/transactions/bulk \
  -H "Content-Type: application/json" \
  -d '{
    "transaction_ids": ["id1", "id2"],
    "operation": "delete"
  }'
```

#### 3.3.5 统计分析测试

```bash
curl -X GET "http://localhost:8080/api/v1/transactions/statistics?ledger_id=550e8400-e29b-41d4-a716-446655440001"

# 预期响应
{
  "total_count": 150,
  "total_income": 50000.00,
  "total_expense": 35000.00,
  "net_amount": 15000.00,
  "average_transaction": 566.67,
  "by_category": [
    {
      "category_id": "770e8400-e29b-41d4-a716-446655440001",
      "category_name": "餐饮",
      "count": 45,
      "total_amount": 3500.00,
      "percentage": 10.0
    }
  ],
  "by_month": [
    {
      "month": "2025-09",
      "income": 5000.00,
      "expense": 3500.00,
      "net": 1500.00,
      "transaction_count": 20
    }
  ]
}
```

### 3.4 余额一致性测试

```bash
# 1. 记录初始余额
curl -X GET http://localhost:8080/api/v1/accounts/660e8400-e29b-41d4-a716-446655440001

# 2. 创建支出交易（-100）
curl -X POST http://localhost:8080/api/v1/transactions \
  -d '{"amount": 100, "transaction_type": "expense", ...}'

# 3. 验证余额减少100

# 4. 删除该交易
curl -X DELETE http://localhost:8080/api/v1/transactions/{id}

# 5. 验证余额恢复
```

### 3.5 性能测试

```bash
# 批量创建测试数据
for i in {1..1000}; do
  curl -X POST http://localhost:8080/api/v1/transactions \
    -H "Content-Type: application/json" \
    -d "{
      \"amount\": $((RANDOM % 1000)),
      \"transaction_type\": \"expense\",
      \"transaction_date\": \"2025-09-01\",
      ...
    }" &
done

# 测试查询性能
time curl -X GET "http://localhost:8080/api/v1/transactions?page=1&per_page=100"
```

## 4. 错误处理测试

### 4.1 验证错误
```bash
# 缺少必填字段
curl -X POST http://localhost:8080/api/v1/transactions \
  -H "Content-Type: application/json" \
  -d '{"amount": 100}'
# 预期: 422 Unprocessable Entity

# 无效的UUID
curl -X GET http://localhost:8080/api/v1/transactions/invalid-uuid
# 预期: 400 Bad Request

# 不存在的交易
curl -X GET http://localhost:8080/api/v1/transactions/550e8400-e29b-41d4-a716-446655440099
# 预期: 404 Not Found
```

## 5. 安全性考虑

### 5.1 输入验证
- UUID格式验证
- 金额必须为正数
- 日期格式验证
- 枚举值验证（transaction_type, status）

### 5.2 SQL注入防护
- 使用参数化查询
- 避免字符串拼接

### 5.3 权限控制（待实现）
- 用户只能访问自己的账本数据
- 事务级别的权限控制

## 6. 优化建议

### 6.1 性能优化
- 添加适当的数据库索引
- 实现查询结果缓存
- 批量操作优化

### 6.2 功能增强
- 添加交易附件上传
- 实现自动分类建议
- 支持定期交易
- 添加交易模板

## 7. 测试结果汇总

| 测试项 | 状态 | 备注 |
|--------|------|------|
| 创建交易 | ✅ 待测 | 包含余额更新 |
| 查询列表 | ✅ 待测 | 支持多条件过滤 |
| 更新交易 | ✅ 待测 | 部分字段更新 |
| 删除交易 | ✅ 待测 | 软删除+余额回滚 |
| 批量操作 | ✅ 待测 | 支持3种操作 |
| 统计分析 | ✅ 待测 | 多维度统计 |
| 余额一致性 | ⏳ 待测 | 事务保证 |
| 性能测试 | ⏳ 待测 | 需要压测工具 |

---

文档版本: 1.0.0  
最后更新: 2025-09-01  
作者: Jive开发团队