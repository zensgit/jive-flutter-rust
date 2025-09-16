#!/usr/bin/env bash
set -euo pipefail

# SQLx 离线缓存准备脚本
# 支持外部 DATABASE_URL，使用 cargo sqlx prepare --merge

# 使用外部 DATABASE_URL 或默认值
DB_URL="${DATABASE_URL:-postgresql://postgres:postgres@localhost:5432/jive_money}"

echo "==> 准备 SQLx 离线缓存"
echo "==> 数据库URL: $DB_URL"

# 检查数据库连接
echo "==> 检查数据库连接..."
if ! psql "$DB_URL" -c "SELECT 1" >/dev/null 2>&1; then
    echo "错误: 无法连接到数据库 $DB_URL"
    exit 1
fi

echo "==> 数据库连接正常"

# 运行数据库迁移（如果需要）
if [ -d "migrations" ]; then
    echo "==> 运行数据库迁移..."
    ./scripts/migrate_local.sh --force --db-url "$DB_URL" || true
fi

# 安装 sqlx-cli（如果未安装）
if ! command -v sqlx >/dev/null 2>&1; then
    echo "==> 安装 sqlx-cli..."
    cargo install sqlx-cli --no-default-features --features postgres
fi

# 生成 SQLx 离线缓存
echo "==> 生成 SQLx 离线缓存..."
export DATABASE_URL="$DB_URL"

# 生成 SQLx 离线缓存 (不使用 --merge，覆盖现有缓存)
cargo sqlx prepare

echo "==> SQLx 离线缓存准备完成"
echo "==> 缓存文件位置: .sqlx/"

# 验证生成的文件
if [ -d ".sqlx" ] && [ "$(ls -1 .sqlx/*.json 2>/dev/null | wc -l)" -gt 0 ]; then
    echo "==> 已生成 $(ls -1 .sqlx/*.json | wc -l) 个缓存文件"
else
    echo "警告: 未找到生成的缓存文件"
    exit 1
fi

echo "==> 完成"
