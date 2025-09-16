#!/bin/bash
# SQLx 离线模式准备脚本

echo "📦 准备 SQLx 离线查询缓存..."

# 如果外部已提供 DATABASE_URL，则不启动本地容器
if [ -z "$DATABASE_URL" ]; then
  echo "未检测到 DATABASE_URL，尝试使用本地开发数据库..."
  export DATABASE_URL="postgresql://postgres:postgres@localhost:5433/jive_money"
  if ! docker ps | grep -q jive-postgres; then
      echo "启动本地数据库容器..."
      docker-compose -f docker-compose.dev.yml up -d postgres
      sleep 5
  fi
else
  echo "使用外部提供的 DATABASE_URL=$DATABASE_URL"
fi

# 安装 sqlx-cli（如果未安装）
if ! command -v sqlx &> /dev/null; then
    echo "安装 sqlx-cli..."
    cargo install sqlx-cli --no-default-features --features postgres
fi

# 准备查询缓存
echo "生成查询缓存..."
cargo sqlx prepare --merge

echo "✅ SQLx 缓存准备完成！"
echo "📝 已生成 .sqlx 目录，请提交到Git"
