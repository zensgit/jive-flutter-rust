# Jive Money 数据库配置指南

## 概述
Jive Money 使用 PostgreSQL 作为主数据库，实现了完整的分类管理系统，包括三层分类架构（系统模板 → 用户分类 → 标签）。

## 快速开始

### 1. 安装 PostgreSQL
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install postgresql postgresql-contrib

# macOS
brew install postgresql
brew services start postgresql

# Arch Linux
sudo pacman -S postgresql
sudo systemctl start postgresql
```

### 2. 配置数据库

#### 方法 A: 使用自动化脚本
```bash
# 运行数据库设置脚本
chmod +x setup_database.sh
./setup_database.sh
```

#### 方法 B: 手动配置
```bash
# 登录 PostgreSQL
sudo -u postgres psql

# 创建用户和数据库
CREATE USER jive WITH PASSWORD 'jive_password';
CREATE DATABASE jive_money OWNER jive;
GRANT ALL PRIVILEGES ON DATABASE jive_money TO jive;

# 退出
\q
```

### 3. 运行迁移
```bash
# 使用 psql 运行迁移
export PGPASSWORD=jive_password
psql -h localhost -U jive -d jive_money -f migrations/002_category_system_enhancement.sql
```

## 数据库架构

### 核心表结构

#### 1. 分类组表 (category_groups)
- 管理系统分类模板的分组
- 包含9个预设分组：收入、日常消费、居住、交通等

#### 2. 系统分类模板表 (system_category_templates)
- 50+ 预设分类模板
- 支持多语言（中文/英文）
- 包含颜色、图标、标签等属性

#### 3. 用户分类表 (categories)
- 用户自定义分类
- 支持两层层级结构
- 可从系统模板导入

#### 4. 批量操作记录表 (category_batch_operations)
- 记录批量操作历史
- 支持24小时内撤销
- 包含操作类型、原始数据等

#### 5. 分类转换历史表 (category_conversions)
- 记录分类到标签的转换历史
- 保存转换选项和影响范围

#### 6. 分类使用统计表 (category_usage_stats)
- 跟踪分类使用频率
- 用于智能推荐和排序

## 环境变量配置

创建 `.env` 文件：
```env
# 数据库配置
DB_HOST=localhost
DB_PORT=5432
DB_NAME=jive_money
DB_USER=jive
DB_PASSWORD=jive_password
DB_MAX_CONNECTIONS=10

# API 配置
API_PORT=8080
API_HOST=0.0.0.0

# 日志级别
RUST_LOG=info
```

## 功能特性

### 分类管理功能
1. **三层架构**
   - 系统模板：50+ 预设分类
   - 用户分类：自定义分类
   - 标签：灵活的标记系统

2. **高级功能**
   - 拖拽排序
   - 批量操作
   - 分类转标签
   - 智能删除策略
   - 使用统计和推荐

3. **数据完整性**
   - 软删除机制
   - 24小时撤销窗口
   - 外键约束保护
   - 事务支持

## API 集成

### Rust 后端集成
```rust
use jive_core::infrastructure::repositories::CategoryRepository;
use sqlx::PgPool;
use std::sync::Arc;

// 创建数据库连接池
let pool = PgPool::connect("postgres://jive:jive_password@localhost/jive_money").await?;
let pool = Arc::new(pool);

// 创建仓储实例
let category_repo = CategoryRepository::new(pool.clone());

// 使用仓储
let categories = category_repo.find_by_ledger(ledger_id).await?;
```

### Flutter 前端集成
```dart
// 在设置页面访问分类管理
Navigator.pushNamed(context, '/settings/categories');

// 访问模板库
Navigator.pushNamed(context, '/category/templates');
```

## 测试数据

运行脚本时选择创建测试数据，将包含：
- 测试用户：testuser
- 测试账本：个人账本
- 基础分类结构

## 故障排除

### 常见问题

1. **连接失败**
   ```bash
   # 检查 PostgreSQL 服务状态
   sudo systemctl status postgresql
   
   # 检查端口
   sudo netstat -tlnp | grep 5432
   ```

2. **权限问题**
   ```sql
   -- 重新授权
   GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO jive;
   GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO jive;
   ```

3. **迁移失败**
   - 检查是否已运行过迁移
   - 确认数据库扩展已安装（uuid-ossp, pgcrypto）

## 维护建议

1. **定期备份**
   ```bash
   pg_dump -U jive -h localhost jive_money > backup_$(date +%Y%m%d).sql
   ```

2. **性能优化**
   - 定期运行 VACUUM ANALYZE
   - 监控慢查询
   - 适当调整连接池大小

3. **安全建议**
   - 使用强密码
   - 限制数据库访问IP
   - 定期更新 PostgreSQL

## 相关文件

- `migrations/002_category_system_enhancement.sql` - 分类系统增强迁移
- `jive-core/src/infrastructure/repositories/category_repository.rs` - 分类仓储实现
- `jive-api/src/db.rs` - 数据库连接管理
- `setup_database.sh` - 自动化设置脚本

## 支持

如遇到问题，请查看：
- 项目 Wiki
- GitHub Issues
- 开发者文档