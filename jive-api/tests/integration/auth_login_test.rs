#[cfg(test)]
mod tests {
    use axum::{routing::post, Router};
    use http::StatusCode;
    use hyper::Body;
    use tower::ServiceExt; // for `oneshot`

    use jive_money_api::handlers::auth::login;

    use crate::fixtures::create_test_pool;

    async fn post_json(app: Router, path: &str, body: serde_json::Value) -> http::Response<hyper::Body> {
        let req = http::Request::builder()
            .method("POST")
            .uri(path)
            .header(http::header::CONTENT_TYPE, "application/json")
            .body(Body::from(body.to_string()))
            .unwrap();
        app.oneshot(req).await.unwrap()
    }

    #[tokio::test]
    async fn login_succeeds_with_bcrypt_hash() {
        let pool = create_test_pool().await;

        // Arrange: insert a user with bcrypt-hashed password
        let email = format!("bcrypt_user_{}@example.com", uuid::Uuid::new_v4());
        let plain = "BcryptPass123!";
        let hash = bcrypt::hash(plain, bcrypt::DEFAULT_COST).expect("hash bcrypt");

        sqlx::query(
            r#"
            INSERT INTO users (email, password_hash, name, is_active, created_at, updated_at)
            VALUES ($1, $2, $3, true, NOW(), NOW())
            "#,
        )
        .bind(&email)
        .bind(&hash)
        .bind("Bcrypt User")
        .execute(&pool)
        .await
        .expect("insert bcrypt user");

        let app = Router::new()
            .route("/api/v1/auth/login", post(login))
            .with_state(pool.clone());

        // Act: login with correct password
        let resp = post_json(
            app,
            "/api/v1/auth/login",
            serde_json::json!({
                "email": email,
                "password": plain,
            }),
        )
        .await;

        // Assert
        assert_eq!(resp.status(), StatusCode::OK);
        let bytes = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        assert!(v.get("token").and_then(|t| t.as_str()).is_some(), "token missing: {:?}", v);

        // Cleanup
        sqlx::query("DELETE FROM users WHERE LOWER(email) = LOWER($1)")
            .bind(&v["email"].as_str().unwrap_or("").to_string())
            .execute(&pool)
            .await
            .ok();
    }

    #[tokio::test]
    async fn login_forbidden_when_user_inactive() {
        let pool = create_test_pool().await;

        // Arrange: insert an inactive user with Argon2 hash
        let email = format!("inactive_user_{}@example.com", uuid::Uuid::new_v4());
        let plain = "InactivePass123!";

        let salt = argon2::password_hash::SaltString::generate(&mut argon2::password_hash::rand_core::OsRng);
        let argon2 = argon2::Argon2::default();
        let hash = argon2
            .hash_password(plain.as_bytes(), &salt)
            .unwrap()
            .to_string();

        sqlx::query(
            r#"
            INSERT INTO users (email, password_hash, name, is_active, created_at, updated_at)
            VALUES ($1, $2, $3, false, NOW(), NOW())
            "#,
        )
        .bind(&email)
        .bind(&hash)
        .bind("Inactive User")
        .execute(&pool)
        .await
        .expect("insert inactive user");

        let app = Router::new()
            .route("/api/v1/auth/login", post(login))
            .with_state(pool.clone());

        // Act: login attempt should be forbidden regardless of password correctness
        let resp = post_json(
            app,
            "/api/v1/auth/login",
            serde_json::json!({
                "email": email,
                "password": plain,
            }),
        )
        .await;

        // Assert
        assert_eq!(resp.status(), StatusCode::FORBIDDEN);

        // Cleanup
        sqlx::query("DELETE FROM users WHERE LOWER(email) = LOWER($1)")
            .bind(&email)
            .execute(&pool)
            .await
            .ok();
    }
}

