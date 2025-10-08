#!/bin/bash

# 完全容器化运行脚本 - 方法2
# 所有服务（包括API）都在Docker容器中运行

set -e

# 颜色定义
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# 显示菜单
show_menu() {
    echo -e "${BLUE}=== Jive API 完全容器化管理 ===${NC}"
    echo ""
    echo "1. 🚀 启动所有服务（生产模式）"
    echo "2. 🛠  启动所有服务（开发模式，含管理工具）"
    echo "3. 🔨 重新构建并启动"
    echo "4. 🛑 停止所有服务"
    echo "5. 📊 查看服务状态"
    echo "6. 📝 查看日志"
    echo "7. 🗑  清理所有数据（危险）"
    echo "8. 🔄 运行数据库迁移"
    echo "9. ❌ 退出"
    echo ""
}

# 启动服务
start_services() {
    MODE=$1
    echo -e "${BLUE}📦 启动Docker服务...${NC}"
    
    if [ "$MODE" = "dev" ]; then
        echo -e "${YELLOW}开发模式：包含数据库和Redis管理界面${NC}"
        docker-compose -f docker-compose.full.yml --profile dev up -d
        echo ""
        echo -e "${GREEN}✅ 所有服务已启动！${NC}"
        echo ""
        echo -e "${BLUE}访问地址：${NC}"
        echo "  • API服务: http://localhost:8012"
        echo "  • 健康检查: http://localhost:8012/health"
        echo "  • Adminer（数据库管理）: http://localhost:8080"
        echo "  • Redis Commander: http://localhost:8081"
    else
        docker-compose -f docker-compose.full.yml up -d
        echo ""
        echo -e "${GREEN}✅ 所有服务已启动！${NC}"
        echo ""
        echo -e "${BLUE}访问地址：${NC}"
        echo "  • API服务: http://localhost:8012"
        echo "  • 健康检查: http://localhost:8012/health"
    fi
    
    echo ""
    echo -e "${BLUE}数据库连接信息：${NC}"
    echo "  • Host: localhost"
    echo "  • Port: 5434"
    echo "  • Database: jive_money"
    echo "  • Username: postgres"
    echo "  • Password: postgres"
}

# 重新构建
rebuild() {
    echo -e "${BLUE}🔨 重新构建Docker镜像...${NC}"
    docker-compose -f docker-compose.full.yml build --no-cache api
    echo -e "${GREEN}✅ 构建完成${NC}"
    start_services "prod"
}

# 停止服务
stop_services() {
    echo -e "${BLUE}🛑 停止所有服务...${NC}"
    docker-compose -f docker-compose.full.yml down
    echo -e "${GREEN}✅ 所有服务已停止${NC}"
}

# 查看状态
show_status() {
    echo -e "${BLUE}📊 服务状态：${NC}"
    docker-compose -f docker-compose.full.yml ps
    echo ""
    echo -e "${BLUE}🔍 健康检查：${NC}"
    curl -s http://localhost:8012/health 2>/dev/null | python3 -m json.tool || echo "API未响应"
}

# 查看日志
show_logs() {
    echo -e "${BLUE}📝 查看日志（按Ctrl+C退出）${NC}"
    docker-compose -f docker-compose.full.yml logs -f
}

# 清理数据
clean_all() {
    echo -e "${RED}⚠️  警告：这将删除所有数据！${NC}"
    read -p "确定要继续吗？(y/n): " confirm
    if [ "$confirm" = "y" ]; then
        docker-compose -f docker-compose.full.yml down -v
        echo -e "${GREEN}✅ 所有数据已清理${NC}"
    else
        echo -e "${YELLOW}已取消${NC}"
    fi
}

# 运行迁移
run_migrations() {
    echo -e "${BLUE}🔄 运行数据库迁移...${NC}"
    
    # 确保数据库服务运行
    docker-compose -f docker-compose.full.yml up -d postgres
    sleep 3
    
    # 运行每个迁移文件
    for migration in migrations/*.sql; do
        if [ -f "$migration" ]; then
            echo -e "${BLUE}执行: $(basename $migration)${NC}"
            docker-compose -f docker-compose.full.yml exec -T postgres \
                psql -U postgres -d jive_money < "$migration" || true
        fi
    done
    
    echo -e "${GREEN}✅ 迁移完成${NC}"
}

# 主循环
main() {
    cd "$(dirname "$0")"
    
    while true; do
        show_menu
        read -p "请选择操作 [1-9]: " choice
        
        case $choice in
            1)
                start_services "prod"
                ;;
            2)
                start_services "dev"
                ;;
            3)
                rebuild
                ;;
            4)
                stop_services
                ;;
            5)
                show_status
                ;;
            6)
                show_logs
                ;;
            7)
                clean_all
                ;;
            8)
                run_migrations
                ;;
            9)
                echo -e "${GREEN}再见！${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}无效选择${NC}"
                ;;
        esac
        
        echo ""
        read -p "按Enter继续..."
    done
}

# 运行主程序
main