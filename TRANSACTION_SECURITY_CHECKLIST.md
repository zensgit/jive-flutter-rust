# 交易系统安全检查清单

**用途**: 开发/审查交易相关代码时的快速参考
**适用**: 后端开发人员、代码审查人员

---

## 🔐 安全编码检查清单

### ✅ 权限验证（所有端点必须）

```rust
// ✅ 标准模板
pub async fn your_transaction_handler(
    // ... 其他参数 ...
    State(pool): State<PgPool>,
    claims: Claims,  // 1. 必须包含 Claims
) -> ApiResult<...> {
    // 2. 提取用户和家庭 ID
    let user_id = claims.user_id()?;
    let family_id = claims.family_id
        .ok_or(ApiError::BadRequest("缺少 family_id".into()))?;

    // 3. 验证家庭访问权限
    let auth_service = AuthService::new(pool.clone());
    let ctx = auth_service
        .validate_family_access(user_id, family_id)
        .await
        .map_err(|_| ApiError::Forbidden)?;

    // 4. 检查具体操作权限
    ctx.require_permission(Permission::ViewTransactions)?;  // 根据操作调整

    // 5. 查询时限定家庭范围
    let query = "... JOIN ledgers l ON t.ledger_id = l.id
                 WHERE ... AND l.family_id = $1";
    // ...
}
```

**权限常量速查**:
- `Permission::ViewTransactions` - 查看交易
- `Permission::CreateTransactions` - 创建交易
- `Permission::EditTransactions` - 编辑交易
- `Permission::DeleteTransactions` - 删除交易
- `Permission::BulkEditTransactions` - 批量操作
- `Permission::ExportData` - 导出数据

---

### ✅ SQL 安全

#### 🚫 禁止：直接拼接用户输入

```rust
// ❌ 危险！
let sort_by = params.sort_by.unwrap_or_default();
query.push(format!(" ORDER BY {}", sort_by));  // SQL 注入风险
```

#### ✅ 推荐：白名单验证

```rust
// ✅ 安全
let sort_column = match params.sort_by.as_deref() {
    Some("date") => "t.transaction_date",
    Some("amount") => "t.amount",
    _ => "t.transaction_date",  // 默认值
};
query.push(format!(" ORDER BY {}", sort_column));
```

#### ✅ 参数化查询

```rust
// ✅ 使用 push_bind
query.push(" WHERE t.id = ");
query.push_bind(transaction_id);  // 自动转义
```

---

### ✅ 家庭隔离模式

**标准 JOIN 模式**:

```sql
-- ✅ 所有交易查询都应包含此 JOIN
SELECT t.*, ...
FROM transactions t
JOIN ledgers l ON t.ledger_id = l.id
WHERE t.deleted_at IS NULL
  AND l.family_id = $1  -- 家庭隔离
```

**双重验证**（更新/删除时）:

```rust
// 先验证所有权
let ownership = sqlx::query(
    "SELECT 1 FROM transactions t
     JOIN ledgers l ON t.ledger_id = l.id
     WHERE t.id = $1 AND l.family_id = $2"
)
.bind(id)
.bind(ctx.family_id)
.fetch_optional(&pool)
.await?;

if ownership.is_none() {
    return Err(ApiError::NotFound("无权限或不存在".into()));
}

// 再执行操作
```

---

### ✅ 数据完整性

**创建交易时必需字段**:

```rust
sqlx::query(
    r#"INSERT INTO transactions (
        id, account_id, ledger_id, amount, transaction_type,
        transaction_date, category_id, payee_id,
        description, notes, tags,
        created_by,     -- ✅ 必须包含
        created_at, updated_at
    ) VALUES (
        $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, NOW(), NOW()
    )"#
)
.bind(id)
// ... 其他绑定 ...
.bind(ctx.user_id)  // created_by 来自 Claims
.execute(&pool)
```

**字段类型对照表**:

| 字段 | Rust 类型 | SQL 类型 | 注意事项 |
|------|----------|---------|---------|
| `id` | `Uuid` | `UUID` | 主键 |
| `amount` | `Decimal` | `DECIMAL(15,2)` | 使用 rust_decimal |
| `transaction_date` | `NaiveDate` | `DATE` | 不含时区 |
| `tags` | `Option<Vec<String>>` | `TEXT[]` | PostgreSQL 数组 |
| `created_by` | `Uuid` | `UUID NOT NULL` | 必填 |
| `payee_id` | `Option<Uuid>` | `UUID` | 外键到 payees |

---

### ✅ CSV 导出安全

**使用安全转义函数**:

```rust
// ✅ 使用项目提供的转义函数
use crate::handlers::transactions::csv_escape_cell;

let escaped = csv_escape_cell(user_input, ',');
```

**危险字符列表**（会自动前缀单引号）:
- `=` - Excel 公式
- `+` - 公式运算符
- `-` - 公式运算符
- `@` - Excel 宏
- `|` - DDE 攻击
- `＝﹢－＠` - 全角字符

---

## 🚨 常见错误及修复

### 错误 1: 缺少家庭隔离

```rust
// ❌ 错误
SELECT * FROM transactions WHERE id = $1

// ✅ 正确
SELECT t.* FROM transactions t
JOIN ledgers l ON t.ledger_id = l.id
WHERE t.id = $1 AND l.family_id = $2
```

### 错误 2: created_by 为 NULL

```rust
// ❌ 错误（缺少 created_by）
INSERT INTO transactions (...) VALUES (...)

// ✅ 正确
INSERT INTO transactions (..., created_by, ...) VALUES (..., $n, ...)
.bind(ctx.user_id)
```

### 错误 3: payees 表不存在

```sql
-- ✅ 确保已运行 migration 040
SELECT table_name FROM information_schema.tables
WHERE table_name = 'payees';
-- 应返回 1 行
```

### 错误 4: SQL 注入

```rust
// ❌ 错误
let query = format!("ORDER BY {}", user_input);

// ✅ 正确
let column = match user_input {
    "date" => "transaction_date",
    _ => "transaction_date"
};
let query = format!("ORDER BY {}", column);
```

---

## 🔍 代码审查检查点

### Pull Request 审查清单

- [ ] **权限检查**: 所有 handler 包含 `claims: Claims`
- [ ] **家庭隔离**: 查询包含 `JOIN ledgers ... WHERE l.family_id = $n`
- [ ] **SQL 注入**: 无直接字符串拼接，使用 `push_bind()`
- [ ] **字段完整**: INSERT 包含所有 NOT NULL 字段
- [ ] **类型匹配**: Rust 类型与 SQL 类型一致
- [ ] **错误处理**: 数据库错误正确转换为 `ApiError`
- [ ] **测试覆盖**: 包含权限测试和家庭隔离测试

### 自动化检查脚本

```bash
#!/bin/bash
# check_transaction_security.sh

echo "🔍 检查交易安全..."

# 检查 1: Handler 是否包含 Claims
echo "检查权限验证..."
grep -r "async fn.*transaction" src/handlers/transactions.rs | while read -r line; do
  if ! echo "$line" | grep -q "claims: Claims"; then
    echo "⚠️ 缺少 Claims: $line"
  fi
done

# 检查 2: 查询是否包含家庭隔离
echo "检查家庭隔离..."
grep -r "FROM transactions" src/handlers/transactions.rs | while read -r line; do
  if ! echo "$line" | grep -q "JOIN ledgers"; then
    echo "⚠️ 缺少家庭隔离: $line"
  fi
done

# 检查 3: created_by 字段
echo "检查 created_by 字段..."
grep -r "INSERT INTO transactions" src/handlers/transactions.rs | while read -r line; do
  if ! echo "$line" | grep -q "created_by"; then
    echo "⚠️ 缺少 created_by: $line"
  fi
done

echo "✅ 检查完成"
```

---

## 📊 性能优化建议

### 查询优化

```rust
// ✅ 使用索引字段过滤
WHERE t.ledger_id = $1  -- 有索引
  AND t.transaction_date >= $2  -- 有索引

// ✅ 避免 SELECT *
SELECT t.id, t.amount, t.transaction_date  -- 只选需要的字段

// ✅ 分页查询
LIMIT $1 OFFSET $2
```

### 批量操作

```rust
// ✅ 使用事务
let mut tx = pool.begin().await?;
for item in items {
    // 执行操作
}
tx.commit().await?;

// ✅ 批量 INSERT
let mut query = QueryBuilder::new("INSERT INTO transactions (...) VALUES");
let mut separated = query.separated(", ");
for item in items {
    separated.push("(");
    separated.push_bind_unseparated(item.id);
    // ...
    separated.push_unseparated(")");
}
query.build().execute(&pool).await?;
```

---

## 🧪 测试模板

### 单元测试

```rust
#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_family_isolation() {
        let pool = get_test_pool().await;

        // 创建两个家庭的交易
        let family_a_tx = create_test_transaction(&pool, family_a_id).await;
        let family_b_tx = create_test_transaction(&pool, family_b_id).await;

        // 家庭 A 用户不应看到家庭 B 的交易
        let claims_a = Claims { family_id: Some(family_a_id), ... };
        let result = list_transactions(
            Query(TransactionQuery::default()),
            State(pool.clone()),
            claims_a
        ).await.unwrap();

        assert!(!result.0.iter().any(|t| t.id == family_b_tx.id));
    }

    #[tokio::test]
    async fn test_permission_required() {
        let pool = get_test_pool().await;
        let claims = Claims {
            user_id: viewer_user_id,
            family_id: Some(family_id),
            permissions: vec![Permission::ViewTransactions],  // 无删除权限
            ...
        };

        let result = delete_transaction(
            Path(transaction_id),
            State(pool),
            claims
        ).await;

        assert!(matches!(result, Err(ApiError::Forbidden)));
    }
}
```

---

## 📚 快速参考

### 常用命令

```bash
# 运行测试
cargo test transaction

# 检查编译错误
cargo check -p jive-money-api

# 运行 migration
sqlx migrate run

# 查看 payees 表
psql -h localhost -p 15432 -U postgres -d jive_money -c "\d payees"
```

### 环境变量

```bash
DATABASE_URL=postgresql://postgres:postgres@localhost:15432/jive_money
API_PORT=18012
JWT_SECRET=your_secret_key
```

### 日志调试

```rust
use tracing::{info, warn, error};

info!("交易创建: id={}, user={}", id, user_id);
warn!("权限不足: user={}, required={:?}", user_id, permission);
error!("数据库错误: {}", e);
```

---

## 🆘 应急响应

### 发现安全漏洞时

1. **立即**: 记录漏洞细节（勿公开）
2. **评估**: 确定影响范围和严重性
3. **修复**: 按 `TRANSACTION_FIX_GUIDE.md` 执行
4. **验证**: 运行安全测试
5. **部署**: 发布补丁版本
6. **通知**: 通知受影响用户（如需要）

### 紧急回滚

```bash
# Git 回滚
git revert <commit_hash>

# 数据库回滚
sqlx migrate revert

# 服务重启
systemctl restart jive-api
```

---

**保持此文档在手边，确保每次修改交易代码时都遵循这些规范！**

**最后更新**: 2025-10-12
