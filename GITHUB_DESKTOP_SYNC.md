# GitHub Desktop 同步指南

## 日常同步流程

### 开始工作前
1. 打开 GitHub Desktop
2. 点击 **"Fetch origin"** 按钮
3. 如有更新，点击 **"Pull origin"**
4. 运行依赖更新：
   ```bash
   cd jive-flutter
   flutter pub get
   ```

### 工作结束后
1. 在 GitHub Desktop 查看 **Changes** 标签
2. 查看所有修改的文件
3. 取消勾选不需要提交的文件（如 .DS_Store、logs/）
4. 填写提交信息：
   - **Summary**: `日期 + 系统 + 简要描述`
   - 例如: `20250901 MacBook 修复登录bug`
5. 点击 **"Commit to main"**
6. 点击 **"Push origin"** 推送到远程

## 文件选择建议

### ✅ 应该提交的文件
- 源代码文件 (*.dart, *.rs, *.js)
- 配置文件 (pubspec.yaml, Cargo.toml)
- 文档文件 (*.md)
- CLAUDE.md (进度同步)

### ❌ 不要提交的文件
- .DS_Store (Mac系统文件)
- logs/* (日志文件)
- target/ (Rust编译输出)
- build/ (Flutter构建输出)
- .flutter_web.pid
- .rust_server.pid
- ephemeral/ (Flutter临时文件)

## 分支管理

### 创建新分支（可选）
1. 点击顶部 **"Current Branch"**
2. 点击 **"New Branch"**
3. 输入分支名称（如: feature/login-fix）
4. 基于 main 创建

### 合并分支
1. 切换到 main 分支
2. 点击 **"Choose a branch to merge"**
3. 选择要合并的分支
4. 确认合并

## 查看历史

1. 点击 **"History"** 标签
2. 可以查看所有提交记录
3. 点击任意提交查看详细更改

## 撤销操作

### 撤销本地更改
- 右键点击文件 → **"Discard Changes"**

### 撤销提交（未推送）
- History 中右键点击提交 → **"Undo Commit"**

### 撤销已推送的提交
- History 中右键点击提交 → **"Revert This Commit"**

## 快捷键

- **Cmd/Ctrl + Shift + F**: Fetch origin
- **Cmd/Ctrl + Shift + P**: Push origin  
- **Cmd/Ctrl + Enter**: Commit
- **Cmd/Ctrl + Shift + N**: New branch

## 故障排查

### 拉取失败
1. 检查网络连接
2. 确认没有未提交的冲突
3. 尝试 Fetch 后再 Pull

### 推送失败
1. 先 Pull 最新代码
2. 解决可能的冲突
3. 重新 Push

### 认证问题
1. GitHub Desktop → Preferences → Accounts
2. 重新登录 GitHub 账户
3. 确认有仓库访问权限

## 同步检查清单

- [ ] Fetch origin 检查更新
- [ ] Pull origin 拉取更新
- [ ] flutter pub get 更新依赖
- [ ] 完成工作
- [ ] 更新 CLAUDE.md 进度
- [ ] Commit 提交更改
- [ ] Push origin 推送到远程