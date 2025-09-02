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

### 服务端口配置
- **Rust API**: 端口 8012 (http://localhost:8012)
- **Flutter Web**: 端口 3021 (http://localhost:3021)  
- **PostgreSQL**: 端口 5432 (数据库: jive_money)
- **Redis**: 端口 6379

### API配置
- 后端服务端口: 8012
- API基础URL: http://localhost:8012/api/v1
- 健康检查: http://localhost:8012/ (返回API信息)

### 数据库配置
- PostgreSQL 数据库: jive_money
- 连接字符串: postgresql://postgres:postgres@localhost:5432/jive_money
- Redis缓存: localhost:6379 (测试通过)

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
最后更新：2025-09-02
更新人：Claude Code (Ubuntu环境)
状态：✅ 所有服务运行正常，编译错误已修复
```