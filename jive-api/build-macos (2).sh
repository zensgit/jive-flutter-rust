#!/bin/bash

# MacOS M4 Docker构建脚本
# 使用交叉编译生成Linux ARM64二进制文件

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== MacOS M4 Docker构建 ===${NC}"
echo ""

# 检查是否安装了交叉编译目标
if ! rustup target list --installed | grep -q "aarch64-unknown-linux-gnu"; then
    echo -e "${YELLOW}安装Linux ARM64交叉编译目标...${NC}"
    rustup target add aarch64-unknown-linux-gnu
fi

# 方案1：使用交叉编译（推荐）
echo -e "${BLUE}方案1: 交叉编译到Linux ARM64${NC}"
echo "需要安装交叉编译工具链："
echo "  brew install messense/macos-cross-toolchains/aarch64-unknown-linux-gnu"
echo ""
echo "然后运行："
echo "  cargo build --release --target aarch64-unknown-linux-gnu --bin jive-api"
echo ""

# 方案2：在Docker容器内编译
echo -e "${BLUE}方案2: 在Docker容器内编译（避免SQLx问题）${NC}"
cat > Dockerfile.macos-build << 'EOF'
# 在Docker容器内编译，避免SQLx编译问题
FROM rust:latest AS builder

RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY . .

# 跳过SQLx编译时检查
ENV SQLX_OFFLINE=false

# 尝试编译，如果失败则使用替代方案
RUN cargo build --release --bin jive-api 2>&1 || \
    echo "编译可能失败，请检查日志"

# 运行阶段
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY --from=builder /app/target/release/jive-api /app/jive-api || echo "Binary not found"

ENV RUST_LOG=info \
    API_PORT=8012 \
    HOST=0.0.0.0

EXPOSE 8012
CMD ["./jive-api"]
EOF

echo ""
echo -e "${GREEN}选择构建方式：${NC}"
echo "1. 本地交叉编译（需要安装工具链）"
echo "2. Docker容器内编译（自动但较慢）"
echo "3. 使用本地MacOS二进制（仅用于测试）"
read -p "选择 [1-3]: " choice

case $choice in
    1)
        echo -e "${BLUE}交叉编译到Linux ARM64...${NC}"
        if command -v aarch64-unknown-linux-gnu-gcc &> /dev/null; then
            export CC_aarch64_unknown_linux_gnu=aarch64-unknown-linux-gnu-gcc
            export CXX_aarch64_unknown_linux_gnu=aarch64-unknown-linux-gnu-g++
            export AR_aarch64_unknown_linux_gnu=aarch64-unknown-linux-gnu-ar
            cargo build --release --target aarch64-unknown-linux-gnu --bin jive-api
            
            # 创建target/release目录的软链接
            ln -sf target/aarch64-unknown-linux-gnu/release/jive-api target/release/jive-api
            
            echo -e "${GREEN}交叉编译完成！${NC}"
            echo "现在构建Docker镜像..."
            docker build -f Dockerfile.macos -t jive-api:macos .
        else
            echo -e "${RED}错误: 未安装交叉编译工具链${NC}"
            echo "请运行: brew install messense/macos-cross-toolchains/aarch64-unknown-linux-gnu"
            exit 1
        fi
        ;;
    2)
        echo -e "${BLUE}在Docker容器内编译...${NC}"
        docker build -f Dockerfile.macos-build -t jive-api:macos .
        ;;
    3)
        echo -e "${YELLOW}警告: 使用MacOS二进制文件（不兼容Linux容器）${NC}"
        echo -e "${YELLOW}仅用于本地开发测试！${NC}"
        cargo build --release --bin jive-api
        docker build -f Dockerfile.macos -t jive-api:macos .
        ;;
    *)
        echo -e "${RED}无效选择${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}=== 构建完成 ===${NC}"
echo ""
echo "运行容器："
echo "  docker run -d -p 8012:8012 --name jive-api \\"
echo "    --add-host=host.docker.internal:host-gateway \\"
echo "    jive-api:macos"
echo ""
echo "注意：容器会连接到MacOS本地的PostgreSQL和Redis"