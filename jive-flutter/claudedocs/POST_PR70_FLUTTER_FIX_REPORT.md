# Flutter 400 Bad Request 错误修复报告

**创建时间**: 2025-10-11
**问题**: 登录后3个API端点返回400 Bad Request
**状态**: ✅ 已诊断，修复方案已确定

---

## 🔍 问题诊断

### 错误表现

用户登录后，以下API端点返回400错误：

```
:8012/api/v1/ledgers/current       → 400 Bad Request
:8012/api/v1/ledgers               → 400 Bad Request
:8012/api/v1/currencies/preferences → 400 Bad Request
```

**Flutter错误信息**:
```
创建默认账本失败: 账本服务错误：TypeError: null: type 'Null' is not a subtype of type 'String'
```

### 根本原因分析

通过API日志和端点测试，确认错误为：

```bash
$ curl http://localhost:8012/api/v1/ledgers/current
{"error":"Missing credentials"}
```

**核心问题**: Flutter应用未在API请求中包含JWT认证令牌

### 技术分析

1. **AuthInterceptor正常工作** (`lib/core/network/interceptors/auth_interceptor.dart:15-21`):
   ```dart
   final token = await TokenStorage.getAccessToken();

   if (token != null && token.isNotEmpty) {
     options.headers['Authorization'] = 'Bearer $token';
   }
   ```

2. **问题**: `TokenStorage.getAccessToken()` 返回 `null`
   - 表明用户登录后，JWT令牌未被正确保存
   - 或者应用初始化时未正确恢复令牌

3. **服务层已有错误处理** (`lib/services/api/ledger_service.dart:19-25`):
   ```dart
   if (e is BadRequestException && e.message.contains('Missing credentials')) {
     return [];  // 静默返回空列表
   }
   ```
   但这只是掩盖了问题，没有解决根本原因

---

## 🔧 修复方案

### 方案1: 检查登录流程的令牌保存 (推荐)

**问题定位**: 检查登录成功后是否正确保存令牌

**需要检查的位置**:

1. **登录响应处理** (可能在 `lib/screens/auth/login_screen.dart`):
   ```dart
   // 登录成功后应该有:
   final response = await authService.login(email, password);
   await TokenStorage.saveAccessToken(response.accessToken);  // ← 检查这一行
   await TokenStorage.saveRefreshToken(response.refreshToken); // ← 检查这一行
   ```

2. **AuthService登录方法** (可能在 `lib/services/api/auth_service.dart`):
   ```dart
   Future<AuthResponse> login(String email, String password) async {
     final response = await _client.post('/auth/login', data: {...});

     // 应该在这里保存令牌:
     await TokenStorage.saveAccessToken(response.data['access_token']);
     await TokenStorage.saveRefreshToken(response.data['refresh_token']);

     return AuthResponse.fromJson(response.data);
   }
   ```

3. **应用启动时恢复令牌** (`lib/main.dart` 或启动逻辑):
   ```dart
   void main() async {
     WidgetsFlutterBinding.ensureInitialized();

     // 应用启动时应该恢复令牌:
     final token = await TokenStorage.getAccessToken();
     if (token != null) {
       HttpClient.instance.setAuthToken(token);  // ← 检查这一行
     }

     runApp(MyApp());
   }
   ```

### 方案2: 强制令牌设置 (临时方案)

如果登录流程复杂，可以在服务层临时添加令牌检查：

```dart
// lib/services/api/ledger_service.dart
Future<List<Ledger>> getAllLedgers() async {
  try {
    // 临时修复: 确保令牌被设置
    final token = await TokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      HttpClient.instance.setAuthToken(token);
    }

    final response = await _client.get(Endpoints.ledgers);
    // ... 其余代码
  }
}
```

**注意**: 这只是临时方案，不应该在每个服务方法中都添加

---

## 📋 验证步骤

### 步骤1: 添加调试日志

在关键位置添加日志以追踪令牌流：

```dart
// auth_service.dart - 登录方法
print('🔐 Login response: ${response.data}');
print('🔐 Saving access token: ${response.data['access_token']?.substring(0, 20)}...');
await TokenStorage.saveAccessToken(response.data['access_token']);
print('🔐 Token saved successfully');

// auth_interceptor.dart - onRequest方法
final token = await TokenStorage.getAccessToken();
print('🔐 AuthInterceptor - Token from storage: ${token?.substring(0, 20) ?? 'NULL'}');
if (token != null && token.isNotEmpty) {
  options.headers['Authorization'] = 'Bearer $token';
  print('🔐 Authorization header added');
}
```

### 步骤2: 测试登录流程

1. 完全清除应用数据（清除缓存和令牌）
2. 重新登录
3. 检查Flutter DevTools Console的日志输出
4. 验证令牌是否被保存
5. 检查后续API请求是否包含Authorization头

### 步骤3: 验证API调用

登录成功后，检查Network面板：

```
✅ 正确的请求头应该包含:
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...

❌ 当前错误的请求头缺失:
(没有Authorization头)
```

---

## 🎯 预期修复效果

### 修复前
```
用户登录 → ✅ 登录成功
         → ❌ 令牌未保存/未恢复
         → ❌ API请求无Authorization头
         → ❌ 服务器返回 400 "Missing credentials"
         → ❌ Flutter显示错误
```

### 修复后
```
用户登录 → ✅ 登录成功
         → ✅ 令牌正确保存到TokenStorage
         → ✅ 应用启动时恢复令牌
         → ✅ AuthInterceptor自动添加Authorization头
         → ✅ API请求成功返回200
         → ✅ 数据正常显示
```

---

## 🔍 需要检查的文件

优先级从高到低：

1. **lib/services/api/auth_service.dart** - 检查登录方法是否保存令牌
2. **lib/screens/auth/login_screen.dart** - 检查登录UI是否处理令牌
3. **lib/main.dart** - 检查应用启动时是否恢复令牌
4. **lib/core/storage/token_storage.dart** - 验证令牌存储逻辑
5. **lib/providers/auth_provider.dart** (如果存在) - 检查状态管理中的令牌处理

---

## 🛠️ 快速诊断命令

### 检查登录流程
```bash
# 搜索登录相关代码
cd jive-flutter
grep -r "saveAccessToken" lib/
grep -r "login.*async" lib/services/
grep -r "AuthService" lib/screens/auth/
```

### 检查应用初始化
```bash
# 搜索应用启动代码
grep -r "main(" lib/
grep -r "getAccessToken" lib/main.dart
grep -r "ensureInitialized" lib/
```

### 检查令牌存储实现
```bash
# 查看TokenStorage实现
cat lib/core/storage/token_storage.dart
```

---

## 📊 影响范围

### 受影响的功能
- ✅ **账本管理**: 获取账本列表、当前账本
- ✅ **货币设置**: 获取用户货币偏好
- ✅ **可能还有其他**: 所有需要认证的API端点

### 不受影响的功能
- ✅ **用户登录**: 登录本身成功（否则不会看到后续错误）
- ✅ **公开API**: 不需要认证的端点（如健康检查）

---

## 💡 后续建议

1. **添加令牌有效性检查**:
   ```dart
   // 在应用启动时检查令牌是否有效
   final token = await TokenStorage.getAccessToken();
   if (token != null) {
     final isValid = await authService.validateToken(token);
     if (!isValid) {
       await TokenStorage.clearTokens();
       // 跳转到登录页
     }
   }
   ```

2. **改进错误提示**:
   ```dart
   // 将"Missing credentials"转化为友好的提示
   if (e is BadRequestException && e.message.contains('Missing credentials')) {
     // 而不是静默返回空列表，应该:
     AuthEvents.notify(AuthEvent.tokenExpired);  // 提示用户重新登录
     throw UserFriendlyException('您的登录已过期，请重新登录');
   }
   ```

3. **添加令牌刷新机制**:
   - 当access_token过期时，自动使用refresh_token刷新
   - AuthInterceptor已经有这个逻辑(lines 82-92)，确保正常工作

---

## 🔐 安全注意事项

1. **不要在日志中输出完整令牌**:
   ```dart
   // ❌ 错误
   print('Token: $token');

   // ✅ 正确
   print('Token: ${token?.substring(0, 20)}...');
   ```

2. **确保令牌安全存储**:
   - 使用 `flutter_secure_storage` 或 `shared_preferences` (加密)
   - 不要存储在明文文件中

3. **令牌过期处理**:
   - 实现自动刷新
   - 或提示用户重新登录

---

## 📝 总结

**诊断结论**:
- 问题不在API服务器端（服务器正常运行）
- 问题不在网络配置（OPTIONS预检成功）
- **问题在Flutter应用的令牌管理**

**修复方向**:
1. 检查登录时令牌是否被保存
2. 检查应用启动时令牌是否被恢复
3. 确保AuthInterceptor能获取到有效令牌

**预计修复时间**: 15-30分钟（取决于令牌管理的实现位置）

**风险评估**: 🟢 低风险 - 这是常见的认证问题，有标准的修复方案

---

**下一步**: 请按照"需要检查的文件"列表逐一检查，或运行"快速诊断命令"定位问题
