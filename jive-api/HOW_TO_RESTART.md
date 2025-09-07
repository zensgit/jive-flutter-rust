# 🔄 如何重启 Jive Money API

## 🚀 快速重启方法

### 方法 1：使用重启脚本（推荐）
```bash
cd ~/jive-project/jive-api
./restart.sh
```

### 方法 2：手动重启
```bash
# 1. 停止服务
cd ~/jive-project/jive-api
./stop.sh

# 2. 启动服务
./start-complete.sh
```

### 方法 3：一行命令
```bash
cd ~/jive-project/jive-api && ./stop.sh && ./start-complete.sh
```

## 📝 详细步骤说明

### 1️⃣ 停止现有服务
```bash
# 查看运行中的进程
ps aux | grep jive-api

# 终止进程（假设进程 ID 是 12345）
kill 12345

# 或强制终止所有 jive-api 进程
pkill -f jive-api
```

### 2️⃣ 重新启动服务
```bash
cd ~/jive-project/jive-api

# 设置环境变量
export RUST_LOG=info
export API_PORT=8012
export DATABASE_URL="postgresql://huazhou:@localhost:5432/jive_money"

# 运行主程序
cargo run --bin jive-api
```

### 3️⃣ 在后台运行
```bash
# 在后台运行并保存日志
cargo run --bin jive-api > api.log 2>&1 &

# 查看日志
tail -f api.log
```

## 🛠️ 可用脚本

| 脚本 | 用途 | 命令 |
|-----|------|------|
| **restart.sh** | 一键重启（停止+启动） | `./restart.sh` |
| **stop.sh** | 仅停止服务 | `./stop.sh` |
| **start-complete.sh** | 启动完整版 | `./start-complete.sh` |
| **start-api.sh** | 启动精简版 | `./start-api.sh` |

## 🔍 检查服务状态

```bash
# 检查健康状态
curl http://localhost:8012/health

# 查看进程
ps aux | grep jive-api

# 查看端口占用
lsof -i :8012
```

## ⚠️ 常见问题

### 端口被占用
```bash
# 查找占用 8012 端口的进程
lsof -i :8012

# 终止占用端口的进程
kill -9 <PID>
```

### 数据库连接失败
```bash
# 确保 PostgreSQL 正在运行
brew services list | grep postgresql

# 启动 PostgreSQL（如果未运行）
brew services start postgresql
```

### 编译错误
```bash
# 清理并重新编译
cargo clean
cargo build --bin jive-api
```

## 💡 提示

- 使用 `RUST_LOG=debug` 获取更详细的日志
- 使用 `cargo run --release` 运行优化版本
- 使用 `nohup` 让服务在关闭终端后继续运行：
  ```bash
  nohup cargo run --bin jive-api > api.log 2>&1 &
  ```

## 📊 服务信息

- **API 地址**: http://localhost:8012
- **WebSocket**: ws://localhost:8012/ws
- **健康检查**: http://localhost:8012/health
- **API 文档**: http://localhost:8012/

## 更新时间: 2025-09-07