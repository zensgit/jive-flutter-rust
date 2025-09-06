//! CORS 配置中间件

use axum::http::{header, Method, HeaderName};
use tower_http::cors::CorsLayer;

/// 创建 CORS 层
pub fn create_cors_layer() -> CorsLayer {
    // 从环境变量获取允许的源
    let _cors_origin = std::env::var("CORS_ORIGIN")
        .unwrap_or_else(|_| "http://localhost:3021".to_string());
    
    let allow_credentials = std::env::var("CORS_ALLOW_CREDENTIALS")
        .unwrap_or_else(|_| "true".to_string())
        .parse::<bool>()
        .unwrap_or(true);
    
    // 在开发环境中，允许特定的源
    let allowed_origins = vec![
        "http://localhost:3021",
        "http://localhost:3000", 
        "http://127.0.0.1:3021",
        "http://127.0.0.1:3000"
    ];
    
    let cors = CorsLayer::new()
        .allow_origin(
            allowed_origins
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
        .max_age(std::time::Duration::from_secs(3600));
    
    cors
}