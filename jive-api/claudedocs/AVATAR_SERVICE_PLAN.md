# Jive Money 头像服务方案说明

**文档版本**: 1.0
**创建日期**: 2025-10-09
**最后更新**: 2025-10-09

---

## 📋 目录

1. [当前方案](#当前方案)
2. [版权合规性](#版权合规性)
3. [头像选项详情](#头像选项详情)
4. [自建DiceBear方案](#自建dicebear方案)
5. [成本对比分析](#成本对比分析)
6. [迁移指南](#迁移指南)
7. [常见问题](#常见问题)

---

## 当前方案

### 架构概述

```
用户浏览器
    ↓
Flutter Web App (localhost:3021)
    ↓
头像来源（三种方式）：
    1. 本地上传图片 → Jive API (localhost:18012)
    2. 系统内置头像 → Flutter Assets (24个emoji图标)
    3. 网络头像 → 外部API:
        - DiceBear API (api.dicebear.com) - 44个
        - RoboHash API (robohash.org) - 6个
```

### 当前头像数量

- **系统内置头像**: 24个（emoji表情图标）
- **网络头像**: 50个
  - DiceBear v7 API: 44个（10种风格）
  - RoboHash: 6个（机器人和动物）

### 代码位置

**主文件**: `jive-flutter/lib/screens/settings/profile_settings_screen.dart`

- **Line 30-96**: 网络头像配置（`_networkAvatars` 列表）
- **Line 99-124**: 系统头像配置（`_systemAvatars` 列表）
- **Line 853-860**: 版权署名提示
- **Line 424-463**: 网络图片错误处理

**设置页面**: `jive-flutter/lib/screens/settings/settings_screen.dart`

- **Line 494-543**: "关于"对话框中的完整版权署名

---

## 版权合规性

### DiceBear API

**代码许可**: MIT License (可商用)
**官方托管API限制**: 仅限非商业用途
**官方文档**: https://www.dicebear.com/licenses

#### 各风格许可

| 风格 | 许可 | 商业使用 |
|------|------|----------|
| Avataaars | Free for personal and commercial use | ✅ |
| Bottts | MIT License | ✅ |
| Micah | MIT License | ✅ |
| Adventurer | MIT License | ✅ |
| Lorelei | MIT License | ✅ |
| Personas | MIT License | ✅ |
| Pixel Art | MIT License | ✅ |
| Fun Emoji | MIT License | ✅ |
| Big Smile | MIT License | ✅ |
| Identicon | MIT License | ✅ |

**注意**: 虽然风格许可允许商业使用，但**官方托管API**要求非商业用途。商业项目需要自建实例。

### RoboHash

**代码许可**: MIT License (可商用)
**图像许可**: Creative Commons (CC-BY-3.0/4.0)
**官方网站**: https://robohash.org

#### 各Set许可

| Set | 内容 | 作者 | 许可 |
|-----|------|------|------|
| Set 1 | 机器人 | Zikri Kader | CC-BY-3.0/4.0 |
| Set 2 | 怪物 | Hrvoje Novakovic | CC-BY-3.0 |
| Set 3 | - | Julian Peter Arias | CC-BY-3.0 |
| Set 4 | 猫 | David Revoy | CC-BY-4.0 |

**CC-BY要求**: 必须提供署名（Attribution）

### 当前署名实现

✅ **已完成** - 符合CC-BY许可要求

**位置1**: 个人资料设置页面底部
```
网络头像由 DiceBear 和 RoboHash 提供 · 查看"关于"了解许可
```

**位置2**: 设置 → 关于 Jive Money 对话框
```
第三方服务
头像服务：
• DiceBear - MIT License
  https://dicebear.com
• RoboHash - CC-BY License
  https://robohash.org
  由 Zikri Kader, Hrvoje Novakovic,
  Julian Peter Arias, David Revoy 等创作
```

---

## 头像选项详情

### 网络头像（50个）

#### DiceBear v7 API - 44个

**1. Avataaars 风格（卡通人物）- 8个**
```dart
{'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Felix', 'name': 'Felix'},
{'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Aneka', 'name': 'Aneka'},
{'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sarah', 'name': 'Sarah'},
{'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=John', 'name': 'John'},
{'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Emma', 'name': 'Emma'},
{'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Oliver', 'name': 'Oliver'},
{'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Sophia', 'name': 'Sophia'},
{'url': 'https://api.dicebear.com/7.x/avataaars/svg?seed=Liam', 'name': 'Liam'},
```

**2. Bottts 风格（机器人）- 5个**
```dart
Bot1, Bot2, Bot3, Bot4, Bot5
```

**3. Micah 风格（抽象人物）- 4个**
```dart
Person1, Person2, Person3, Person4
```

**4. Adventurer 风格（冒险者）- 5个**
```dart
Alex, Sam, Jordan, Taylor, Casey
```

**5. Lorelei 风格（现代人物）- 4个**
```dart
Luna, Nova, Zara, Maya
```

**6. Personas 风格（简约人物）- 4个**
```dart
Persona 1, Persona 2, Persona 3, Persona 4
```

**7. Pixel Art 风格（像素风）- 4个**
```dart
Pixel 1, Pixel 2, Pixel 3, Pixel 4
```

**8. Fun Emoji 风格（趣味表情）- 4个**
```dart
Happy, Cool, Smile, Wink
```

**9. Big Smile 风格（大笑脸）- 3个**
```dart
Joy 1, Joy 2, Joy 3
```

**10. Identicon 风格（几何图案）- 3个**
```dart
Geo 1, Geo 2, Geo 3
```

#### RoboHash - 6个

```dart
{'url': 'https://robohash.org/user1?set=set1', 'name': 'Robo 1'},
{'url': 'https://robohash.org/user2?set=set2', 'name': 'Robo 2'},
{'url': 'https://robohash.org/user3?set=set3', 'name': 'Robo 3'},
{'url': 'https://robohash.org/cat1?set=set4', 'name': 'Cat 1'},
{'url': 'https://robohash.org/cat2?set=set4', 'name': 'Cat 2'},
{'url': 'https://robohash.org/monster1?set=set2', 'name': 'Monster'},
```

### 系统头像（24个）

内置emoji表情图标，无需网络请求：
- 动物系列：🐶🐱🐼🐰🐻🦊🐸🐷
- 表情系列：😀😎😍🤗🤔😴😇🥳
- 其他系列：🌟⭐🎈🎨🎭🎪🎸🎮

---

## 自建DiceBear方案

### 为什么需要自建？

**官方API限制**:
- ⚠️ 仅限非商业用途
- ⚠️ 请求速率限制
- ⚠️ 依赖第三方服务可用性
- ⚠️ 中国大陆访问速度可能较慢

**自建优势**:
- ✅ 可商业使用（MIT许可）
- ✅ 无请求限制
- ✅ 完全控制服务
- ✅ 更快响应速度（服务器在国内）
- ✅ 数据隐私保护

### 部署方案

#### 方案1: Docker Compose（推荐）

**1. 创建配置文件**

在 `jive-api/docker-compose.dev.yml` 中添加：

```yaml
services:
  # ... 现有服务 ...

  dicebear:
    image: dicebear/api:3
    container_name: jive-dicebear
    restart: always
    ports:
      - "13000:3000"  # 避免与现有服务冲突
    tmpfs:
      - '/run'
      - '/tmp'
    networks:
      - jive-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

**2. 启动服务**

```bash
cd jive-api
docker-compose -f docker-compose.dev.yml up -d dicebear
```

**3. 验证服务**

```bash
# 测试头像生成
curl http://localhost:13000/7.x/avataaars/svg?seed=Felix

# 应该返回SVG图像数据
```

#### 方案2: 独立Docker运行

```bash
docker run -d \
  --name jive-dicebear \
  --tmpfs /run \
  --tmpfs /tmp \
  -p 13000:3000 \
  --restart always \
  dicebear/api:3
```

#### 方案3: Node.js原生运行

```bash
# 克隆仓库
git clone https://github.com/dicebear/api.git dicebear-api
cd dicebear-api

# 安装依赖
npm install

# 构建
npm run build

# 启动（默认端口3000）
npm start
```

### 代码集成

#### 步骤1: 创建配置文件

**文件**: `jive-flutter/lib/config/avatar_config.dart`

```dart
/// 头像服务配置
class AvatarConfig {
  // DiceBear API 基础URL
  static const String dicebearBaseUrl = String.fromEnvironment(
    'DICEBEAR_URL',
    defaultValue: 'https://api.dicebear.com', // 默认使用官方API
  );

  // RoboHash API（无需自建）
  static const String robohashBaseUrl = 'https://robohash.org';

  // 获取DiceBear头像URL
  static String getDiceBearUrl(String style, String seed) {
    return '$dicebearBaseUrl/7.x/$style/svg?seed=$seed';
  }

  // 获取RoboHash头像URL
  static String getRobohashUrl(String seed, String set) {
    return '$robohashBaseUrl/$seed?set=$set';
  }
}
```

#### 步骤2: 修改头像配置

**文件**: `jive-flutter/lib/screens/settings/profile_settings_screen.dart`

```dart
import 'package:jive_money/config/avatar_config.dart';

// 修改网络头像列表（Line 30-96）
final List<Map<String, dynamic>> _networkAvatars = [
  // DiceBear v7 API - Avataaars 风格
  {
    'url': AvatarConfig.getDiceBearUrl('avataaars', 'Felix'),
    'name': 'Felix'
  },
  {
    'url': AvatarConfig.getDiceBearUrl('avataaars', 'Aneka'),
    'name': 'Aneka'
  },
  // ... 其他头像 ...

  // RoboHash
  {
    'url': AvatarConfig.getRobohashUrl('user1', 'set1'),
    'name': 'Robo 1'
  },
  // ... 其他头像 ...
];
```

#### 步骤3: 环境变量配置

**开发环境（使用官方API）**:
```bash
flutter run -d web-server --web-port 3021
# 默认使用官方API: api.dicebear.com
```

**生产环境（使用自建实例）**:
```bash
# 本地自建实例
flutter run -d web-server --web-port 3021 \
  --dart-define=DICEBEAR_URL=http://localhost:13000

# 生产服务器
flutter build web --dart-define=DICEBEAR_URL=https://avatars.your-domain.com
```

### Nginx反向代理（生产环境）

如果使用域名访问自建实例：

```nginx
# /etc/nginx/sites-available/avatars.your-domain.com

server {
    listen 80;
    server_name avatars.your-domain.com;

    location / {
        proxy_pass http://localhost:13000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_cache_valid 200 24h;  # 缓存头像24小时
    }
}
```

启用HTTPS（使用Let's Encrypt）:
```bash
sudo certbot --nginx -d avatars.your-domain.com
```

---

## 成本对比分析

### 方案对比

| 项目 | 官方API | 自建实例 | 说明 |
|------|---------|---------|------|
| **服务器成本** | 免费 | $5-10/月 | VPS服务器 |
| **域名成本** | 无 | $10-15/年 | 可选 |
| **开发时间** | 0小时 | 2-4小时 | 初始设置 |
| **维护时间** | 0小时 | 1小时/年 | 几乎免维护 |
| **请求限制** | 有限制 | 无限制 | - |
| **响应速度** | 较慢（国外） | 快（国内） | - |
| **商业使用** | ❌ 不可 | ✅ 可以 | MIT许可 |
| **数据隐私** | ⚠️ 第三方 | ✅ 自控 | - |

### VPS服务商推荐

**国际服务商**:
- DigitalOcean: $6/月（1GB RAM）
- Vultr: $5/月（1GB RAM）
- Linode: $5/月（1GB RAM）

**国内服务商**（更快速度）:
- 阿里云ECS: ¥30-50/月
- 腾讯云CVM: ¥30-50/月
- 华为云ECS: ¥30-50/月

### 资源占用

**DiceBear API服务**:
- 内存: ~100-200MB
- CPU: 低（按需）
- 磁盘: ~50MB
- 网络: 低（SVG文件很小）

**可与现有服务共用服务器**，无需单独VPS。

---

## 迁移指南

### 时间规划

**阶段1: 开发/测试（当前）**
- ✅ 使用官方API
- ✅ 已添加版权署名
- ⏱️ 持续时间：开发阶段

**阶段2: 预发布准备（商业化前1-2周）**
- 🔄 部署自建实例
- 🔄 代码集成测试
- 🔄 性能验证
- ⏱️ 持续时间：2-4小时

**阶段3: 正式发布**
- 🚀 切换到自建实例
- 🚀 监控服务状态
- ⏱️ 持续时间：持续

### 迁移步骤

#### 准备阶段

**1. 服务器准备**
```bash
# SSH登录服务器
ssh user@your-server.com

# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# 安装Docker Compose
sudo apt install docker-compose -y
```

**2. 部署DiceBear**
```bash
# 创建目录
mkdir -p ~/jive-dicebear
cd ~/jive-dicebear

# 创建docker-compose.yml
cat > docker-compose.yml <<EOF
version: '3.8'
services:
  dicebear:
    image: dicebear/api:3
    restart: always
    ports:
      - "3000:3000"
    tmpfs:
      - '/run'
      - '/tmp'
EOF

# 启动服务
docker-compose up -d

# 验证
curl http://localhost:3000/7.x/avataaars/svg?seed=test
```

#### 代码修改

**1. 添加配置文件**（如上"代码集成"部分）

**2. 测试本地自建实例**
```bash
cd jive-flutter
flutter run -d web-server --web-port 3021 \
  --dart-define=DICEBEAR_URL=http://your-server-ip:3000
```

**3. 验证所有头像正常加载**

#### 部署阶段

**1. 配置域名（可选但推荐）**
```bash
# 安装Nginx
sudo apt install nginx -y

# 配置反向代理（如上"Nginx反向代理"部分）

# 配置SSL
sudo apt install certbot python3-certbot-nginx -y
sudo certbot --nginx -d avatars.your-domain.com
```

**2. 构建生产版本**
```bash
cd jive-flutter
flutter build web \
  --dart-define=DICEBEAR_URL=https://avatars.your-domain.com
```

**3. 部署到生产环境**

#### 验证阶段

**性能测试**:
```bash
# 测试响应时间
time curl -o /dev/null -s http://avatars.your-domain.com/7.x/avataaars/svg?seed=test

# 压力测试（可选）
ab -n 1000 -c 10 http://avatars.your-domain.com/7.x/avataaars/svg?seed=test
```

**功能测试**:
- [ ] 所有10种DiceBear风格正常显示
- [ ] 不同seed生成不同头像
- [ ] 图片加载错误处理正常
- [ ] 响应时间可接受（<500ms）

### 回滚方案

**如果自建实例出现问题**:

```dart
// 方法1: 环境变量回滚
// 重新部署时不传DICEBEAR_URL，自动使用官方API

// 方法2: 代码回滚
// 在 avatar_config.dart 中修改defaultValue
static const String dicebearBaseUrl = String.fromEnvironment(
  'DICEBEAR_URL',
  defaultValue: 'https://api.dicebear.com', // 回滚到官方API
);
```

---

## 常见问题

### Q1: 当前方案是否合法？

**A**: 是的，完全合法。
- ✅ 开发/测试阶段可免费使用官方API
- ✅ 已按CC-BY要求添加版权署名
- ⚠️ 商业发布时需要切换到自建实例

### Q2: 什么时候需要自建DiceBear？

**A**: 以下情况建议自建：
- 📱 应用正式商业发布
- 📈 日活用户超过1000（请求量大）
- 🚀 需要更快的响应速度
- 🔒 对数据隐私有要求

### Q3: 自建实例的维护工作量大吗？

**A**: 维护量很小。
- DiceBear API是无状态服务
- Docker自动重启
- 几乎不需要更新（稳定版本）
- 预计每年<1小时维护时间

### Q4: RoboHash需要自建吗？

**A**: 不需要。
- RoboHash允许商业使用（CC-BY许可）
- 已添加署名，符合许可要求
- 服务稳定，无需自建

### Q5: 能否同时使用官方API和自建实例？

**A**: 可以，通过环境变量切换。
```dart
// 开发环境 → 官方API
flutter run

// 生产环境 → 自建实例
flutter run --dart-define=DICEBEAR_URL=https://avatars.your-domain.com
```

### Q6: 头像数据存储在哪里？

**A**:
- 系统头像：Flutter assets（打包在应用内）
- 网络头像：SVG生成服务（无需存储）
- 用户上传：Jive API服务器（数据库）

### Q7: SVG格式有什么优势？

**A**:
- ✅ 矢量格式，任意缩放不失真
- ✅ 文件小（通常<5KB）
- ✅ 支持CSS样式修改
- ✅ 浏览器原生支持

### Q8: 如何添加更多头像风格？

**A**:
1. 访问 https://www.dicebear.com/styles
2. 选择喜欢的风格（如`initials`, `shapes`等）
3. 在 `profile_settings_screen.dart` 添加配置：
```dart
{
  'url': AvatarConfig.getDiceBearUrl('initials', 'AB'),
  'name': 'Initials AB'
},
```

### Q9: 自建实例支持哪些DiceBear版本？

**A**: Docker镜像 `dicebear/api:3` 支持：
- DiceBear v5, v6, v7, v8, v9
- 当前使用v7（最新稳定版）

### Q10: 如何监控自建实例运行状态？

**A**:
```bash
# Docker日志
docker logs jive-dicebear

# 健康检查
curl http://localhost:3000/health

# 资源占用
docker stats jive-dicebear
```

---

## 附录

### 相关链接

**官方文档**:
- DiceBear官网: https://www.dicebear.com
- DiceBear GitHub: https://github.com/dicebear/dicebear
- DiceBear自建指南: https://www.dicebear.com/guides/host-the-http-api-yourself/
- RoboHash官网: https://robohash.org
- RoboHash GitHub: https://github.com/e1ven/Robohash

**许可证文本**:
- MIT License: https://opensource.org/licenses/MIT
- CC-BY-3.0: https://creativecommons.org/licenses/by/3.0/
- CC-BY-4.0: https://creativecommons.org/licenses/by/4.0/

### 修改历史

| 日期 | 版本 | 修改内容 | 修改人 |
|------|------|---------|--------|
| 2025-10-09 | 1.0 | 创建文档，记录当前方案和自建方案 | Claude Code |

### 代码文件清单

```
jive-flutter/
├── lib/
│   ├── screens/
│   │   └── settings/
│   │       ├── profile_settings_screen.dart  # 头像选择界面
│   │       └── settings_screen.dart          # 版权署名
│   └── config/
│       └── avatar_config.dart                # 配置文件（待创建）
│
jive-api/
├── docker-compose.dev.yml                    # Docker配置（待添加）
└── claudedocs/
    └── AVATAR_SERVICE_PLAN.md                # 本文档
```

---

## 结论

**当前阶段建议**：
- ✅ 继续使用官方API进行开发
- ✅ 已完成版权署名，符合许可要求
- ✅ 提供50种网络头像选择，满足用户需求

**商业化准备**：
- 📅 在正式发布前1-2周部署自建DiceBear实例
- ⏱️ 预计工作量：2-4小时
- 💰 运营成本：$5-10/月（可与现有服务器共用）
- 🔄 迁移风险：低（已准备回滚方案）

**文档维护**：
- 📝 本文档将随项目进展更新
- 🔗 欢迎补充常见问题和最佳实践
