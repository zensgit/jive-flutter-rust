#[cfg(test)]
mod tests {
    use axum::{routing::post, Router};
    use http::StatusCode;
    use hyper::Body;
    use tower::ServiceExt;

    use jive_money_api::handlers::auth::{login, refresh_token};

    use crate::fixtures::create_test_pool;

    async fn post_json(app: &Router, path: &str, body: serde_json::Value) -> http::Response<hyper::Body> {
        let req = http::Request::builder()
            .method("POST")
            .uri(path)
            .header(http::header::CONTENT_TYPE, "application/json")
            .body(Body::from(body.to_string()))
            .unwrap();
        app.clone().oneshot(req).await.unwrap()
    }

    #[tokio::test]
    async fn login_fails_with_wrong_password_bcrypt() {
        let pool = create_test_pool().await;
        let email = format!("bcrypt_fail_{}@example.com", uuid::Uuid::new_v4());
        let good_plain = "CorrectPass123!";
        let bcrypt_hash = bcrypt::hash(good_plain, bcrypt::DEFAULT_COST).unwrap();

        sqlx::query(
            r#"INSERT INTO users (email, password_hash, name, is_active, created_at, updated_at)
               VALUES ($1,$2,$3,true,NOW(),NOW())"#,
        )
        .bind(&email)
        .bind(&bcrypt_hash)
        .bind("Bcrypt Fail")
        .execute(&pool)
        .await
        .expect("insert bcrypt user");

        let app = Router::new()
            .route("/api/v1/auth/login", post(login))
            .with_state(pool.clone());

        // Wrong password
        let resp = post_json(&app, "/api/v1/auth/login", serde_json::json!({
            "email": email,
            "password": "BadPass999!",
        })).await;
        assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);

        // Cleanup
        sqlx::query("DELETE FROM users WHERE LOWER(email)=LOWER($1)")
            .bind(&email)
            .execute(&pool)
            .await
            .ok();
    }

    #[tokio::test]
    async fn refresh_fails_for_inactive_user() {
        let pool = create_test_pool().await;
        let email = format!("inactive_refresh_{}@example.com", uuid::Uuid::new_v4());

        // Create inactive user (argon2)
        let salt = argon2::password_hash::SaltString::generate(&mut argon2::password_hash::rand_core::OsRng);
        let argon2 = argon2::Argon2::default();
        let hash = argon2
            .hash_password("InactivePass123!".as_bytes(), &salt)
            .unwrap()
            .to_string();
        let user_id: uuid::Uuid = uuid::Uuid::new_v4();
        sqlx::query(
            r#"INSERT INTO users (id, email, password_hash, name, is_active, created_at, updated_at)
               VALUES ($1,$2,$3,$4,false,NOW(),NOW())"#,
        )
        .bind(user_id)
        .bind(&email)
        .bind(&hash)
        .bind("Inactive Refresh")
        .execute(&pool)
        .await
        .expect("insert inactive user");

        // Generate a JWT manually to simulate prior login (even though user inactive now)
        let token = jive_money_api::auth::generate_jwt(user_id, None).unwrap();

        let app = Router::new()
            .route("/api/v1/auth/refresh", post(refresh_token))
            .with_state(pool.clone());

        // Attempt refresh
        let req = http::Request::builder()
            .method("POST")
            .uri("/api/v1/auth/refresh")
            .header("Authorization", format!("Bearer {}", token))
            .body(Body::empty())
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::FORBIDDEN);

        sqlx::query("DELETE FROM users WHERE id = $1")
            .bind(user_id)
            .execute(&pool)
            .await
            .ok();
    }
}

