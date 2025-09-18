# Jive Flutter Rust 项目配置

## 项目结构
- `jive-flutter/` - Flutter前端应用
- `jive-core/` - Rust后端核心
- `database/` - 数据库相关文件

## 跨平台开发注意事项

### MacBook环境
- 项目路径: `/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust`
- 软链接: `~/jive-project` (建议创建: `ln -s /Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust ~/jive-project`)
- Flutter SDK: 通过Homebrew或官网安装
- 开发前运行: `flutter pub get`

### Ubuntu环境  
- 项目路径: `/home/zou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust`
- 软链接: `~/jive-project` (建议创建: `ln -s /home/zou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust ~/jive-project`)
- Flutter SDK: 通过snap或手动安装
- 开发前运行: `flutter pub get`

### 快速进入项目
两个系统都执行：
```bash
cd ~/jive-project && claude
```

## 同步工作流

1. **开始工作前**：
   ```bash
   git pull
   cd jive-flutter
   flutter pub get
   ```

2. **提交代码前**：
   ```bash
   git add .
   git commit -m "描述更改"
   git push
   ```

## 🎯 最佳开发模式（推荐）

### 智能混合模式 - 根据系统选择最佳方案

#### 🍎 macOS (推荐本地API + Docker数据库)
- ✅ **API本地运行** - 充分利用M4芯片性能
- ✅ **数据库Docker** - 隔离依赖，易于管理
- ✅ **调试方便** - 原生调试工具
- ✅ **热重载快** - 无虚拟化开销

#### 🐧 Ubuntu/Linux (推荐全Docker)
- ✅ **全容器化** - 环境隔离完整
- ✅ **资源优化** - Linux Docker性能好
- ✅ **配置简单** - 一键启动所有服务
- ✅ **易于维护** - 统一管理

### 支持平台
- ✅ MacBook M4 (ARM64/Apple Silicon)
- ✅ Ubuntu/Linux (AMD64/x86_64)
- ✅ 跨平台无缝切换

### 🚀 统一启动方式（推荐）
```bash
# 任何系统都执行：
cd ~/jive-project && ./start-dev.sh
```

### Docker 服务详情
```bash
# 服务端口映射（已调整避免冲突）
- API服务: localhost:18012 → 8012 (容器内)
- PostgreSQL: localhost:15432 → 5432 (容器内)
- Redis: localhost:16379 → 6379 (容器内)
- Adminer: localhost:19080 → 8080 (容器内)

# 管理命令
cd ~/jive-project/jive-api
docker-compose -f docker-compose.dev.yml up -d    # 启动
docker-compose -f docker-compose.dev.yml down     # 停止
docker-compose -f docker-compose.dev.yml logs -f  # 日志
docker-compose -f docker-compose.dev.yml restart  # 重启
```

### Docker 服务端口（已优化避免冲突）
- **API服务**: http://localhost:18012
- **PostgreSQL**: localhost:15432
- **Redis**: localhost:16379
- **Adminer** (数据库管理): http://localhost:19080 (仅开发环境)

### Docker 命令说明
```bash
./docker-run.sh build      # 构建镜像
./docker-run.sh dev        # 启动开发环境
./docker-run.sh prod       # 启动生产环境
./docker-run.sh status     # 查看服务状态
./docker-run.sh logs       # 查看日志
./docker-run.sh shell      # 进入容器
./docker-run.sh db-shell   # 进入数据库
./docker-run.sh clean      # 清理所有容器和数据
```

### 开发环境特性
- 🔥 热重载（代码修改自动重启）
- 📝 源码挂载
- 🔧 调试端口 9229
- 🗄️ 数据库管理工具
- 📊 Redis 可视化工具

## 常用命令

### Flutter相关
```bash
# 获取依赖
flutter pub get

# 运行应用 (Web)
flutter run -d web-server --web-port 3021

# 运行应用 (桌面)  
flutter run

# 构建APK
flutter build apk

# 构建Web
flutter build web

# 清理项目
flutter clean
```

### Rust相关
```bash
# 构建
cargo build

# 运行 (端口8012)
cargo run

# 带环境变量运行
API_PORT=8012 cargo run

# 测试
cargo test
```

## 注意事项

- **不要提交**：
  - `.DS_Store` (Mac系统文件)
  - `ephemeral/` 目录（Flutter临时文件）
  - `target/` 目录（Rust编译输出）
  - 本地软链接

- **每次切换系统后**：
  - 运行 `flutter pub get` 重新生成本地依赖
  - 检查是否有未提交的更改
  - 拉取最新代码

## 项目特定配置

### 服务端口配置（Docker容器化）
- **Rust API**: 端口 18012 (http://localhost:18012)
- **Flutter Web**: 端口 3021 (http://localhost:3021)
- **PostgreSQL**: 端口 15432 (数据库: jive_money)
- **Redis**: 端口 16379

### API配置
- 后端服务端口: 18012 (Docker映射)
- API基础URL: http://localhost:18012/api/v1
- 健康检查: http://localhost:18012/ (返回API信息)

### 数据库配置
- PostgreSQL 数据库: jive_money
- 连接字符串: postgresql://postgres:postgres@localhost:15432/jive_money
- Redis缓存: localhost:16379

## 当前工作进度

### 正在进行的任务
<!-- 在这里记录当前任务，切换系统时更新 -->
- [x] 修复Flutter编译错误
- [x] 配置服务端口
- [x] 连接真实数据库
- [ ] 测试完整功能流程

### 最近完成的功能
<!-- 记录最近完成的重要功能 -->
- [x] 修复所有Flutter编译错误 (22个关键错误)
- [x] 配置端口和服务连接 (API: 8012, Web: 3021)
- [x] 建立API连接测试 (Rust API正常响应)
- [x] 创建环境配置管理系统
- [x] 添加服务健康检查工具

### 待解决的问题
<!-- 记录需要注意的问题 -->
- 数据库连接权限配置
- 完整的用户认证流程测试
- 前后端数据交互验证

### 工作笔记
<!-- 任何需要在系统间传递的笔记 -->
```
最后更新：2025-09-03 00:30
更新人：Claude Code (Ubuntu环境)
状态：✅ Docker容器化部署完成

最新更新：
- 添加Docker多架构支持（ARM64/AMD64）
- 创建docker-compose配置
- 实现开发环境热重载
- 添加数据库和Redis管理工具
- 创建一键部署脚本

之前修复：
- 端口配置统一为8012
- 实现JWT认证中间件
- 添加CORS安全配置
- 创建统一错误处理
- 实现请求限流保护
- 修复所有编译警告

详细修复报告：jive-api/FIX_REPORT.md
Docker使用说明：见上方Docker容器化部署章节
```