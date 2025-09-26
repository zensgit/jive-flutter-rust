#[cfg(test)]
mod tests {
    use axum::{routing::post, Router};
    use http::{Request, header, StatusCode};
    use hyper::Body;
    use tower::ServiceExt;
    use uuid::Uuid;

    use jive_money_api::handlers::auth::login;
    use crate::fixtures::create_test_pool;

    // Verifies bcrypt hash upgraded to argon2id after login (if REHASH_ON_LOGIN enabled).
    #[tokio::test]
    async fn bcrypt_login_triggers_rehash() {
        // Ensure rehash on login enabled
        std::env::set_var("REHASH_ON_LOGIN", "1");
        let pool = create_test_pool().await;
        let email = format!("rehash_user_{}@example.com", Uuid::new_v4());
        let password = "Rehash123!";
        let bcrypt_hash = bcrypt::hash(password, bcrypt::DEFAULT_COST).unwrap();

        sqlx::query("INSERT INTO users (email,password_hash,name,is_active,created_at,updated_at) VALUES ($1,$2,$3,true,NOW(),NOW())")
            .bind(&email)
            .bind(&bcrypt_hash)
            .bind("Rehash User")
            .execute(&pool)
            .await
            .expect("insert bcrypt user");

        let app = Router::new()
            .route("/api/v1/auth/login", post(login))
            .with_state(pool.clone());

        let req = Request::builder()
            .method("POST")
            .uri("/api/v1/auth/login")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(format!("{{\"email\":\"{}\",\"password\":\"{}\"}}", email, password)))
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::OK);

        // Fetch updated hash
        let row = sqlx::query("SELECT password_hash FROM users WHERE LOWER(email)=LOWER($1)")
            .bind(&email)
            .fetch_one(&pool)
            .await
            .expect("fetch user");
        let new_hash: String = row.try_get("password_hash").unwrap();
        assert!(new_hash.starts_with("$argon2id$"), "hash not upgraded: {}", new_hash);

        // Cleanup
        sqlx::query("DELETE FROM users WHERE LOWER(email)=LOWER($1)")
            .bind(&email)
            .execute(&pool)
            .await
            .ok();
    }
}

