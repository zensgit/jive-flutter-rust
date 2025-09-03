//! CORS 配置中间件

use axum::http::{header, Method};
use tower_http::cors::{CorsLayer, AllowOrigin};

/// 创建 CORS 层
pub fn create_cors_layer() -> CorsLayer {
    // 从环境变量获取允许的源
    let cors_origin = std::env::var("CORS_ORIGIN")
        .unwrap_or_else(|_| "http://localhost:3021".to_string());
    
    let allow_credentials = std::env::var("CORS_ALLOW_CREDENTIALS")
        .unwrap_or_else(|_| "true".to_string())
        .parse::<bool>()
        .unwrap_or(true);
    
    let cors = CorsLayer::new()
        .allow_origin(
            cors_origin
                .parse::<axum::http::HeaderValue>()
                .map(AllowOrigin::exact)
                .unwrap_or_else(|_| AllowOrigin::any())
        )
        .allow_methods([
            Method::GET,
            Method::POST,
            Method::PUT,
            Method::DELETE,
            Method::OPTIONS,
        ])
        .allow_headers([
            header::CONTENT_TYPE,
            header::AUTHORIZATION,
            header::ACCEPT,
            header::ORIGIN,
        ])
        .allow_credentials(allow_credentials)
        .max_age(std::time::Duration::from_secs(3600));
    
    cors
}