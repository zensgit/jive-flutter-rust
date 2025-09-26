#[cfg(test)]
mod tests {
    use axum::{routing::post, Router};
    use http::{Request, header, StatusCode};
    use hyper::Body;
    use tower::ServiceExt;
    use uuid::Uuid;

    use jive_money_api::handlers::auth::login;
    use jive_money_api::{AppMetrics, AppState};

    use crate::fixtures::create_test_pool;

    // Simulate rehash failure by using a read-only role for the UPDATE step (one approach).
    // Here we instead force failure by deleting the user between verify and update in parallel thread.
    #[tokio::test]
    async fn rehash_failure_increments_fail_counter() {
        std::env::set_var("REHASH_ON_LOGIN", "1");
        let pool = create_test_pool().await;
        let metrics = AppMetrics::new();
        let state = AppState { pool: pool.clone(), ws_manager: None, redis: None, metrics: metrics.clone() };

        let email = format!("rehash_fail_{}@example.com", Uuid::new_v4());
        let password = "Fail123!";
        let bcrypt_hash = bcrypt::hash(password, bcrypt::DEFAULT_COST).unwrap();
        sqlx::query("INSERT INTO users (email,password_hash,name,is_active,created_at,updated_at) VALUES ($1,$2,'RF User',true,NOW(),NOW())")
            .bind(&email)
            .bind(&bcrypt_hash)
            .execute(&pool)
            .await
            .expect("insert user");

        // Spawn a task that deletes the user right after a short delay to race the UPDATE
        let pool_del = pool.clone();
        let email_del = email.clone();
        tokio::spawn(async move {
            // Small sleep to let handler pass password verify
            tokio::time::sleep(std::time::Duration::from_millis(30)).await;
            let _ = sqlx::query("DELETE FROM users WHERE LOWER(email)=LOWER($1)")
                .bind(&email_del)
                .execute(&pool_del).await;
        });

        let app = Router::new()
            .route("/api/v1/auth/login", post(login))
            .with_state(state.clone());

        let req = Request::builder()
            .method("POST")
            .uri("/api/v1/auth/login")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(format!("{{\"email\":\"{}\",\"password\":\"{}\"}}", email, password)))
            .unwrap();
        let _ = app.clone().oneshot(req).await; // success or unauthorized both fine

        // Fail counter should be >=1 (may also have no success increment since user removed)
        assert!(metrics.get_rehash_fail() >= 1, "rehash_fail_count not incremented");
    }
}

