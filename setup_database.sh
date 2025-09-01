#!/bin/bash

# 数据库设置脚本
# 用于初始化Jive Money数据库和运行迁移

set -e

# 默认配置
DB_HOST=${DB_HOST:-localhost}
DB_PORT=${DB_PORT:-5432}
DB_NAME=${DB_NAME:-jive_money}
DB_USER=${DB_USER:-jive}
DB_PASSWORD=${DB_PASSWORD:-jive_password}

echo "========================================="
echo "Jive Money 数据库设置"
echo "========================================="
echo "数据库主机: $DB_HOST:$DB_PORT"
echo "数据库名称: $DB_NAME"
echo "数据库用户: $DB_USER"
echo ""

# 检查是否安装了PostgreSQL客户端
if ! command -v psql &> /dev/null; then
    echo "错误: 未找到 psql 命令。请先安装 PostgreSQL 客户端。"
    echo "Ubuntu/Debian: sudo apt-get install postgresql-client"
    echo "macOS: brew install postgresql"
    exit 1
fi

# 创建.env文件（如果不存在）
if [ ! -f .env ]; then
    echo "创建 .env 文件..."
    cat > .env << EOF
# 数据库配置
DB_HOST=$DB_HOST
DB_PORT=$DB_PORT
DB_NAME=$DB_NAME
DB_USER=$DB_USER
DB_PASSWORD=$DB_PASSWORD
DB_MAX_CONNECTIONS=10

# API服务配置
API_PORT=8080
API_HOST=0.0.0.0

# 日志级别
RUST_LOG=info
EOF
    echo "✓ .env 文件已创建"
fi

# 函数：执行SQL命令
execute_sql() {
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $1 -c "$2" 2>/dev/null || true
}

# 函数：执行SQL文件
execute_sql_file() {
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $1 -f $2
}

# 创建数据库用户（如果不存在）
echo "检查数据库用户..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U postgres -tc "SELECT 1 FROM pg_user WHERE usename = '$DB_USER'" | grep -q 1 || {
    echo "创建数据库用户 $DB_USER..."
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U postgres -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';"
    echo "✓ 用户已创建"
}

# 创建数据库（如果不存在）
echo "检查数据库..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U postgres -tc "SELECT 1 FROM pg_database WHERE datname = '$DB_NAME'" | grep -q 1 || {
    echo "创建数据库 $DB_NAME..."
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
    echo "✓ 数据库已创建"
}

# 授予权限
echo "设置数据库权限..."
PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U postgres -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

# 创建必要的扩展
echo "创建数据库扩展..."
execute_sql $DB_NAME "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
execute_sql $DB_NAME "CREATE EXTENSION IF NOT EXISTS \"pgcrypto\";"
echo "✓ 扩展已创建"

# 创建基础表（如果需要）
echo "检查基础表..."
TABLE_EXISTS=$(execute_sql $DB_NAME "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'users');" | grep -c 't' || echo 0)

if [ "$TABLE_EXISTS" -eq 0 ]; then
    echo "创建基础表结构..."
    
    # 创建用户表
    execute_sql $DB_NAME "
    CREATE TABLE IF NOT EXISTS users (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        username VARCHAR(50) UNIQUE NOT NULL,
        email VARCHAR(255) UNIQUE NOT NULL,
        password_hash VARCHAR(255) NOT NULL,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );"
    
    # 创建账本表
    execute_sql $DB_NAME "
    CREATE TABLE IF NOT EXISTS ledgers (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(100) NOT NULL,
        description TEXT,
        currency VARCHAR(3) DEFAULT 'CNY',
        user_id UUID REFERENCES users(id),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );"
    
    # 创建分类表
    execute_sql $DB_NAME "
    CREATE TABLE IF NOT EXISTS categories (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        ledger_id UUID REFERENCES ledgers(id),
        name VARCHAR(100) NOT NULL,
        parent_id UUID REFERENCES categories(id),
        classification VARCHAR(20) NOT NULL,
        color VARCHAR(7),
        icon VARCHAR(50),
        description TEXT,
        position INTEGER DEFAULT 0,
        is_active BOOLEAN DEFAULT true,
        is_system BOOLEAN DEFAULT false,
        deleted_at TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );"
    
    # 创建标签表
    execute_sql $DB_NAME "
    CREATE TABLE IF NOT EXISTS tags (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        name VARCHAR(50) NOT NULL,
        color VARCHAR(7),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );"
    
    # 创建交易表
    execute_sql $DB_NAME "
    CREATE TABLE IF NOT EXISTS transactions (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        ledger_id UUID REFERENCES ledgers(id),
        user_id UUID REFERENCES users(id),
        category_id UUID REFERENCES categories(id),
        amount DECIMAL(19, 4) NOT NULL,
        currency VARCHAR(3) DEFAULT 'CNY',
        date DATE NOT NULL,
        description TEXT,
        tags UUID[],
        deleted_at TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );"
    
    echo "✓ 基础表已创建"
fi

# 创建更新时间戳的触发器函数
echo "创建触发器函数..."
execute_sql $DB_NAME "
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS \$\$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
\$\$ LANGUAGE plpgsql;"

# 运行迁移文件
echo ""
echo "运行数据库迁移..."

# 检查迁移目录
if [ ! -d "migrations" ]; then
    echo "警告: 未找到 migrations 目录"
else
    # 运行所有迁移文件
    for migration in migrations/*.sql; do
        if [ -f "$migration" ]; then
            echo "运行迁移: $(basename $migration)"
            execute_sql_file $DB_NAME "$migration" || {
                echo "警告: 迁移 $(basename $migration) 执行失败，可能已经应用过"
            }
        fi
    done
    echo "✓ 迁移完成"
fi

# 创建测试数据（可选）
read -p "是否要创建测试数据？(y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "创建测试数据..."
    
    # 创建测试用户
    execute_sql $DB_NAME "
    INSERT INTO users (id, username, email, password_hash) 
    VALUES ('11111111-1111-1111-1111-111111111111', 'testuser', 'test@example.com', 'hashed_password')
    ON CONFLICT DO NOTHING;"
    
    # 创建测试账本
    execute_sql $DB_NAME "
    INSERT INTO ledgers (id, name, description, user_id)
    VALUES ('22222222-2222-2222-2222-222222222222', '个人账本', '我的个人财务记录', '11111111-1111-1111-1111-111111111111')
    ON CONFLICT DO NOTHING;"
    
    echo "✓ 测试数据已创建"
fi

echo ""
echo "========================================="
echo "数据库设置完成！"
echo ""
echo "数据库连接信息："
echo "  主机: $DB_HOST"
echo "  端口: $DB_PORT"
echo "  数据库: $DB_NAME"
echo "  用户: $DB_USER"
echo ""
echo "连接字符串："
echo "  postgres://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
echo "========================================="