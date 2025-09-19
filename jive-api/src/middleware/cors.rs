//! CORS 配置中间件

use axum::http::{header, Method, HeaderName};
use tower_http::cors::CorsLayer; // 移除未使用的 Any
use std::time::Duration;

/// 创建 CORS 层
pub fn create_cors_layer() -> CorsLayer {
    // 可通过环境变量 CORS_DEV=1 启用完全开放（本地调试临时使用）
    let dev_mode = std::env::var("CORS_DEV").ok().as_deref() == Some("1");
    // 从环境变量获取允许的源
    let _cors_origin = std::env::var("CORS_ORIGIN")
        .unwrap_or_else(|_| "http://localhost:3021".to_string());
    
    let allow_credentials = std::env::var("CORS_ALLOW_CREDENTIALS")
        .unwrap_or_else(|_| "true".to_string())
        .parse::<bool>()
        .unwrap_or(true);
    
    // 在开发环境中，允许特定的源
    const ALLOWED_ORIGINS: [&str; 8] = [
        "http://localhost:3021",
        "http://localhost:3000", 
        "http://localhost:8080",
        "http://localhost:8081",
        "http://127.0.0.1:3021",
        "http://127.0.0.1:3000",
        "http://127.0.0.1:8080",
        "http://127.0.0.1:8081"
    ];
    
    if dev_mode {
        // Development: allow a set of common local origins (not wildcard) so that credentials are valid
        let origin_values = ALLOWED_ORIGINS
            .iter()
            .map(|o| o.parse::<axum::http::HeaderValue>().unwrap())
            .collect::<Vec<_>>();
        return CorsLayer::new()
            .allow_origin(origin_values)
            .allow_methods([
                Method::GET,
                Method::POST,
                Method::PUT,
                Method::DELETE,
                Method::OPTIONS,
                Method::PATCH,
            ])
            .allow_headers([
                header::CONTENT_TYPE,
                header::AUTHORIZATION,
                header::ACCEPT,
                header::ORIGIN,
                header::REFERER,
                header::USER_AGENT,
                HeaderName::from_static("x-app-version"),
                HeaderName::from_static("x-requested-with"),
                HeaderName::from_static("x-platform"),
                HeaderName::from_static("x-request-id"),
                HeaderName::from_static("x-timestamp"),
            ])
            .expose_headers([
                header::CONTENT_TYPE,
                header::AUTHORIZATION,
            ])
            .allow_credentials(allow_credentials)
            .max_age(Duration::from_secs(3600));
    }

    let cors = CorsLayer::new()
        .allow_origin(
            ALLOWED_ORIGINS
                .iter()
                .map(|origin| origin.parse::<axum::http::HeaderValue>().unwrap())
                .collect::<Vec<_>>()
        )
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::DELETE,
            Method::OPTIONS,
            Method::PATCH,
        ])
        .allow_headers([
            header::CONTENT_TYPE,
            header::AUTHORIZATION,
            header::ACCEPT,
            header::ORIGIN,
            header::REFERER,
            header::USER_AGENT,
            HeaderName::from_static("x-app-version"),
            HeaderName::from_static("x-requested-with"),
            HeaderName::from_static("x-platform"),
            HeaderName::from_static("x-request-id"),
            HeaderName::from_static("x-timestamp"),
        ])
        .expose_headers([
            header::CONTENT_TYPE,
            header::AUTHORIZATION,
        ])
        .allow_credentials(allow_credentials)
        .max_age(Duration::from_secs(3600));
    
    cors
}
