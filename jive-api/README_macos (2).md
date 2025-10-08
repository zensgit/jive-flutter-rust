Docker运行成功！

  现在的运行方式非常简单：

  🚀 启动所有服务

  cd ~/jive-project/jive-api
  ./start.sh

  🛑 停止所有服务

  ./stop.sh

  当前运行状态

  ✅ PostgreSQL数据库 - 端口 5433（Docker容器）
  ✅ Redis缓存 - 端口 6380（Docker容器）
  ✅ API服务 - 端口 8012（本地运行）

  服务地址

  - API健康检查: http://localhost:8012/health
  - 数据库管理: 可以使用Adminer或其他PostgreSQL客户端连接到 localhost:5433
  - Redis管理: 可以使用RedisInsight连接到 localhost:6380

  测试账户

  | 用途    | 邮箱                  | 密码       |
  |-------|---------------------|----------|
  | 超级管理员 | superadmin@jive.com | admin123 |
  | 测试用户  | test@example.com    | test123  |

  日常使用

  1. 查看容器状态
  docker ps
  2. 查看日志
  docker-compose -f docker-compose.macos.yml logs -f
  3. 重启服务
  ./stop.sh && ./start.sh
  4. 清理所有数据（谨慎使用）
  docker-compose -f docker-compose.macos.yml down -v

  所有服务都已正常运行！API可以正常访问了。