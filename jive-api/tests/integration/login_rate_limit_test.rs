#[cfg(test)]
mod tests {
    use axum::{routing::post, Router};
    use http::{Request, header, StatusCode};
    use hyper::Body;
    use tower::ServiceExt;
    use jive_money_api::{handlers::auth::login, AppState, AppMetrics};
    use jive_money_api::middleware::rate_limit::{RateLimiter, login_rate_limit};
    use crate::fixtures::create_test_pool;
    use uuid::Uuid;

    #[tokio::test]
    async fn login_rate_limit_blocks_after_threshold() {
        let pool = create_test_pool().await;
        // Seed a user so we can attempt logins (with wrong password to avoid side effects)
        let email = format!("rl_{}@example.com", Uuid::new_v4());
        sqlx::query("INSERT INTO users (email,password_hash,name,is_active,created_at,updated_at) VALUES ($1,'$argon2id$v=19$m=4096,t=3,p=1$dGVzdHNhbHQAAAAAAAAAAA$Jr7Z5fakehashHashHashHashHashHash','RL User',true,NOW(),NOW())")
            .bind(&email).execute(&pool).await.unwrap();
        let metrics = AppMetrics::new();
        let state = AppState { pool: pool.clone(), ws_manager: None, redis: None, metrics: metrics.clone() };
        let limiter = RateLimiter::new(3, 60); // allow 3 attempts
        let app = Router::new()
            .route("/api/v1/auth/login", post(login).route_layer(
                axum::middleware::from_fn_with_state((limiter, state.clone()), login_rate_limit)
            ));

        // Perform 4 attempts -> last should be 429
        for i in 0..4 {
            let req = Request::builder().method("POST").uri("/api/v1/auth/login")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(format!("{{\"email\":\"{}\",\"password\":\"Bad{}\"}}", email, i)))
                .unwrap();
            let resp = app.clone().oneshot(req).await.unwrap();
            if i < 3 { assert_ne!(resp.status(), StatusCode::TOO_MANY_REQUESTS); } else { assert_eq!(resp.status(), StatusCode::TOO_MANY_REQUESTS); }
        }
    }
}

