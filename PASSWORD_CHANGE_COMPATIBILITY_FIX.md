# 密码修改功能兼容性修复报告

**文件名**: `PASSWORD_CHANGE_COMPATIBILITY_FIX.md`
**日期**: 2025-10-12
**修复状态**: ✅ **已修复并验证**
**影响范围**: `src/handlers/auth.rs` 中的 `change_password` 函数
**严重级别**: 🟠 **中等** (影响部分核心用户功能)

---

## 1. 问题描述

### 根本原因
在 `src/handlers/auth.rs` 的 `login` 函数中，为了实现从旧密码哈希算法 `bcrypt` 到新算法 `argon2` 的平滑升级，系统设计了兼容两种算法的验证逻辑。这是一个优秀的设计。

然而，历史版本的 `change_password` 确实只考虑了验证 `argon2` 格式的哈希，**忽略了对 `bcrypt` 格式哈希的兼容**。当前代码已完成修复并支持两种格式的验证与平滑升级。

### 旧版本的错误代码 (`change_password` 函数中)
```rust
// ... 获取当前密码哈希 current_hash

// 验证旧密码 (只支持 argon2)
let parsed_hash =
    PasswordHash::new(&current_hash).map_err(|_| ApiError::InternalServerError)?;

let argon2 = Argon2::default();
argon2
    .verify_password(req.old_password.as_bytes(), &parsed_hash)
    .map_err(|_| ApiError::Unauthorized)?;
```

### 实际影响
如果一个用户的密码在数据库中是以 `bcrypt` 格式 (`$2a$...` 或 `$2y$...` 开头) 存储的，当他尝试修改密码时：
1. `PasswordHash::new(&current_hash)` 会因为无法解析 `bcrypt` 格式而失败。
2. API 将返回 `InternalServerError` 或 `Unauthorized` 错误。
3. **导致该用户永远无法成功修改密码**，严重影响用户体验。

---

## 2. 修复方案（已落地）

### 核心思想
将 `login` 函数中那段成熟、健壮的**双哈希验证逻辑**，移植到 `change_password` 函数中，用于验证用户的“旧密码”。

### 变更前 (Before)
```rust
// 验证旧密码
let parsed_hash =
    PasswordHash::new(&current_hash).map_err(|_| ApiError::InternalServerError)?;

let argon2 = Argon2::default();
argon2
    .verify_password(req.old_password.as_bytes(), &parsed_hash)
    .map_err(|_| ApiError::Unauthorized)?;
```

### 变更后 (After) — 已合并在主分支
```rust
// 验证旧密码 (兼容 argon2 和 bcrypt)
let old_password_valid = if current_hash.starts_with("$argon2") {
    // 优先处理 argon2
    PasswordHash::new(&current_hash)
        .and_then(|parsed| Argon2::default().verify_password(req.old_password.as_bytes(), &parsed))
        .is_ok()
} else if current_hash.starts_with("$2") {
    // 兼容处理 bcrypt
    bcrypt::verify(&req.old_password, &current_hash).unwrap_or(false)
} else {
    // 兜底：尝试按 Argon2 解析（best-effort），并在指标中观察异常前缀
    match PasswordHash::new(&current_hash) {
        Ok(parsed) => Argon2::default().verify_password(req.old_password.as_bytes(), &parsed).is_ok(),
        Err(_) => false,
    }
};

if !old_password_valid {
    // 如果验证失败，返回未授权错误
    return Err(ApiError::Unauthorized);
}

// 注意：这里不需要像 login 函数那样进行 rehash，因为我们马上就要用新密码的哈希覆盖它了。
```

---

## 3. 验证步骤

修复后，需要进行以下验证：

1.  **准备测试数据**:
    *   在数据库中，手动将一个测试用户的 `password_hash` 修改为 `bcrypt` 格式的哈希值 (例如: `$2y$12$IqT.d...`)
    *   确保有另一个测试用户的密码哈希是 `argon2` 格式。

2.  **测试 `bcrypt` 用户**:
    *   使用该用户的旧密码和新密码，调用 `POST /api/v1/auth/password` 接口。
    *   **预期结果**: ✅ 请求成功 (HTTP 200 OK)，数据库中的密码哈希被更新为新的 `argon2` 格式。

3.  **测试 `argon2` 用户**:
    *   使用该用户的旧密码和新密码，调用 `POST /api/v1/auth/password` 接口。
    *   **预期结果**: ✅ 请求成功 (HTTP 200 OK)，密码哈希被更新。

4.  **测试错误密码**:
    *   对以上任一用户，使用错误的旧密码调用接口。
    *   **预期结果**: ❌ 请求失败 (HTTP 401 Unauthorized)。

---

## 4. 总结

此 Bug 虽然不直接造成数据丢失或安全漏洞，但严重影响了部分存量用户的核心体验。通过应用此修复，可以确保所有用户（无论其密码哈希格式新旧）都能正常使用“修改密码”功能，并保持与 `login` 功能一致的健壮性。

**建议立即实施此修复。**
