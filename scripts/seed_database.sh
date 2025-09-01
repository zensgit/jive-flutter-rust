#!/bin/bash

# 数据库种子数据导入脚本
# 用于将系统分类模板导入到PostgreSQL数据库

set -e

# 数据库配置
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-jive_money}
DB_USER=${DB_USER:-jive}
DB_PASSWORD=${DB_PASSWORD:-jive_password}

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Jive Money 数据库种子数据导入${NC}"
echo -e "${GREEN}=========================================${NC}"
echo "数据库: $DB_NAME"
echo "主机: $DB_HOST:$DB_PORT"
echo "用户: $DB_USER"
echo ""

# 检查 psql 是否安装
if ! command -v psql &> /dev/null; then
    echo -e "${RED}错误: 未找到 psql 命令${NC}"
    echo "请先安装 PostgreSQL 客户端："
    echo "  Ubuntu/Debian: sudo apt-get install postgresql-client"
    echo "  macOS: brew install postgresql"
    exit 1
fi

# 检查种子文件是否存在
SEED_FILE="scripts/seed_templates.sql"
if [ ! -f "$SEED_FILE" ]; then
    echo -e "${RED}错误: 种子文件不存在: $SEED_FILE${NC}"
    exit 1
fi

# 测试数据库连接
echo -n "测试数据库连接... "
if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1" > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
    echo -e "${RED}无法连接到数据库，请检查配置${NC}"
    exit 1
fi

# 显示当前模板统计
echo ""
echo "当前数据库模板统计："
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "
SELECT 
    COALESCE(COUNT(*), 0) as total,
    COALESCE(COUNT(CASE WHEN is_featured THEN 1 END), 0) as featured
FROM system_category_templates;" | while read total featured; do
    echo "  总模板数: $total"
    echo "  精选模板: $featured"
done

# 询问是否继续
echo ""
read -p "是否要导入/更新系统分类模板？(y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 0
fi

# 执行种子文件
echo ""
echo -e "${YELLOW}正在导入种子数据...${NC}"
if PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$SEED_FILE" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ 种子数据导入成功${NC}"
else
    echo -e "${RED}✗ 种子数据导入失败${NC}"
    echo "尝试显示错误信息："
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f "$SEED_FILE" 2>&1 | tail -20
    exit 1
fi

# 显示导入结果
echo ""
echo -e "${GREEN}导入完成！${NC}"
echo ""
echo "导入结果统计："

# 显示各分组的模板数量
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "
SELECT 
    cg.name,
    COUNT(t.id) as count
FROM category_groups cg
LEFT JOIN system_category_templates t ON cg.key = t.category_group
GROUP BY cg.name, cg.display_order
ORDER BY cg.display_order;" | while read group count; do
    if [ ! -z "$group" ]; then
        printf "  %-20s: %s 个模板\n" "$group" "$count"
    fi
done

# 显示总计
echo ""
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "
SELECT 
    COUNT(*) as total,
    COUNT(CASE WHEN is_featured THEN 1 END) as featured,
    COUNT(CASE WHEN classification = 'income' THEN 1 END) as income,
    COUNT(CASE WHEN classification = 'expense' THEN 1 END) as expense,
    COUNT(CASE WHEN classification = 'transfer' THEN 1 END) as transfer
FROM system_category_templates;" | while read total featured income expense transfer; do
    echo "总计："
    echo "  总模板数: $total"
    echo "  精选模板: $featured"
    echo "  收入模板: $income"
    echo "  支出模板: $expense"
    echo "  转账模板: $transfer"
done

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}种子数据导入完成！${NC}"
echo ""
echo "您现在可以："
echo "1. 在用户界面浏览模板库"
echo "2. 超级管理员可以访问 /admin/templates 管理模板"
echo -e "${GREEN}=========================================${NC}"