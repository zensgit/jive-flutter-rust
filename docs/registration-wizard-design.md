# 注册向导功能设计文档

## 概述
Jive Money 采用三步式注册向导（Registration Wizard），提供渐进式的用户注册体验，让新用户能够快速设置账户并个性化配置偏好。

## 文件位置
- **主文件**: `/jive-flutter/lib/screens/auth/registration_wizard.dart`
- **路由配置**: `/jive-flutter/lib/core/router/app_router.dart` (路径: `/register-wizard`)
- **API端点**: `/auth/register-enhanced`

## 注册流程架构

### 步骤概览
```
步骤1: 账户信息 → 步骤2: 个人资料 → 步骤3: 偏好设置 → 完成注册
```

## 详细功能设计

### 步骤1: 账户信息 (Account Info)

#### 功能描述
收集用户的基本账户信息，确保账户安全性。

#### 界面元素
| 字段 | 类型 | 验证规则 | 必填 |
|------|------|----------|------|
| 用户名 | 文本输入框 | 最少3个字符 | ✅ |
| 邮箱地址 | 邮箱输入框 | 有效邮箱格式 | ✅ |
| 密码 | 密码输入框 | 见密码强度要求 | ✅ |
| 确认密码 | 密码输入框 | 必须与密码一致 | ✅ |
| 用户协议 | 复选框 | 必须勾选 | ✅ |

#### 密码强度要求
- ✅ 至少8个字符
- ✅ 包含大小写字母
- ✅ 包含数字
- ✅ 包含特殊字符

#### 特性
- **实时密码强度检测**: 4个进度条显示各项要求满足情况
- **密码可见性切换**: 眼睛图标切换密码显示/隐藏
- **实时验证反馈**: 输入时即时验证并显示错误信息

### 步骤2: 个人资料设置 (Profile Setup)

#### 功能描述
允许用户上传头像，建立个人身份标识。

#### 界面元素
| 字段 | 类型 | 规格要求 | 必填 |
|------|------|----------|------|
| 头像 | 图片选择器 | JPG/PNG, 最大5MB | ❌ |

#### 特性
- **圆形头像预览**: 150x150像素的圆形展示区
- **图片选择**: 从相册选择图片
- **自动裁剪**: 512x512像素，85%质量压缩
- **可选设置**: 用户可跳过此步骤

### 步骤3: 偏好设置 (Preferences)

#### 功能描述
配置地区、货币、语言等个性化设置，支持全球化使用需求。

#### 界面元素
| 字段 | 类型 | 自动调整 | 手动修改 | 说明 |
|------|------|---------|----------|------|
| 国家/地区 | 下拉选择 | - | ✅ | 80+国家选项 |
| 货币 | 下拉选择 | ✅ | ✅ | 根据国家自动设置，可手动更改 |
| 语言 | 下拉选择 | ✅ | ✅ | 根据国家自动设置，可手动更改 |
| 时区 | 下拉选择 | ✅ | ✅ | 根据国家自动设置，可手动更改 |
| 日期格式 | 下拉选择 | ✅ | ✅ | 根据国家自动设置，可手动更改 |

#### 实时预览卡片
显示示例账户余额，根据用户选择的偏好实时更新显示格式：
- 货币符号和金额格式
- 日期显示格式
- 数字分隔符

#### 自动调整逻辑
当用户选择国家/地区时，系统自动设置相应的默认值：

##### 亚太地区
| 国家/地区 | 货币 | 语言 | 时区 | 日期格式 |
|-----------|------|------|------|----------|
| 中国 (CN) | CNY | zh-CN | Asia/Shanghai | YYYY-MM-DD |
| 台湾 (TW) | TWD | zh-TW | Asia/Taipei | YYYY-MM-DD |
| 香港 (HK) | HKD | zh-HK | Asia/Hong_Kong | DD/MM/YYYY |
| 澳门 (MO) | MOP | zh-MO | Asia/Macau | DD/MM/YYYY |
| 新加坡 (SG) | SGD | en-SG | Asia/Singapore | DD/MM/YYYY |
| 马来西亚 (MY) | MYR | ms-MY | Asia/Kuala_Lumpur | DD/MM/YYYY |
| 印度 (IN) | INR | en-IN | Asia/Kolkata | DD/MM/YYYY |
| 印尼 (ID) | IDR | id-ID | Asia/Jakarta | DD/MM/YYYY |
| 泰国 (TH) | THB | th-TH | Asia/Bangkok | DD/MM/YYYY |
| 越南 (VN) | VND | vi-VN | Asia/Ho_Chi_Minh | DD/MM/YYYY |
| 菲律宾 (PH) | PHP | en-PH | Asia/Manila | MM/DD/YYYY |
| 日本 (JP) | JPY | ja-JP | Asia/Tokyo | YYYY-MM-DD |
| 韩国 (KR) | KRW | ko-KR | Asia/Seoul | YYYY-MM-DD |

##### 其他地区
- **欧洲**: 30+国家，多数使用EUR，日期格式DD/MM/YYYY或DD.MM.YYYY
- **北美**: 美国(USD)、加拿大(CAD)、墨西哥(MXN)
- **南美**: 巴西(BRL)、阿根廷(ARS)、智利(CLP)等
- **中东**: 阿联酋(AED)、沙特(SAR)、以色列(ILS)等
- **非洲**: 南非(ZAR)、埃及(EGP)、尼日利亚(NGN)等

### 时区选择选项
系统提供50+常用时区，按地区分组：
- **东亚**: 中国、香港、台湾、日本、韩国
- **东南亚**: 新加坡、吉隆坡、雅加达、曼谷、胡志明市、马尼拉
- **南亚**: 加尔各答、达卡、卡拉奇
- **中东**: 迪拜、利雅得、耶路撒冷、伊斯坦布尔
- **欧洲**: 伦敦、巴黎、柏林、马德里、罗马、阿姆斯特丹、苏黎世、斯德哥尔摩、莫斯科
- **大洋洲**: 悉尼、墨尔本、珀斯、奥克兰
- **北美**: 纽约、芝加哥、丹佛、洛杉矶、多伦多、温哥华、墨西哥城
- **南美**: 圣保罗、布宜诺斯艾利斯、圣地亚哥、利马
- **非洲**: 开罗、约翰内斯堡、拉各斯、内罗毕

## 技术实现

### 状态管理
```dart
// 步骤1状态
bool _isPasswordVisible = false;
bool _agreeToTerms = false;
bool _hasMinLength = false;
bool _hasUpperLower = false;
bool _hasNumber = false;
bool _hasSpecialChar = false;

// 步骤2状态  
File? _profileImage;

// 步骤3状态
String _selectedCountry = 'CN';
String _selectedCurrency = 'CNY';
String _selectedLanguage = 'zh-CN';
String _selectedTimezone = 'Asia/Shanghai';
String _selectedDateFormat = 'YYYY-MM-DD';
```

### API集成
注册时调用增强版API端点：
```dart
POST /auth/register-enhanced
{
  "name": "用户名",
  "email": "邮箱",
  "password": "密码",
  "country": "国家代码",
  "currency": "货币代码",
  "language": "语言代码",
  "timezone": "时区",
  "date_format": "日期格式"
}
```

### 数据持久化
注册成功后：
1. 保存JWT Token
2. 保存用户ID
3. 偏好设置存储到 `user_currency_settings` 表
4. 如有头像，异步上传到服务器

## 用户体验优化

### 进度指示
- 页面顶部显示3段进度条
- 当前步骤高亮显示
- 完成的步骤标记为已完成

### 导航控制
- **上一步**: 返回前一个步骤（步骤2、3可用）
- **下一步/完成注册**: 验证当前步骤后前进
- 使用 `PageView` 实现平滑切换动画

### 错误处理
- 实时表单验证
- 清晰的错误提示信息
- 注册失败时显示具体错误原因
- 网络错误时的重试机制

### 响应式设计
- 适配不同屏幕尺寸
- 键盘弹出时自动滚动
- 长列表内容使用 `SingleChildScrollView`

## 安全考虑

1. **密码安全**
   - 强密码要求
   - 密码加密传输
   - 确认密码防止输入错误

2. **数据验证**
   - 前端实时验证
   - 后端二次验证
   - SQL注入防护

3. **隐私保护**
   - 用户协议确认
   - 敏感信息加密存储
   - HTTPS传输

## 后续优化建议

1. **功能增强**
   - 添加社交账号登录（Google、Apple ID）
   - 支持邮箱验证码
   - 添加更多国家和时区选项
   - 支持深色/浅色主题选择

2. **用户体验**
   - 添加跳过按钮（步骤2）
   - 记住上次选择的国家
   - 智能推荐基于IP地址
   - 添加帮助提示

3. **性能优化**
   - 懒加载国家/货币数据
   - 图片压缩优化
   - 缓存用户偏好

## 相关文档
- [多币种功能设计](./multi-currency-design.md)
- [用户认证流程](./auth-flow.md)
- [API接口文档](./api-documentation.md)