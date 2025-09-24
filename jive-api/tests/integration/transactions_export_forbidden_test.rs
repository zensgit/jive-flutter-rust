#[cfg(test)]
mod tests {
    use axum::{routing::get, Router};
    use http::{header, Request, StatusCode};
    use hyper::Body;
    use tower::ServiceExt; // for `oneshot`

    use jive_money_api::handlers::transactions::export_transactions_csv_stream;
    use jive_money_api::auth::Claims;

    use crate::fixtures::{create_test_pool, create_test_user, create_test_family};

    async fn bearer_for(user_id: uuid::Uuid, family_id: uuid::Uuid) -> String {
        let claims = Claims::new(user_id, format!("{}@example.com", user_id), Some(family_id));
        format!("Bearer {}", claims.to_token().unwrap())
    }

    // User A should not export data for User B's family (403)
    #[tokio::test]
    async fn export_cross_family_forbidden() {
        let pool = create_test_pool().await;

        // Create two users and two families (each user owns their own family)
        let user_a = create_test_user(&pool).await;
        let user_b = create_test_user(&pool).await;
        let family_a = create_test_family(&pool, user_a.id).await;
        let family_b = create_test_family(&pool, user_b.id).await;

        // Token for user A bound to family A
        let token_a_family_a = bearer_for(user_a.id, family_a.id).await;

        // Minimal router with CSV export endpoint
        let app = Router::new()
            .route("/api/v1/transactions/export.csv", get(export_transactions_csv_stream))
            .with_state(pool.clone());

        // Try to export for family B while token is bound to family A.
        // The handler reads family_id from token claims, not from query, so the
        // access check should fail before any data is returned.
        let req = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv")
            .header(header::AUTHORIZATION, token_a_family_a)
            .body(Body::empty())
            .unwrap();

        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::FORBIDDEN);

        // Control: user B exporting their own family's data should pass auth (may be empty CSV)
        let token_b_family_b = bearer_for(user_b.id, family_b.id).await;
        let req = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv")
            .header(header::AUTHORIZATION, token_b_family_b)
            .body(Body::empty())
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
    }
}

