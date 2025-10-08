#!/bin/bash

# Docker 镜像源配置脚本

echo "配置Docker国内镜像源..."

# 创建Docker配置目录
sudo mkdir -p /etc/docker

# 配置镜像源
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": [
    "https://docker.mirrors.ustc.edu.cn",
    "https://hub-mirror.c.163.com",
    "https://mirror.ccs.tencentyun.com",
    "https://registry.docker-cn.com",
    "https://dockerhub.azk8s.cn"
  ],
  "insecure-registries": [],
  "debug": false,
  "experimental": false,
  "features": {
    "buildkit": true
  }
}
EOF

echo "重启Docker服务..."
sudo systemctl daemon-reload
sudo systemctl restart docker

echo "验证配置..."
docker info

echo "Docker镜像源配置完成！"
echo "现在可以尝试: cd ~/jive-project/jive-api && ./docker-run.sh dev"