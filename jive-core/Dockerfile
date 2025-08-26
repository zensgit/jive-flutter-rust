# Rust API Dockerfile
FROM rust:1.75-alpine AS builder

# 安装依赖
RUN apk add --no-cache musl-dev openssl-dev pkgconfig

WORKDIR /app

# 复制依赖文件
COPY Cargo.toml Cargo.lock ./

# 构建依赖（缓存层）
RUN mkdir src && \
    echo "fn main() {}" > src/main.rs && \
    cargo build --release && \
    rm -rf src

# 复制源代码
COPY . .

# 构建应用
RUN cargo build --release

# 运行时镜像
FROM alpine:3.19

RUN apk add --no-cache openssl ca-certificates

WORKDIR /app

# 复制编译好的二进制文件
COPY --from=builder /app/target/release/jive-core /app/jive-core

# 创建非 root 用户
RUN adduser -D -u 1000 jive
USER jive

EXPOSE 8080

CMD ["./jive-core"]