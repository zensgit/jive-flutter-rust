#[cfg(test)]
mod tests {
    use axum::{routing::post, Router};
    use http::{Request, header, StatusCode};
    use hyper::Body;
    use tower::ServiceExt;

    use jive_money_api::{handlers::auth::login, AppMetrics, AppState};
    use crate::fixtures::create_test_pool;
    use uuid::Uuid;

    fn extract_metric(body: &str, name: &str) -> Option<u64> {
        body.lines().filter(|l| !l.starts_with('#')).find_map(|l| {
            if l.starts_with(name) {
                l.split_whitespace().last()?.parse().ok()
            } else { None }
        })
    }

    #[tokio::test]
    async fn login_fail_and_inactive_counters_increment() {
        let pool = create_test_pool().await;
        let metrics = AppMetrics::new();
        let state = AppState { pool: pool.clone(), ws_manager: None, redis: None, metrics: metrics.clone() };
        let app = Router::new()
            .route("/api/v1/auth/login", post(login))
            .route("/metrics", axum::routing::get(jive_money_api::metrics::metrics_handler))
            .with_state(state.clone());

        // Seed one inactive user (is_active=false)
        let email_inactive = format!("inactive_{}@example.com", Uuid::new_v4());
        sqlx::query("INSERT INTO users (email,password_hash,name,is_active,created_at,updated_at) VALUES ($1,$2,$3,false,NOW(),NOW())")
            .bind(&email_inactive)
            .bind("$argon2id$v=19$m=4096,t=3,p=1$ZmFrZVNhbHQAAAAAAAAAAA$1YJzJ6x3P0fakefakefakefakefakefakefake")
            .bind("Inactive User")
            .execute(&pool).await.expect("insert inactive");

        // 1) Unknown user login -> fail counter
        let req_fail = Request::builder().method("POST").uri("/api/v1/auth/login")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from("{\"email\":\"nouser@example.com\",\"password\":\"X\"}"))
            .unwrap();
        let resp_fail = app.clone().oneshot(req_fail).await.unwrap();
        assert_eq!(resp_fail.status(), StatusCode::UNAUTHORIZED);

        // 2) Inactive user login -> inactive counter
        let req_inactive = Request::builder().method("POST").uri("/api/v1/auth/login")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(format!("{{\"email\":\"{}\",\"password\":\"whatever\"}}", email_inactive)))
            .unwrap();
        let resp_inactive = app.clone().oneshot(req_inactive).await.unwrap();
        assert_eq!(resp_inactive.status(), StatusCode::FORBIDDEN);

        // Fetch metrics
        let mreq = Request::builder().uri("/metrics").body(Body::empty()).unwrap();
        let mresp = app.clone().oneshot(mreq).await.unwrap();
        assert_eq!(mresp.status(), StatusCode::OK);
        let body = hyper::body::to_bytes(mresp.into_body()).await.unwrap();
        let txt = String::from_utf8(body.to_vec()).unwrap();
        let fail = extract_metric(&txt, "auth_login_fail_total").unwrap_or(0);
        let inactive = extract_metric(&txt, "auth_login_inactive_total").unwrap_or(0);
        assert!(fail >= 1, "expected fail >=1, got {}", fail);
        assert!(inactive >= 1, "expected inactive >=1, got {}", inactive);
    }
}

