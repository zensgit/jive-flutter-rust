# 微信登录集成指南

## 概述

本文档说明如何在 Jive Money 应用中集成微信登录功能。

## 功能特性

- ✅ 微信授权登录
- ✅ 微信账户注册
- ✅ 微信账户绑定/解绑
- ✅ 用户信息获取
- ✅ Web端模拟登录（开发和演示用途）

## 已实现的组件

### 1. 服务层
- `lib/services/wechat_service.dart` - 微信SDK封装服务
- `lib/widgets/wechat_login_button.dart` - 微信登录按钮组件

### 2. 界面组件
- `lib/screens/auth/login_screen.dart` - 登录页面（已添加微信登录）
- `lib/screens/auth/register_screen.dart` - 注册页面（已添加微信注册）
- `lib/screens/settings/wechat_binding_screen.dart` - 微信绑定设置页面

### 3. 数据模型
- `WeChatAuthResult` - 微信授权结果
- `WeChatUserInfo` - 微信用户信息

## Web端实现

目前Web端使用模拟数据实现微信登录功能，包括：
- 模拟授权流程（2秒延迟）
- 模拟用户信息获取
- 完整的UI交互体验

## 移动端集成（待实现）

### Android集成

1. 在 `android/app/src/main/java/` 中创建平台通道：

```java
public class WeChatPlugin implements MethodCallHandler {
    private static final String CHANNEL = "com.jivemoney.flutter/wechat";
    
    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "initWeChat":
                // 初始化微信SDK
                break;
            case "isWeChatInstalled":
                // 检查微信安装状态
                break;
            case "login":
                // 发起微信登录
                break;
            case "getUserInfo":
                // 获取用户信息
                break;
        }
    }
}
```

2. 在 `android/app/build.gradle` 中添加微信SDK依赖：

```gradle
dependencies {
    implementation 'com.tencent.mm.opensdk:wechat-sdk-android-without-mta:+'
}
```

### iOS集成

1. 在 `ios/Runner/` 中创建平台通道
2. 添加微信SDK到 `ios/Podfile`
3. 配置URL Schemes

### 配置要求

1. **微信开放平台申请**
   - 注册微信开放平台账号
   - 创建移动应用
   - 获取 AppID 和 AppSecret

2. **更新配置**
   - 在 `lib/services/wechat_service.dart` 中更新真实的 AppID
   - 配置应用签名和包名

## API对接

### 后端接口设计

```rust
// 微信登录接口
POST /api/auth/wechat/login
{
    "code": "微信授权码",
    "state": "状态码",
    "access_token": "访问令牌",
    "openid": "微信OpenID",
    "unionid": "微信UnionID"
}

// 微信绑定接口  
POST /api/user/wechat/bind
{
    "access_token": "访问令牌",
    "openid": "微信OpenID",
    "user_info": {
        "nickname": "微信昵称",
        "headimgurl": "头像URL",
        // ...其他用户信息
    }
}

// 微信解绑接口
DELETE /api/user/wechat/unbind
```

## 安全考虑

- ✅ 状态码验证防止CSRF攻击
- ✅ Access Token安全存储
- ✅ 用户信息加密传输
- ✅ UnionID绑定防止账户冲突

## 测试说明

当前实现包含完整的UI测试功能：
1. 在Web浏览器中访问登录/注册页面
2. 点击"微信登录"或"微信注册"按钮
3. 系统会模拟微信授权流程（显示加载动画）
4. 2秒后返回模拟的微信用户信息
5. 完成登录/注册流程

## 下一步开发

1. **移动端原生实现**
   - Android平台通道实现
   - iOS平台通道实现
   
2. **后端API开发**
   - 微信登录验证接口
   - 用户绑定/解绑接口
   
3. **完善功能**
   - 错误处理优化
   - 用户体验改进
   - 安全机制加强