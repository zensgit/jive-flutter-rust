# Flutter Web Dockerfile
FROM ubuntu:22.04 AS builder

# 安装依赖
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# 安装 Flutter
ENV FLUTTER_VERSION=3.16.0
ENV FLUTTER_HOME=/flutter
ENV PATH=$FLUTTER_HOME/bin:$PATH

RUN git clone -b stable https://github.com/flutter/flutter.git $FLUTTER_HOME && \
    flutter precache && \
    flutter config --enable-web

WORKDIR /app

# 复制项目文件
COPY pubspec.yaml pubspec.lock ./

# 获取依赖
RUN flutter pub get

# 复制源代码
COPY . .

# 构建 Web 应用
RUN flutter build web --release

# 运行时镜像
FROM nginx:alpine

# 复制构建产物
COPY --from=builder /app/build/web /usr/share/nginx/html

# 复制 nginx 配置
COPY nginx-flutter.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]