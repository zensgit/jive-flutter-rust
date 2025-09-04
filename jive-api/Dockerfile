# 多阶段构建，支持 ARM64 (M4 Mac) 和 AMD64 (Ubuntu) 架构
# 构建阶段
FROM --platform=$BUILDPLATFORM rust:latest as builder

# 安装构建依赖
RUN apt-get update && apt-get install -y \
    pkg-config \
    libssl-dev \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# 设置工作目录
WORKDIR /app

# 复制 Cargo 文件
COPY Cargo.toml Cargo.lock ./

# 创建虚拟文件以缓存依赖
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    echo "fn main() {}" > src/main_simple.rs && \
    echo "fn main() {}" > src/main_simple_ws.rs && \
    echo "fn main() {}" > src/main_with_ws.rs && \
    cargo build --release --bin jive-api && \
    rm -rf src

# 复制源代码
COPY src ./src
COPY .env .env.example ./

# 构建应用（禁用SQLx编译时检查）
ENV SQLX_OFFLINE=false
RUN touch src/main.rs && \
    cargo build --release --bin jive-api

# 运行阶段
FROM --platform=$TARGETPLATFORM debian:bookworm-slim

# 安装运行时依赖
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libssl3 \
    libpq5 \
    curl \
    && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户
RUN useradd -m -u 1001 -s /bin/bash jive

# 设置工作目录
WORKDIR /app

# 从构建阶段复制二进制文件
COPY --from=builder /app/target/release/jive-api /app/jive-api

# 复制配置文件
COPY --from=builder /app/.env.example /app/.env.example

# 创建必要的目录
RUN mkdir -p /app/logs /app/static && \
    chown -R jive:jive /app

# 切换到非 root 用户
USER jive

# 环境变量
ENV RUST_LOG=info \
    API_PORT=8012 \
    HOST=0.0.0.0

# 暴露端口
EXPOSE 8012

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8012/health || exit 1

# 启动应用
CMD ["./jive-api"]