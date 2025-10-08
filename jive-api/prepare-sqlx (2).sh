#!/bin/bash
# SQLx 离线模式准备脚本

echo "📦 准备 SQLx 离线查询缓存..."

# 确保数据库运行
if ! docker ps | grep -q jive-postgres; then
    echo "启动数据库..."
    docker-compose -f docker-compose.dev.yml up -d postgres
    sleep 5
fi

# 设置数据库URL
export DATABASE_URL="postgresql://postgres:postgres@localhost:5433/jive_money"

# 安装 sqlx-cli（如果未安装）
if ! command -v sqlx &> /dev/null; then
    echo "安装 sqlx-cli..."
    cargo install sqlx-cli --no-default-features --features postgres
fi

# 准备查询缓存
echo "生成查询缓存..."
cargo sqlx prepare

echo "✅ SQLx 缓存准备完成！"
echo "📝 已生成 .sqlx 目录，请提交到Git"
