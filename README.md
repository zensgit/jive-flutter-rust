# Jive Money - 集腋记账

一个全功能的个人财务管理系统，采用 Flutter 前端和 Rust 后端架构。

> **集腋成裘，细水长流** - 用心记录每一笔收支，积小成大，理财从记账开始。

## 🚀 快速启动

### 方法 1: 使用智能启动脚本（推荐）

```bash
# 赋予执行权限
chmod +x start.sh

# 交互式启动
./start.sh

# 或直接启动所有服务
./start.sh start
```

启动脚本功能：
- ✅ 自动检查所有依赖（Rust、Flutter、数据库）
- ✅ 检测端口占用并提供处理选项
- ✅ 支持多平台运行（Web、iOS、Android、桌面）
- ✅ 开发模式热重载
- ✅ 服务状态监控
- ✅ 日志查看

### 方法 2: 使用 Make 命令

```bash
# 安装依赖
make install

# 检查环境
make check

# 启动服务
make start

# 开发模式
make dev

# 查看更多命令
make help
```

### 方法 3: 使用 Docker Compose

```bash
# 启动所有服务
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down
```

## 📋 系统要求

### 必需依赖
- **Rust**: 1.75+
- **Flutter**: 3.16+
- **PostgreSQL**: 14+

### 可选依赖
- **Redis**: 用于缓存和会话管理
- **Docker**: 容器化部署
- **Make**: 简化命令操作

## 🔧 配置

1. 复制环境配置文件：
```bash
cp .env.example .env
```

2. 根据需要修改 `.env` 文件中的配置

## 🏗️ 项目结构

```
jive-flutter-rust/
├── jive-core/          # Rust 后端
│   ├── src/
│   │   ├── domain/     # 领域模型
│   │   └── application/ # 业务逻辑
│   └── Cargo.toml
├── jive-flutter/       # Flutter 前端
│   ├── lib/
│   └── pubspec.yaml
├── start.sh           # 智能启动脚本
├── docker-compose.yml # Docker 配置
├── Makefile          # Make 命令
└── .env.example      # 环境配置模板
```

## ✨ 功能特性

### 核心功能
- 🏠 **Family 多用户协作**: 基于家庭的财务管理，支持多角色权限
- 🔐 **MFA 多因素认证**: TOTP 双因素认证，增强账户安全
- 💳 **信用卡管理**: 账单周期、还款提醒、多币种支持
- 📊 **智能分析报表**: 收支分析、预算跟踪、趋势预测
- 📱 **快速记账**: 智能分类、商户识别、语音输入
- 🤖 **规则引擎**: 自动分类、批量处理、智能提醒
- 💼 **投资组合**: 持仓管理、收益计算、风险分析
- 🔔 **通知系统**: 多渠道通知、个性化设置、成就系统

### 中国本地化
- 支持支付宝、微信支付数据导入
- 中国银行信用卡账单支持
- 微信通知渠道
- 人民币优先显示

## 🛠️ 开发命令

```bash
# 运行测试
make test

# 代码格式化
make format

# 代码检查
make lint

# 清理构建文件
make clean

# 数据库迁移
make db-migrate

# 查看日志
make logs
```

## 📱 支持平台

- ✅ Web (Chrome, Firefox, Safari)
- ✅ iOS (10.0+)
- ✅ Android (API 21+)
- ✅ macOS (10.14+)
- ✅ Linux (Ubuntu 18.04+)
- ✅ Windows (10+)

## 🔍 故障排查

### 端口被占用
启动脚本会自动检测并提示处理，或手动修改 `.env` 文件中的端口配置。

### 依赖安装失败
- Rust: 访问 https://rustup.rs/
- Flutter: 访问 https://flutter.dev/docs/get-started/install
- PostgreSQL: 使用系统包管理器安装

### 查看详细日志
```bash
# 查看所有日志
tail -f logs/*.log

# 查看特定服务日志
tail -f logs/rust_server.log
tail -f logs/flutter_web.log
```

## 📄 许可证

MIT License

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

## 📞 联系

如有问题，请提交 Issue 或联系维护者。