# 跨平台路径同步解决方案

## 路径映射

### MacBook 路径
```
/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust
```

### Ubuntu 路径
```
/home/zou/OneDrive/应用/GitHub/jive-flutter-rust
```

## 解决方案

### 1. 使用环境变量（推荐）

**在 MacBook 的 ~/.zshrc 或 ~/.bash_profile:**
```bash
export JIVE_PROJECT_ROOT="/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust"
```

**在 Ubuntu 的 ~/.bashrc:**
```bash
export JIVE_PROJECT_ROOT="/home/zou/OneDrive/应用/GitHub/jive-flutter-rust"
```

**使用时:**
```bash
cd $JIVE_PROJECT_ROOT
cd $JIVE_PROJECT_ROOT/jive-flutter
```

### 2. 创建统一软链接

**在 MacBook:**
```bash
sudo ln -s /Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust /opt/jive
```

**在 Ubuntu:**
```bash
sudo ln -s /home/zou/OneDrive/应用/GitHub/jive-flutter-rust /opt/jive
```

**统一使用:**
```bash
cd /opt/jive
cd /opt/jive/jive-flutter
```

### 3. 智能路径检测脚本

创建 `detect_path.sh`:
```bash
#!/bin/bash

# 自动检测项目路径
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    export JIVE_ROOT="/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux/Ubuntu
    export JIVE_ROOT="/home/zou/OneDrive/应用/GitHub/jive-flutter-rust"
fi

cd "$JIVE_ROOT"
echo "项目路径: $JIVE_ROOT"
```

## Claude 使用建议

### 1. 使用相对路径
当 Claude 需要操作文件时，尽量使用相对路径：
```bash
# 不好的做法
/Users/huazhou/.../jive-flutter/lib/main.dart

# 好的做法
./jive-flutter/lib/main.dart
jive-flutter/lib/main.dart
```

### 2. 让 Claude 感知当前系统
在每个新会话开始时告诉 Claude：
```
"我现在在 MacBook/Ubuntu 上工作，项目路径是 xxx"
```

### 3. 在 CLAUDE.md 中记录
```markdown
## 当前工作环境
- 系统: MacBook / Ubuntu
- 路径: 使用 $JIVE_PROJECT_ROOT 或 /opt/jive
- 最后工作位置: jive-flutter/lib/screens/home.dart:125
```

## 自动同步脚本

创建 `sync_work.sh`:
```bash
#!/bin/bash

# 获取当前系统
if [[ "$OSTYPE" == "darwin"* ]]; then
    SYSTEM="MacBook"
    PROJECT_ROOT="/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust"
else
    SYSTEM="Ubuntu"
    PROJECT_ROOT="/home/zou/OneDrive/应用/GitHub/jive-flutter-rust"
fi

cd "$PROJECT_ROOT"

# 同步前的操作
echo "=== 在 $SYSTEM 上同步工作 ==="

# 1. 拉取最新代码
echo "1. 拉取最新代码..."
git pull

# 2. 更新依赖
echo "2. 更新 Flutter 依赖..."
cd jive-flutter
flutter pub get
cd ..

# 3. 显示最近提交
echo "3. 最近的提交："
git log --oneline -5

# 4. 显示 Claude 进度
echo "4. Claude 最新进度："
grep -A 5 "### 正在进行的任务" CLAUDE.md

echo "=== 同步完成，可以开始工作 ==="
```

## 使用流程

### 切换到新系统后
1. 运行同步脚本：
   ```bash
   ./sync_work.sh
   ```

2. 告诉 Claude 当前环境：
   ```
   "我现在在 [MacBook/Ubuntu] 上，继续之前的工作"
   ```

3. Claude 会：
   - 读取 CLAUDE.md 了解进度
   - 使用相对路径操作文件
   - 继续之前的对话上下文（因为已同步）

### 完成工作后
1. 更新进度：
   ```
   "更新 CLAUDE.md 记录今天的进度"
   ```

2. 提交代码：
   ```bash
   git add .
   git commit -m "$SYSTEM $(date +%Y%m%d) 完成xxx"
   git push
   ```

这样就能完美处理路径差异，实现真正的无缝切换！