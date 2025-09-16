# Jive Money 服务管理指南

## 📋 目录
- [快速开始](#快速开始)
- [管理脚本介绍](#管理脚本介绍)
- [基本命令](#基本命令)
- [高级功能](#高级功能)
- [故障排除](#故障排除)
- [系统服务配置](#系统服务配置)

## 🚀 快速开始

### 最简单的方式启动所有服务
```bash
./jive start
```

### 查看服务状态
```bash
./jive status
```

### 停止所有服务
```bash
./jive stop
```

## 📁 管理脚本介绍

项目提供了多个管理脚本，适用于不同场景：

| 脚本 | 用途 | 特点 |
|------|------|------|
| `jive-manager.sh` | 完整服务管理器 | 功能最全，支持单个服务管理 |
| `jive` | 快捷命令 | jive-manager.sh 的别名 |
| `start-unified.sh` | 统一启动脚本 | 自动适配系统，一键启动 |
| `.jive-config` | 配置文件 | 端口和参数配置 |

## 🎮 基本命令

### 使用 jive-manager.sh (或简写 jive)

#### 服务控制
```bash
# 启动服务
./jive start          # 启动所有服务
./jive start api      # 只启动 API
./jive start web      # 只启动 Web
./jive start db       # 只启动数据库
./jive start redis    # 只启动 Redis

# 停止服务
./jive stop           # 停止所有服务
./jive stop api       # 只停止 API
./jive stop web       # 只停止 Web

# 重启服务
./jive restart        # 重启所有服务
./jive restart api    # 只重启 API
```

#### 状态和日志
```bash
# 查看状态
./jive status         # 显示所有服务状态

# 查看日志
./jive logs           # 查看所有日志
./jive logs api       # 只看 API 日志
./jive logs web       # 只看 Web 日志
./jive logs docker    # 查看 Docker 服务日志
```

## 🐳 Docker 数据库 + 本地 API（推荐开发流）

当你希望在 Docker 中运行数据库/Redis，而在本机直接运行 Rust API 与 Flutter Web，可使用以下流程：

- 启动 Docker 上的数据库与 Redis
  - `./jive start db`
  - `./jive start redis`
  - 默认数据库监听 `localhost:5433`，用户/密码：`postgres/postgres`，库名：`jive_money`

- 执行数据库迁移（新增）
  - `./jive start migrate`
  - 等价于对 `postgresql://postgres:postgres@localhost:5433/jive_money` 依次执行 `jive-api/migrations/*.sql`

- 启动本地 API（选择模式）
  - 安全模式：`./jive mode safe`
  - 开发宽松模式：`./jive mode dev`
  - 管理脚本会在未显式设置 `DATABASE_URL` 时默认连接上面的 Docker 开发库。

- 启动/查看前端 Web（可选）
  - `./jive start web`
  - 访问 `http://localhost:3021`

排错：若看到 “role postgres does not exist”，通常说明你连接到了本机 5432 或使用了错误用户。请确认端口为 5433 且账号为 `postgres/postgres`，或显式设置 `DATABASE_URL` 后重试。

## 🔧 高级功能

### 1. 端口管理

**释放所有占用的端口：**
```bash
./jive ports
```

这个命令会：
- 自动检测并释放端口 8012 (API)
- 释放端口 3021 (Web)
- 释放端口 5433 (PostgreSQL)
- 释放端口 6380 (Redis)
- 释放端口 8080 (Adminer)

### 2. 清理功能

**完全清理（慎用）：**
```bash
./jive clean
```

这会：
- 停止所有服务
- 删除所有日志
- 清理 Docker 卷和数据
- 清理构建缓存

### 3. 自定义端口

编辑 `.jive-config` 文件：
```bash
# API 配置
API_PORT=8012         # 修改为你想要的端口
WEB_PORT=3021         # 修改为你想要的端口
DB_PORT=5433          # 修改为你想要的端口
```

### 4. 查看实时状态

```bash
# 实时监控服务状态
watch -n 2 './jive status'
```

## 🔍 故障排除

### 端口被占用

**问题：** 启动服务时提示端口已被占用

**解决方案：**
```bash
# 方法1：使用内置命令释放端口
./jive ports

# 方法2：手动查找并杀死进程
lsof -i:8012           # 查看占用 8012 端口的进程
kill -9 <PID>          # 杀死进程

# 方法3：重启服务（会自动释放端口）
./jive restart api
```

### 数据库连接失败

**问题：** API 无法连接到数据库

**解决方案：**
```bash
# 1. 确保数据库服务运行
./jive start db

# 2. 检查数据库状态
docker ps | grep postgres

# 3. 重新初始化数据库
docker-compose -f jive-api/docker-compose.dev.yml down -v
./jive start db

# 4. 手动创建数据库
docker exec -it jive-api-postgres-1 psql -U postgres -c "CREATE DATABASE jive_money;"
```

### 服务启动后立即停止

**问题：** 服务启动后马上退出

**解决方案：**
```bash
# 查看详细日志
./jive logs api
tail -f .logs/api.log

# 检查依赖
cargo --version        # 确保 Rust 已安装
flutter --version      # 确保 Flutter 已安装
docker --version       # 确保 Docker 已安装
```

### Redis 连接问题

**问题：** Redis 连接失败但不影响运行

**解决方案：**
```bash
# Redis 是可选的，可以忽略
# 如果需要 Redis：
./jive start redis

# 验证 Redis
docker exec -it jive-api-redis-1 redis-cli ping
```

## 🐧 系统服务配置 (Linux)

### 安装为系统服务

**1. 复制服务文件：**
```bash
sudo cp scripts/jive-money.service /etc/systemd/system/
```

**2. 修改服务文件：**
```bash
sudo nano /etc/systemd/system/jive-money.service
# 修改 User 和 WorkingDirectory 为实际路径
```

**3. 启用服务：**
```bash
sudo systemctl daemon-reload
sudo systemctl enable jive-money
sudo systemctl start jive-money
```

**4. 管理服务：**
```bash
sudo systemctl status jive-money   # 查看状态
sudo systemctl restart jive-money  # 重启
sudo systemctl stop jive-money     # 停止
sudo journalctl -u jive-money -f   # 查看日志
```

## 🍎 macOS 自启动 (可选)

创建 LaunchAgent：
```bash
# 创建 plist 文件
cat > ~/Library/LaunchAgents/com.jive.money.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.jive.money</string>
    <key>ProgramArguments</key>
    <array>
        <string>$HOME/jive-flutter-rust/jive-manager.sh</string>
        <string>start</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
EOF

# 加载服务
launchctl load ~/Library/LaunchAgents/com.jive.money.plist
```

## 📊 服务架构

```
┌─────────────────────────────────────────┐
│          jive-manager.sh                │
│         (服务管理器)                     │
└────────────┬────────────────────────────┘
             │
    ┌────────┴────────┬─────────┬─────────┐
    ▼                 ▼         ▼         ▼
┌──────┐         ┌──────┐  ┌──────┐  ┌──────┐
│ API  │         │ Web  │  │  DB  │  │Redis │
│:8012 │         │:3021 │  │:5433 │  │:6380 │
└──────┘         └──────┘  └──────┘  └──────┘
  Rust           Flutter   Docker    Docker
```

## 🔄 服务依赖关系

```
PostgreSQL (必需)
    ↓
Rust API (核心)
    ↓
Flutter Web (前端)
    
Redis (可选，用于缓存)
Adminer (可选，数据库管理)
```

## 💡 最佳实践

### 开发环境
```bash
# 1. 启动基础服务
./jive start docker

# 2. 开发 API 时
cargo watch -x run  # 自动重载

# 3. 开发前端时
flutter run -d chrome --web-port 3021
```

### 生产环境
```bash
# 使用 Docker Compose
docker-compose -f docker-compose.prod.yml up -d

# 或使用系统服务
sudo systemctl start jive-money
```

### 日常维护
```bash
# 每日检查
./jive status                      # 检查服务状态
df -h                              # 检查磁盘空间
docker system df                   # 检查 Docker 使用

# 每周维护
docker system prune -a             # 清理 Docker
./jive restart                     # 重启所有服务

# 查看资源使用
docker stats                       # Docker 资源监控
htop                              # 系统资源监控
```

## 🆘 获取帮助

```bash
# 查看帮助
./jive help

# 查看脚本版本和配置
cat .jive-config

# 报告问题
# 请提供以下信息：
./jive status
./jive logs > debug.log
uname -a
docker --version
```

## 📝 常用操作速查

| 操作 | 命令 |
|------|------|
| 一键启动 | `./jive start` |
| 一键停止 | `./jive stop` |
| 查看状态 | `./jive status` |
| 重启 API | `./jive restart api` |
| 查看日志 | `./jive logs` |
| 释放端口 | `./jive ports` |
| 完全清理 | `./jive clean` |

## 🔗 相关文档

- [项目配置说明](./CLAUDE.md)
- [汇率系统设计](./docs/exchange-rate-system-design.md)
- [API 文档](./docs/multi-currency-api-database.md)
