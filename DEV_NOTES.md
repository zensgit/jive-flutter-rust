# 开发环境说明

## macOS开发（本地API）
```bash
# 1. 启动本地服务
cd jive-api
cargo run  # API运行在 localhost:8012

# 2. Flutter配置
# lib/core/config/api_config.dart
# baseUrl: 'http://localhost:8012'

# 3. 数据库连接
# DATABASE_URL=postgresql://postgres:postgres@localhost:5432/jive_money
```

## Ubuntu开发（Docker API）
```bash
# 1. 启动Docker服务
cd jive-api
docker-compose -f docker-compose.dev.yml up -d

# 2. Flutter配置
# lib/core/config/api_config.dart
# baseUrl: 'http://localhost:18012'

# 3. 数据库连接
# DATABASE_URL=postgresql://postgres:postgres@localhost:15432/jive_money
```

## 重要提示
- **不要提交**端口配置修改到Git
- 每个系统使用独立的数据库实例
- API功能在两个环境中保持一致

## 测试账户
- Email: superadmin@jive.money
- Password: admin123

## 切换系统时
1. macOS → Ubuntu: 运行 `./switch-env.sh`
2. Ubuntu → macOS: 手动修改端口配置或运行脚本