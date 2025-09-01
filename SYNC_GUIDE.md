# 📚 Jive 项目跨平台同步指南

## 🎯 同步目标
实现 MacBook 和 Ubuntu 之间的无缝切换，包括代码、进度和 Claude 对话的完整同步。

## 🖥️ 系统环境

| 系统 | 路径 | 用户 |
|------|------|------|
| MacBook | `/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust` | huazhou |
| Ubuntu | `/home/zou/OneDrive/应用/GitHub/jive-flutter-rust` | zou |

## 🔄 同步机制

### 1. **代码同步** - GitHub
- 使用 Git 进行版本控制
- 通过 GitHub Desktop 或命令行同步

### 2. **文件同步** - OneDrive
- 项目位于 OneDrive 目录
- 自动同步非 Git 管理的文件

### 3. **Claude 同步** - 软链接
- 对话历史通过软链接同步
- 进度通过 CLAUDE.md 文件记录

## 📋 快速同步流程

### 🚀 离开当前系统前

```bash
# 1. 更新进度文档
# 告诉 Claude: "请更新 CLAUDE.md 记录当前进度"

# 2. 提交所有更改
git add .
git commit -m "$(date +%Y%m%d) $(uname -s) 更新"
git push

# 3. 确认状态
git status  # 应显示 "working tree clean"
```

### 🎯 到达新系统后

```bash
# 1. 运行同步脚本（推荐）
./sync_work.sh

# 或手动执行：
# 2. 拉取最新代码
git pull

# 3. 更新依赖
cd jive-flutter
flutter pub get
cd ..

# 4. 告诉 Claude
# "我在 [MacBook/Ubuntu] 上继续工作"
```

## 🛠️ 一键同步脚本

### 使用 sync_work.sh
```bash
# 首次使用赋予权限
chmod +x sync_work.sh

# 运行同步
./sync_work.sh
```

脚本功能：
- ✅ 自动检测系统
- ✅ 拉取最新代码
- ✅ 更新 Flutter 依赖
- ✅ 显示任务进度
- ✅ 设置环境变量
- ✅ 创建统一路径 /opt/jive

## 📁 统一路径访问

### 方法一：环境变量
```bash
# 自动设置（运行 sync_work.sh 后）
cd $JIVE_PROJECT_ROOT
```

### 方法二：软链接
```bash
# 两个系统都可用
cd /opt/jive
```

### 方法三：别名
```bash
# 添加到 ~/.bashrc 或 ~/.zshrc
alias jive='cd $JIVE_PROJECT_ROOT'
alias jive-flutter='cd $JIVE_PROJECT_ROOT/jive-flutter'
alias jive-core='cd $JIVE_PROJECT_ROOT/jive-core'
```

## 📝 GitHub Desktop 同步

### 提交代码
1. 打开 GitHub Desktop
2. 查看 **Changes** 标签
3. 选择要提交的文件（排除 .DS_Store、logs/ 等）
4. 填写提交信息：
   - Summary: `20250901 MacBook 功能描述`
5. 点击 **Commit to main**
6. 点击 **Push origin**

### 拉取代码
1. 点击 **Fetch origin**
2. 如有更新，点击 **Pull origin**
3. 运行 `flutter pub get` 更新依赖

## 🚨 注意事项

### ✅ 需要同步的文件
- 源代码（*.dart, *.rs）
- 配置文件（pubspec.yaml, Cargo.toml）
- 文档（*.md）
- **CLAUDE.md**（重要！）

### ❌ 不要同步的文件
- .DS_Store（Mac 系统文件）
- target/（Rust 编译输出）
- build/（Flutter 构建）
- ephemeral/（Flutter 临时文件）
- *.pid（进程文件）
- logs/（日志文件）

## 🔧 常见问题

### 1. 路径找不到
```bash
# 运行同步脚本设置路径
./sync_work.sh

# 或手动设置
export JIVE_PROJECT_ROOT="当前系统的项目路径"
```

### 2. Flutter 依赖错误
```bash
# 清理并重新获取
cd jive-flutter
flutter clean
flutter pub get
```

### 3. Git 冲突
```bash
# 查看冲突文件
git status

# 解决后
git add .
git commit -m "解决冲突"
git push
```

### 4. Claude 不了解进度
```
告诉 Claude: "请查看 CLAUDE.md 了解当前进度"
```

## 📊 同步状态检查

```bash
# 检查 Git 状态
git status

# 查看最近提交
git log --oneline -5

# 查看 Claude 进度
grep "最后更新" CLAUDE.md

# 检查 Flutter
cd jive-flutter && flutter doctor

# 检查 Rust
cd ../jive-core && cargo check
```

## 🎉 最佳实践

1. **每日工作流**
   - 开始：运行 `./sync_work.sh`
   - 工作中：定期 commit
   - 结束：更新 CLAUDE.md 并 push

2. **Claude 使用**
   - 使用相对路径而非绝对路径
   - 重要决策写入 CLAUDE.md
   - 切换系统后先让 Claude 读取进度

3. **冲突预防**
   - 不要同时在两个系统工作
   - 切换前确保所有更改已提交
   - 使用 .gitignore 排除本地文件

## 📞 快速命令参考

```bash
# 同步工作
./sync_work.sh

# 启动项目
./start.sh

# 进入项目
cd /opt/jive
cd $JIVE_PROJECT_ROOT

# Git 操作
git pull
git add .
git commit -m "message"
git push

# Flutter 操作
flutter pub get
flutter run
flutter clean

# 查看进度
cat CLAUDE.md | grep -A 5 "正在进行"
```

---

💡 **提示**: 将此文档保持更新，记录遇到的新问题和解决方案。

📅 **最后更新**: 2025-09-01
🖥️ **更新系统**: MacBook