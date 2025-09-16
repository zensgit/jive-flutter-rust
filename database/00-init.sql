-- 初始化数据库脚本
-- 这个脚本会在 Docker 容器第一次启动时自动执行

-- 确保使用正确的数据库
\c jive_money;

-- 执行其他初始化脚本（按顺序）
-- Docker 会自动执行 /docker-entrypoint-initdb.d 目录下的所有 .sql 文件