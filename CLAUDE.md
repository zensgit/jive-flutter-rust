# Jive Flutter Rust 项目配置

## 项目结构
- `jive-flutter/` - Flutter前端应用
- `jive-core/` - Rust后端核心
- `database/` - 数据库相关文件

## 跨平台开发注意事项

### MacBook环境
- 项目路径: `/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust`
- Flutter SDK: 通过Homebrew或官网安装
- 开发前运行: `flutter pub get`

### Ubuntu环境  
- 项目路径: `/home/zou/OneDrive/应用/GitHub/jive-flutter-rust`
- Flutter SDK: 通过snap或手动安装
- 开发前运行: `flutter pub get`

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

# 运行应用
flutter run

# 构建APK
flutter build apk

# 清理项目
flutter clean
```

### Rust相关
```bash
# 构建
cargo build

# 运行
cargo run

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

### 数据库
- SQLite数据库位于: `database/` 目录

### API配置
- 后端服务端口: [根据实际配置填写]
- API基础URL: [根据实际配置填写]

## 当前工作进度

### 正在进行的任务
<!-- 在这里记录当前任务，切换系统时更新 -->
- [ ] 任务1：描述
- [ ] 任务2：描述

### 最近完成的功能
<!-- 记录最近完成的重要功能 -->
- [x] 配置.gitignore文件
- [x] 设置Claude跨平台配置

### 待解决的问题
<!-- 记录需要注意的问题 -->
- 问题1：描述
- 问题2：描述

### 工作笔记
<!-- 任何需要在系统间传递的笔记 -->

## 跨平台同步工作流

### 切换系统时的步骤

**离开当前系统前：**
1. 更新 CLAUDE.md 中的进度
2. 提交所有更改：
   ```bash
   git add .
   git commit -m "日期 系统名称更新"
   git push
   ```

**到达新系统后：**
1. 拉取最新代码：
   ```bash
   git pull
   ```
2. 重新生成本地依赖：
   ```bash
   cd jive-flutter
   flutter pub get
   ```
3. 查看 CLAUDE.md 了解最新进度

### 注意事项
- `.gitignore` 已配置忽略系统特定文件
- 本地路径差异通过环境变量处理
- Flutter依赖需每次重新生成

```
最后更新：2025-09-01
更新人：MacBook
```