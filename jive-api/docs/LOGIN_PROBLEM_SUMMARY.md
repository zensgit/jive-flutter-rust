# 登录问题总结

## 当前状态

### 问题症状
1. **Flutter应用登录失败** - 返回 401 Unauthorized
2. **直接API测试也失败** - curl测试同样返回 401
3. **Token过期已清除** - localStorage已清空

### 已测试的登录凭据

全部失败 (401):
- `superadmin@jive.money` / `123456` ❌
- `superadmin@jive.money` / `admin123` ❌
- `test@jive.money` / `123456` ❌
- `test@jive.money` / `admin123` ❌

### 数据库用户状态

```sql
-- 6个active用户存在于数据库
SELECT id, email, role, is_active FROM users;
```

用户列表：
- superadmin@jive.money (role: user) ✅ active
- test@jive.money (role: user) ✅ active
- test@example.com (role: user) ✅ active
- admin@example.com (role: user) ✅ active
- superadmin@jive.com (role: superadmin) ✅ active

### Password Hash示例
```
$argon2id$v=19$m=19456,t=2,p=1$VE0e3g7U1HjmqOWAPRp51A$aRFqZJJdE8Jlwvo0r+CXqIaIcHiLqxXHhKmTq5xVlC0
```

## 可能的原因

1. **密码验证逻辑问题**
   - Auth handler可能有bug
   - Argon2验证配置错误

2. **API路由问题**
   - `/api/v1/auth/login` 可能没有正确注册
   - 中间件拦截了请求

3. **数据库连接问题**
   - 查询失败但没有日志
   - 用户查找逻辑错误

4. **编译问题**
   - 运行的API二进制文件与当前代码不匹配
   - 有编译错误但旧二进制仍在运行

## 需要排查的步骤

### 1. 检查API服务器日志
```bash
# 当前没有看到任何登录相关的日志输出
# 需要用DEBUG级别重启
RUST_LOG=debug cargo run --bin jive-api
```

### 2. 检查Auth Handler代码
```bash
find jive-api/src -name "*auth*" -type f
```

需要检查：
- login endpoint 实现
- password验证逻辑
- 错误日志是否输出

### 3. 直接测试密码验证
创建测试脚本验证argon2哈希：
```rust
// test_password.rs
use argon2::{Argon2, PasswordHash, PasswordVerifier};

fn main() {
    let hash = "$argon2id$v=19$m=19456,t=2,p=1$VE0e3g7U1HjmqOWAPRp51A$aRFqZJJdE8Jlwvo0r+CXqIaIcHiLqxXHhKmTq5xVlC0";
    let parsed_hash = PasswordHash::new(hash).unwrap();

    // 测试不同密码
    for password in &["123456", "admin123", "password", ""] {
        let result = Argon2::default().verify_password(password.as_bytes(), &parsed_hash);
        println!("{}: {:?}", password, result);
    }
}
```

### 4. 检查API路由注册
```bash
grep -r "auth/login" jive-api/src/
```

### 5. 编译状态检查
```bash
# 当前有编译错误
cd jive-api && cargo build 2>&1 | grep error | head -10
```

错误：
- `no method named 'unwrap_or' found for type 'bool'`
- `no method named 'unwrap_or_else' found for struct 'DateTime'`
- 等6个编译错误

这说明代码有问题，但旧的编译版本在运行。

## 建议解决方案

### 方案1: 修复代码并重新编译
1. 修复6个编译错误
2. 重新编译API
3. 重启服务器
4. 测试登录

### 方案2: 使用注册功能创建新用户
```bash
curl -X POST http://localhost:8012/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email": "newuser@test.com", "password": "test123", "name": "New User"}'
```

然后用新创建的用户登录。

### 方案3: 直接更新数据库密码
使用已知的有效hash（从hash_password工具生成）：

```sql
-- hash_password工具生成的hash (密码: admin123)
UPDATE users
SET password_hash = '$argon2id$v=19$m=19456,t=2,p=1$0HV6oKw5rkWLit4w/6wZag$lWDiDJ4V48XRdfob5DvmZT7po1r4pV/QAOzLI3bqefM'
WHERE email = 'superadmin@jive.money';
```

## 当前环境

- **API端口**: 8012 ✅ 运行中
- **Flutter端口**: 3021 ✅ 运行中
- **数据库**: localhost:5433 ✅ 连接正常
- **Redis**: localhost:6379 ✅ 连接正常

## 紧急解决方案

**最快的解决方法**:
1. 停止当前API服务器
2. 修复编译错误
3. 重新编译并启动
4. 测试登录

**临时绕过方法**:
如果代码修复复杂，可以：
1. 创建新用户通过register endpoint
2. 或使用database seed script重置所有用户密码
3. 或checkout到最后一个working commit

## 下一步行动

我建议您：
1. 提供正确的登录密码（如果您知道）
2. 或者让我修复代码编译错误并重启API
3. 或者让我通过register创建新的测试用户
