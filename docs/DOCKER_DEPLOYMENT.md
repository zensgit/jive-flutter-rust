# Docker部署设计与测试文档

## 设计概述

Docker容器化部署方案，包含以下组件：
- PostgreSQL数据库
- Redis缓存
- Rust API服务器
- Flutter Web前端
- Nginx反向代理
- 自动备份服务

## 架构设计

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Browser   │────▶│    Nginx    │────▶│  Flutter    │
└─────────────┘     └─────────────┘     │    Web      │
                            │            └─────────────┘
                            │
                            ▼
                    ┌─────────────┐
                    │   Rust API  │
                    └─────────────┘
                            │
                    ┌───────┴───────┐
                    ▼               ▼
            ┌─────────────┐ ┌─────────────┐
            │  PostgreSQL │ │    Redis    │
            └─────────────┘ └─────────────┘
```

## 文件结构

```
jive-flutter-rust/
├── docker-compose.yml          # Docker编排配置
├── .env.example                # 环境变量示例
├── jive-api/
│   └── Dockerfile             # API服务镜像
├── jive-flutter/
│   ├── Dockerfile             # Flutter Web镜像
│   └── nginx.conf             # Web服务Nginx配置
└── nginx/
    ├── nginx.conf             # 主Nginx配置
    └── sites-enabled/
        └── jive.conf          # 站点配置
```

## 部署步骤

### 1. 环境准备
```bash
# 复制环境变量配置
cp .env.example .env

# 编辑配置（修改密码等敏感信息）
vim .env
```

### 2. 构建和启动服务
```bash
# 构建所有服务
docker-compose build

# 启动基础服务（数据库、缓存、API、Web）
docker-compose up -d

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f api
```

### 3. 生产环境部署
```bash
# 包含Nginx和备份服务
docker-compose --profile production --profile backup up -d

# 验证所有服务
docker-compose ps
```

## 测试验证

### 1. 健康检查
```bash
# API健康检查
curl http://localhost:8012/health

# Web健康检查  
curl http://localhost:8080/

# Nginx健康检查（生产环境）
curl http://localhost/health
```

### 2. 数据库连接测试
```bash
# 进入PostgreSQL容器
docker exec -it jive-postgres psql -U jive -d jive_money

# 查看表结构
\dt

# 退出
\q
```

### 3. Redis连接测试
```bash
# 进入Redis容器
docker exec -it jive-redis redis-cli

# 测试命令
PING
# 应返回: PONG

# 退出
exit
```

### 4. API功能测试
```bash
# 注册用户
curl -X POST http://localhost:8012/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123456!",
    "name": "Test User"
  }'

# 登录
curl -X POST http://localhost:8012/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123456!"
  }'
```

### 5. 备份测试
```bash
# 手动触发备份
docker exec jive-backup sh -c "pg_dump -h postgres -U jive -d jive_money > /backups/manual_backup.sql"

# 验证备份文件
ls -la ./backups/
```

## 性能优化

### 1. 资源限制
在docker-compose.yml中添加：
```yaml
services:
  api:
    deploy:
      resources:
        limits:
          cpus: '2'
          memory: 1G
        reservations:
          cpus: '0.5'
          memory: 256M
```

### 2. 缓存配置
- Nginx缓存API响应：1分钟
- Redis缓存会话：24小时
- 静态资源缓存：1年

### 3. 连接池
- PostgreSQL：10个连接
- Redis：自动管理

## 监控建议

### 1. 日志收集
```bash
# 查看所有服务日志
docker-compose logs

# 实时查看特定服务
docker-compose logs -f api

# 导出日志
docker-compose logs > logs/docker.log
```

### 2. 资源监控
```bash
# 查看容器资源使用
docker stats

# 查看特定容器
docker stats jive-api
```

### 3. 数据库监控
```sql
-- 连接数
SELECT count(*) FROM pg_stat_activity;

-- 慢查询
SELECT query, calls, mean_exec_time 
FROM pg_stat_statements 
ORDER BY mean_exec_time DESC 
LIMIT 10;
```

## 故障排查

### 1. 服务无法启动
```bash
# 检查端口占用
lsof -i:8012
lsof -i:5432

# 查看详细日志
docker-compose logs api | grep ERROR
```

### 2. 数据库连接失败
```bash
# 验证网络
docker network ls
docker network inspect jive-flutter-rust_jive-network

# 测试连接
docker exec jive-api ping postgres
```

### 3. 性能问题
```bash
# 查看容器资源
docker stats --no-stream

# 检查数据库性能
docker exec -it jive-postgres psql -U jive -c "SELECT * FROM pg_stat_database;"
```

## 安全建议

1. **修改默认密码**
   - 数据库密码
   - JWT密钥
   - Redis密码（如需要）

2. **限制端口暴露**
   - 生产环境只暴露80/443端口
   - 数据库和Redis不对外暴露

3. **定期备份**
   - 自动备份每天执行
   - 保留7天历史备份
   - 定期测试恢复流程

4. **SSL/TLS配置**
   - 使用Let's Encrypt获取证书
   - 在nginx配置中启用HTTPS

## 扩展方案

### 水平扩展API服务
```yaml
api:
  deploy:
    replicas: 3
```

### 数据库主从复制
参考PostgreSQL官方文档配置streaming replication

### 添加监控服务
```yaml
prometheus:
  image: prom/prometheus:latest
  # ...配置

grafana:
  image: grafana/grafana:latest
  # ...配置
```

## 总结

Docker部署方案提供了：
- ✅ 完整的容器化部署
- ✅ 服务健康检查
- ✅ 自动备份机制
- ✅ 生产环境配置
- ✅ 性能优化设置
- ✅ 安全最佳实践

测试状态：**已完成设计，待实际部署验证**