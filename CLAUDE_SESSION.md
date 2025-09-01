# Claude 会话状态 - OneDrive同步

> 此文件通过OneDrive自动同步，用于`/resume`恢复会话

## 🔄 同步状态
- **最后同步时间**: 2025-08-31 17:45
- **最后工作系统**: MacBook
- **同步方式**: OneDrive + Insync

## 📍 当前工作状态

### 活动任务
```yaml
current_task: "配置OneDrive同步环境"
progress: 50%
next_steps:
  - 完成同步配置
  - 测试跨系统工作流
```

### 最近修改的文件
- `.insyncignore` - 配置同步忽略规则
- `CLAUDE.md` - 项目配置文档
- `.gitignore` - Git忽略规则

## ⚠️ 系统特定注意事项

### MacBook路径
```bash
PROJECT_ROOT=/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust
FLUTTER_ROOT=[根据实际安装路径]
```

### Ubuntu路径
```bash
PROJECT_ROOT=/home/zou/OneDrive/应用/GitHub/jive-flutter-rust
FLUTTER_ROOT=[根据实际安装路径]
```

## 🔧 切换系统后必须执行

### 从MacBook切换到Ubuntu
```bash
# 1. 等待OneDrive同步完成
# 2. 重建Flutter依赖
cd jive-flutter
flutter clean
flutter pub get

# 3. 清理Rust缓存
cd ../jive-core
cargo clean
cargo build
```

### 从Ubuntu切换到MacBook
```bash
# 1. 等待OneDrive同步完成
# 2. 重建Flutter依赖
cd jive-flutter
flutter clean
flutter pub get

# 3. 如果有iOS相关
cd ios
pod install
```

## 📝 工作日志

### 2025-08-31
- [MacBook] 配置OneDrive同步环境
- [MacBook] 创建.insyncignore忽略规则
- [MacBook] 设置Claude会话状态追踪

### 待完成任务队列
- [ ] 测试OneDrive同步效果
- [ ] 验证Flutter依赖重建
- [ ] 确认软链接处理

## 🚨 已知问题和解决方案

### 问题1: 软链接冲突
**症状**: Flutter报错找不到插件
**解决**: 运行 `flutter pub get` 重新生成

### 问题2: 文件锁定
**症状**: OneDrive显示同步冲突
**解决**: 关闭IDE，等待同步完成

### 问题3: 路径不一致
**症状**: Claude找不到文件
**解决**: 使用相对路径，避免绝对路径

---
*自动同步文件 - 请勿在两个系统同时编辑*