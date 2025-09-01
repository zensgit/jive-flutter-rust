# 账户管理API设计与测试文档

## 1. 设计概述

### 1.1 功能范围
账户管理API提供以下功能：
- 账户的创建、查询、更新和删除（CRUD）
- 账户余额管理
- 账户统计信息
- 多账本（ledger）支持
- 软删除机制

### 1.2 数据模型

```sql
accounts表结构：
- id: UUID (主键)
- ledger_id: UUID (账本ID)
- name: VARCHAR(255) (账户名称)
- account_type: VARCHAR(50) (账户类型)
- account_number: VARCHAR(100) (账号)
- institution_name: VARCHAR(255) (机构名称)
- currency: VARCHAR(10) (货币)
- current_balance: DECIMAL(19,4) (当前余额)
- available_balance: DECIMAL(19,4) (可用余额)
- credit_limit: DECIMAL(19,4) (信用额度)
- status: VARCHAR(50) (状态)
- is_manual: BOOLEAN (是否手动账户)
- color: VARCHAR(7) (颜色代码)
- icon: VARCHAR(50) (图标)
- notes: TEXT (备注)
- created_at: TIMESTAMPTZ
- updated_at: TIMESTAMPTZ
- deleted_at: TIMESTAMPTZ (软删除)
```

### 1.3 API端点

| 方法 | 路径 | 描述 |
|------|------|------|
| GET | /api/v1/accounts | 获取账户列表 |
| GET | /api/v1/accounts/:id | 获取账户详情 |
| POST | /api/v1/accounts | 创建账户 |
| PUT | /api/v1/accounts/:id | 更新账户 |
| DELETE | /api/v1/accounts/:id | 删除账户 |
| GET | /api/v1/accounts/statistics | 获取账户统计 |

## 2. 实现细节

### 2.1 技术栈
- **框架**: Axum
- **数据库**: PostgreSQL + SQLx
- **序列化**: Serde
- **认证**: JWT (预留接口)
- **错误处理**: 自定义ApiError类型

### 2.2 核心组件

#### 错误处理模块 (error.rs)
```rust
pub enum ApiError {
    NotFound(String),
    BadRequest(String),
    Unauthorized,
    Forbidden,
    DatabaseError(String),
    ValidationError(String),
    InternalServerError,
}
```

#### 认证模块 (auth.rs)
- JWT令牌生成和验证
- Claims结构包含用户ID、邮箱、家庭ID
- FromRequestParts trait实现自动提取

#### 账户处理器 (handlers/accounts.rs)
- 完整的CRUD操作
- 动态查询构建
- 分页支持
- 软删除机制

## 3. 测试计划

### 3.1 单元测试

#### 测试数据准备
```bash
# 创建测试账本
INSERT INTO ledgers (id, name) VALUES 
('550e8400-e29b-41d4-a716-446655440001', 'Test Ledger 1');
```

### 3.2 集成测试

#### 3.2.1 创建账户测试
```bash
# 测试命令
curl -X POST http://localhost:8080/api/v1/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "ledger_id": "550e8400-e29b-41d4-a716-446655440001",
    "name": "工商银行储蓄卡",
    "account_type": "checking",
    "account_number": "6222****1234",
    "institution_name": "中国工商银行",
    "currency": "CNY",
    "initial_balance": 10000.00,
    "color": "#FF5733",
    "icon": "bank",
    "notes": "主要储蓄账户"
  }'

# 预期响应
{
  "id": "generated-uuid",
  "ledger_id": "550e8400-e29b-41d4-a716-446655440001",
  "name": "工商银行储蓄卡",
  "account_type": "checking",
  "current_balance": 10000.00,
  "status": "active",
  "created_at": "2025-09-01T00:00:00Z"
}
```

#### 3.2.2 查询账户列表测试
```bash
# 测试命令
curl -X GET "http://localhost:8080/api/v1/accounts?ledger_id=550e8400-e29b-41d4-a716-446655440001&page=1&per_page=10"

# 预期响应
[
  {
    "id": "uuid",
    "name": "工商银行储蓄卡",
    "account_type": "checking",
    "current_balance": 10000.00,
    ...
  }
]
```

#### 3.2.3 更新账户测试
```bash
# 测试命令
curl -X PUT http://localhost:8080/api/v1/accounts/{account_id} \
  -H "Content-Type: application/json" \
  -d '{
    "name": "工商银行主卡",
    "notes": "更新后的备注"
  }'

# 预期响应
{
  "id": "account_id",
  "name": "工商银行主卡",
  "notes": "更新后的备注",
  "updated_at": "2025-09-01T00:00:00Z"
}
```

#### 3.2.4 删除账户测试（软删除）
```bash
# 测试命令
curl -X DELETE http://localhost:8080/api/v1/accounts/{account_id}

# 预期响应
HTTP 204 No Content
```

#### 3.2.5 账户统计测试
```bash
# 测试命令
curl -X GET "http://localhost:8080/api/v1/accounts/statistics?ledger_id=550e8400-e29b-41d4-a716-446655440001"

# 预期响应
{
  "total_accounts": 5,
  "total_assets": 50000.00,
  "total_liabilities": 10000.00,
  "net_worth": 40000.00,
  "by_type": [
    {
      "account_type": "checking",
      "count": 2,
      "total_balance": 20000.00
    },
    {
      "account_type": "credit_card",
      "count": 1,
      "total_balance": -5000.00
    }
  ]
}
```

### 3.3 性能测试

#### 并发测试
```bash
# 使用Apache Bench进行并发测试
ab -n 1000 -c 10 http://localhost:8080/api/v1/accounts
```

#### 预期性能指标
- 响应时间 < 100ms (95分位)
- 并发支持 > 100 req/s
- 错误率 < 0.1%

### 3.4 错误场景测试

#### 3.4.1 无效账本ID
```bash
curl -X POST http://localhost:8080/api/v1/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "ledger_id": "invalid-uuid",
    "name": "Test Account"
  }'

# 预期响应: 400 Bad Request
```

#### 3.4.2 缺少必填字段
```bash
curl -X POST http://localhost:8080/api/v1/accounts \
  -H "Content-Type: application/json" \
  -d '{
    "ledger_id": "550e8400-e29b-41d4-a716-446655440001"
  }'

# 预期响应: 422 Unprocessable Entity
```

#### 3.4.3 不存在的账户
```bash
curl -X GET http://localhost:8080/api/v1/accounts/non-existent-id

# 预期响应: 404 Not Found
```

## 4. 部署检查清单

### 4.1 数据库准备
- [ ] 创建accounts表
- [ ] 创建account_balances表
- [ ] 创建必要的索引
- [ ] 设置更新触发器

### 4.2 环境变量
```bash
DATABASE_URL=postgresql://jive:jive_password@localhost/jive_money
JWT_SECRET=your-secret-key
RUST_LOG=info
```

### 4.3 健康检查
```bash
# 健康检查端点
curl http://localhost:8080/health

# 预期响应
{
  "status": "healthy",
  "service": "jive-money-api",
  "version": "1.0.0"
}
```

## 5. 已知问题和限制

1. **认证暂未启用**: 当前版本未启用JWT认证，所有端点均可公开访问
2. **事务支持**: 账户余额更新需要确保事务一致性
3. **货币转换**: 当前不支持多币种自动转换
4. **审计日志**: 暂未实现操作审计日志

## 6. 后续改进计划

1. 添加JWT认证中间件
2. 实现账户余额历史追踪
3. 添加账户分组功能
4. 支持账户导入/导出
5. 实现账户对账功能
6. 添加账户预算管理

## 7. API使用示例代码

### Rust客户端示例
```rust
use reqwest;
use serde_json::json;

async fn create_account() -> Result<(), Box<dyn std::error::Error>> {
    let client = reqwest::Client::new();
    let response = client
        .post("http://localhost:8080/api/v1/accounts")
        .json(&json!({
            "ledger_id": "550e8400-e29b-41d4-a716-446655440001",
            "name": "测试账户",
            "account_type": "checking"
        }))
        .send()
        .await?;
    
    println!("Response: {:?}", response.text().await?);
    Ok(())
}
```

### Flutter客户端示例
```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> createAccount() async {
  final response = await http.post(
    Uri.parse('http://localhost:8080/api/v1/accounts'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'ledger_id': '550e8400-e29b-41d4-a716-446655440001',
      'name': '测试账户',
      'account_type': 'checking',
    }),
  );
  
  if (response.statusCode == 200) {
    print('Account created: ${response.body}');
  } else {
    print('Failed to create account');
  }
}
```

## 8. 测试结果记录

| 测试项 | 状态 | 备注 |
|--------|------|------|
| 创建账户 | ✅ 通过 | 成功创建并返回账户信息 |
| 查询列表 | ✅ 通过 | 支持分页和过滤 |
| 更新账户 | ✅ 通过 | 部分字段更新正常 |
| 删除账户 | ✅ 通过 | 软删除机制正常 |
| 统计信息 | ✅ 通过 | 统计计算准确 |
| 错误处理 | ✅ 通过 | 错误响应符合预期 |
| 并发测试 | ⏳ 待测 | 需要压力测试工具 |

---

文档版本: 1.0.0  
最后更新: 2025-09-01  
作者: Jive开发团队