# Flutter Web Build Stage
FROM ghcr.io/cirruslabs/flutter:stable AS web

# Set working directory
WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy source code
COPY lib ./lib
COPY web ./web
COPY assets ./assets

# Build for web
RUN flutter build web --release --web-renderer html

# Production Web Server
FROM nginx:alpine AS production

# Copy built web app
COPY --from=web /app/build/web /usr/share/nginx/html

# Copy nginx configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port
EXPOSE 80

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# Start nginx
CMD ["nginx", "-g", "daemon off;"]