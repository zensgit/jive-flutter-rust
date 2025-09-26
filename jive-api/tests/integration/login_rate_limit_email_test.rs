#[cfg(test)]
mod tests {
    use axum::{routing::post, Router};
    use http::{Request, header, StatusCode};
    use hyper::Body;
    use tower::ServiceExt;
    use uuid::Uuid;
    use jive_money_api::{handlers::auth::login, AppMetrics, AppState};
    use jive_money_api::middleware::rate_limit::{RateLimiter, login_rate_limit};
    use crate::fixtures::create_test_pool;

    // Helper to insert a user
    async fn seed_user(pool: &sqlx::PgPool, email: &str) {
        sqlx::query("INSERT INTO users (email,password_hash,name,is_active,created_at,updated_at) VALUES ($1,'$argon2id$v=19$m=4096,t=3,p=1$dGVzdHNhbHQAAAAAAAAAAA$Jr7Z5fakehashHashHashHashHashHash','RL U',true,NOW(),NOW())")
            .bind(email).execute(pool).await.unwrap();
    }

    #[tokio::test]
    async fn rate_limit_is_per_email() {
        let pool = create_test_pool().await;
        let email1 = format!("rl_email1_{}@example.com", Uuid::new_v4());
        let email2 = format!("rl_email2_{}@example.com", Uuid::new_v4());
        seed_user(&pool, &email1).await;
        seed_user(&pool, &email2).await;
        let metrics = AppMetrics::new();
        let state = AppState { pool: pool.clone(), ws_manager: None, redis: None, metrics };
        let limiter = RateLimiter::new(3, 60); // 3 attempts per key
        let app = Router::new().route("/api/v1/auth/login", post(login).route_layer(
            axum::middleware::from_fn_with_state((limiter, state), login_rate_limit)
        ));

        // Email1: 3 attempts allowed, 4th blocked
        for i in 0..4 {
            let req = Request::builder().method("POST").uri("/api/v1/auth/login")
                .header(header::CONTENT_TYPE, "application/json")
                .body(Body::from(format!("{{\"email\":\"{}\",\"password\":\"Bad{}\"}}", email1, i)))
                .unwrap();
            let resp = app.clone().oneshot(req).await.unwrap();
            if i < 3 { assert_ne!(resp.status(), StatusCode::TOO_MANY_REQUESTS); } else { assert_eq!(resp.status(), StatusCode::TOO_MANY_REQUESTS); }
        }
        // Email2 still independent -> first attempt should be allowed
        let req2 = Request::builder().method("POST").uri("/api/v1/auth/login")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(format!("{{\"email\":\"{}\",\"password\":\"Bad\"}}", email2)))
            .unwrap();
        let resp2 = app.clone().oneshot(req2).await.unwrap();
        assert_ne!(resp2.status(), StatusCode::TOO_MANY_REQUESTS);
    }
}

