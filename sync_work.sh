#!/bin/bash

# Jive 跨平台工作同步脚本
# 自动处理 MacBook 和 Ubuntu 之间的路径差异

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 检测当前系统并设置路径
if [[ "$OSTYPE" == "darwin"* ]]; then
    SYSTEM="MacBook"
    PROJECT_ROOT="/Users/huazhou/Insync/hua.chau@outlook.com/OneDrive/应用/GitHub/jive-flutter-rust"
    USER_HOME="/Users/huazhou"
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    SYSTEM="Ubuntu"
    PROJECT_ROOT="/home/zou/OneDrive/应用/GitHub/jive-flutter-rust"
    USER_HOME="/home/zou"
else
    echo "未知系统类型: $OSTYPE"
    exit 1
fi

echo -e "${BLUE}=== 在 $SYSTEM 上同步 Jive 项目 ===${NC}"
echo "项目路径: $PROJECT_ROOT"

# 切换到项目目录
cd "$PROJECT_ROOT"

# 1. Git 同步
echo -e "\n${YELLOW}1. 检查 Git 状态...${NC}"
git status --short

echo -e "\n${YELLOW}2. 拉取最新代码...${NC}"
git pull || {
    echo -e "${YELLOW}提示: 如有冲突请手动解决${NC}"
}

# 2. 更新依赖
echo -e "\n${YELLOW}3. 更新 Flutter 依赖...${NC}"
if [ -d "jive-flutter" ]; then
    cd jive-flutter
    flutter pub get
    cd ..
    echo -e "${GREEN}✓ Flutter 依赖更新完成${NC}"
fi

# 3. 创建/更新软链接（可选）
if [ ! -L "/opt/jive" ]; then
    echo -e "\n${YELLOW}4. 创建统一路径软链接...${NC}"
    echo "需要 sudo 权限创建 /opt/jive 链接"
    sudo ln -sf "$PROJECT_ROOT" /opt/jive && \
        echo -e "${GREEN}✓ 软链接创建成功: /opt/jive${NC}"
fi

# 4. 设置环境变量
echo -e "\n${YELLOW}5. 设置环境变量...${NC}"
export JIVE_PROJECT_ROOT="$PROJECT_ROOT"
echo "export JIVE_PROJECT_ROOT=\"$PROJECT_ROOT\"" >> ~/.jive_env
echo -e "${GREEN}✓ JIVE_PROJECT_ROOT 已设置${NC}"

# 5. 显示最近提交
echo -e "\n${YELLOW}6. 最近的 Git 提交:${NC}"
git log --oneline --graph --decorate -5

# 6. 显示当前进度
echo -e "\n${YELLOW}7. Claude 任务进度:${NC}"
if [ -f "CLAUDE.md" ]; then
    echo -e "${BLUE}--- 正在进行的任务 ---${NC}"
    sed -n '/### 正在进行的任务/,/### 最近完成的功能/p' CLAUDE.md | head -n 10
    
    echo -e "\n${BLUE}--- 最后更新信息 ---${NC}"
    grep "最后更新：" CLAUDE.md || echo "未找到更新信息"
    grep "更新人：" CLAUDE.md || echo "未找到更新人信息"
fi

# 7. 检查是否有未提交的更改
echo -e "\n${YELLOW}8. 检查未提交的更改:${NC}"
if [[ -n $(git status -s) ]]; then
    echo -e "${YELLOW}⚠ 发现未提交的更改:${NC}"
    git status -s
else
    echo -e "${GREEN}✓ 工作区干净${NC}"
fi

# 8. 提供快捷命令
echo -e "\n${GREEN}=== 同步完成 ===${NC}"
echo -e "${BLUE}快捷命令:${NC}"
echo "  cd \$JIVE_PROJECT_ROOT  # 进入项目目录"
echo "  cd /opt/jive           # 使用统一路径"
echo "  ./start.sh             # 启动项目"
echo "  code .                 # 打开 VS Code"

echo -e "\n${GREEN}提示: 告诉 Claude '我在 $SYSTEM 上继续工作'${NC}"