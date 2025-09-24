#[cfg(test)]
mod tests {
    use axum::{routing::{post, get}, Router};
    use http::{Request, header, StatusCode};
    use hyper::Body;
    use tower::ServiceExt; // for `oneshot`

    use jive_money_api::handlers::transactions::{export_transactions, export_transactions_csv_stream};

    use crate::fixtures::create_test_pool;

    #[tokio::test]
    async fn export_requires_auth() {
        let pool = create_test_pool().await;
        let app = Router::new()
            .route("/api/v1/transactions/export", post(export_transactions))
            .route("/api/v1/transactions/export.csv", get(export_transactions_csv_stream))
            .with_state(pool.clone());

        // POST without Authorization
        let req = Request::builder()
            .method("POST")
            .uri("/api/v1/transactions/export")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from("{}"))
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);

        // GET without Authorization
        let req = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv")
            .body(Body::empty())
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::UNAUTHORIZED);
    }
}

