# 部署策略对比与跨系统同步方案

## 🎯 核心问题

你在MacBook和Ubuntu两个系统间同步开发，需要选择最适合的部署方案。

## 📊 部署方案对比

### 方法1：混合模式（推荐 ⭐⭐⭐⭐⭐）

**架构：Docker运行数据库和Redis，本地运行API**

```
┌──────────────────────────────────────┐
│         本地主机系统                    │
│                                      │
│  ┌────────────┐    ┌──────────────┐ │
│  │  API服务    │───▶│   源代码      │ │
│  │  (本地运行)  │    │ (Git同步)     │ │
│  └────────────┘    └──────────────┘ │
│         │                            │
│         ▼                            │
│  ┌────────────────────────────────┐ │
│  │       Docker容器                │ │
│  │  ┌──────────┐  ┌──────────┐   │ │
│  │  │PostgreSQL│  │  Redis   │   │ │
│  │  └──────────┘  └──────────┘   │ │
│  └────────────────────────────────┘ │
└──────────────────────────────────────┘
```

**优点：**
- ✅ **开发效率最高** - 代码修改立即生效，无需重建镜像
- ✅ **调试方便** - 可以直接使用IDE调试器
- ✅ **同步简单** - 只需同步源代码，不需要同步Docker镜像
- ✅ **性能最佳** - API直接运行在主机上，无容器开销
- ✅ **兼容性好** - 避免了跨平台编译问题

**缺点：**
- ⚠️ 需要本地安装Rust环境
- ⚠️ 不同系统可能有环境差异

**使用方式：**
```bash
# MacOS
cd ~/jive-project/jive-api
./start.sh

# Ubuntu
cd ~/jive-project/jive-api
./start-ubuntu.sh  # 需要创建Ubuntu版本
```

### 方法2：完全容器化

**架构：所有服务都在Docker容器中运行**

```
┌──────────────────────────────────────┐
│         本地主机系统                    │
│                                      │
│  ┌──────────────┐                   │
│  │   源代码      │                   │
│  │  (Git同步)    │                   │
│  └──────────────┘                   │
│         │                            │
│         ▼                            │
│  ┌────────────────────────────────┐ │
│  │       Docker容器                │ │
│  │  ┌──────────┐  ┌──────────┐   │ │
│  │  │   API    │  │PostgreSQL│   │ │
│  │  └──────────┘  │          │   │ │
│  │  ┌──────────┐  │  Redis   │   │ │
│  │  │  镜像     │  └──────────┘   │ │
│  │  └──────────┘                  │ │
│  └────────────────────────────────┘ │
└──────────────────────────────────────┘
```

**优点：**
- ✅ 环境完全一致
- ✅ 部署简单，一键启动
- ✅ 适合生产环境

**缺点：**
- ❌ **同步困难** - 不同架构需要不同的Docker镜像
- ❌ **开发效率低** - 每次修改需要重建镜像
- ❌ **调试困难** - 需要远程调试配置
- ❌ **构建缓慢** - 特别是在容器内编译Rust

### 方法3：纯本地运行

**架构：所有服务都在本地运行**

**优点：**
- ✅ 最简单直接
- ✅ 性能最好

**缺点：**
- ❌ 需要在每个系统安装PostgreSQL和Redis
- ❌ 配置管理复杂
- ❌ 版本控制困难

## 🏆 推荐方案：方法1（混合模式）

### 为什么推荐方法1？

1. **同步友好** 📱
   - 只需通过Git同步源代码
   - 不需要处理Docker镜像的跨架构问题
   - 数据库数据可以通过SQL备份/恢复同步

2. **开发效率** ⚡
   - 代码修改立即生效
   - 支持热重载
   - IDE调试器完美工作

3. **架构兼容** 🔧
   - MacOS M4 (ARM64) 和 Ubuntu (x86_64) 使用相同的代码
   - 避免了交叉编译问题
   - Docker只运行平台无关的服务（数据库、Redis）

## 📋 实施指南

### Step 1: 环境准备

**两个系统都需要：**
- Git（代码同步）
- Docker & Docker Compose（运行数据库）
- Rust（本地编译运行API）

### Step 2: 创建统一的启动脚本

```bash
# start-universal.sh
#!/bin/bash

# 检测操作系统
if [[ "$OSTYPE" == "darwin"* ]]; then
    # MacOS配置
    DB_PORT=5433
    REDIS_PORT=6380
    COMPOSE_FILE="docker-compose.macos.yml"
else
    # Ubuntu/Linux配置
    DB_PORT=5432
    REDIS_PORT=6379
    COMPOSE_FILE="docker-compose.ubuntu.yml"
fi

# 启动数据库容器
docker-compose -f $COMPOSE_FILE up -d postgres redis

# 运行API
DATABASE_URL=postgresql://postgres:postgres@localhost:$DB_PORT/jive_money \
REDIS_URL=redis://localhost:$REDIS_PORT \
cargo run --bin jive-api
```

### Step 3: 数据同步策略

#### 选项A：独立数据库（推荐）
- 每个系统维护自己的测试数据
- 通过迁移脚本保持表结构一致

#### 选项B：数据备份同步
```bash
# 备份（在MacOS）
pg_dump -h localhost -p 5433 -U postgres jive_money > backup.sql

# 恢复（在Ubuntu）
psql -h localhost -p 5432 -U postgres jive_money < backup.sql
```

#### 选项C：使用云数据库
- 两个系统连接同一个云端PostgreSQL
- 需要稳定的网络连接

### Step 4: Git工作流

```bash
# 在MacOS完成开发后
git add .
git commit -m "feat: 新功能"
git push

# 在Ubuntu上
git pull
./start-universal.sh  # 自动使用正确的配置
```

## 📝 配置文件管理

### 推荐的项目结构

```
jive-api/
├── .env.example           # 示例配置
├── .env.local            # 本地配置（不提交）
├── docker/
│   ├── docker-compose.macos.yml
│   └── docker-compose.ubuntu.yml
├── scripts/
│   ├── start-universal.sh
│   ├── backup-db.sh
│   └── restore-db.sh
└── src/                  # 源代码（完全同步）
```

### .gitignore配置

```gitignore
# 本地配置
.env.local
.env

# 本地数据
/data/
/logs/

# 编译产物（每个系统自己编译）
/target/

# Docker卷
postgres_data/
redis_data/
```

## 🔍 决策矩阵

| 因素 | 方法1（混合） | 方法2（容器化） | 方法3（纯本地） |
|------|------------|---------------|--------------|
| 开发效率 | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| 同步便利 | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐ |
| 环境一致性 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| 部署简易度 | ⭐⭐⭐⭐ | ⭐⭐⭐⭐⭐ | ⭐⭐ |
| 调试便利 | ⭐⭐⭐⭐⭐ | ⭐⭐ | ⭐⭐⭐⭐ |
| 资源占用 | ⭐⭐⭐⭐ | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ |
| **总分** | **27/30** | **19/30** | **22/30** |

## 💡 最佳实践建议

1. **开发阶段**：使用方法1（混合模式）
   - 快速迭代
   - 方便调试
   - 跨系统同步简单

2. **测试阶段**：偶尔使用方法2验证
   - 确保容器化部署正常
   - 测试生产环境兼容性

3. **生产部署**：使用方法2（完全容器化）
   - 环境一致性
   - 易于扩展
   - 适合CI/CD

## 🚀 快速开始命令

```bash
# 克隆项目
git clone <repo-url>
cd jive-api

# 方法1：混合模式（推荐）
./start.sh        # MacOS
./start-ubuntu.sh # Ubuntu

# 方法2：完全容器化
./docker-full.sh

# 停止服务
./stop.sh
```

## 📞 故障排查

### 问题1：端口冲突
- MacOS使用 5433(PostgreSQL) 和 6380(Redis)
- Ubuntu使用 5432(PostgreSQL) 和 6379(Redis)

### 问题2：编译错误
- 设置 `SQLX_OFFLINE=true` 跳过SQLx检查
- 确保Rust版本 >= 1.75

### 问题3：同步冲突
- 使用 `.gitignore` 排除本地文件
- 不要提交 `/target` 目录
- 使用 `.env.local` 管理本地配置

## 结论

**对于MacBook和Ubuntu跨系统同步开发，强烈推荐使用方法1（混合模式）**：
- Docker运行数据库和Redis（平台无关）
- 本地运行API（每个系统自己编译）
- 通过Git同步源代码

这种方式在开发效率、同步便利性和系统兼容性之间达到了最佳平衡。