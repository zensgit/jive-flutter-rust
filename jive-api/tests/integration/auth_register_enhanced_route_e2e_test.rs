#[cfg(test)]
mod tests {
    use axum::{Router, routing::{post, get}};
    use http::{Request, header, StatusCode};
    use hyper::Body;
    use tower::ServiceExt; // for oneshot
    use serde_json::json;
    use uuid::Uuid;

    use jive_money_api::handlers::{enhanced_profile::register_with_preferences, transactions::export_transactions_csv_stream};
    use crate::fixtures::create_test_pool;

    #[tokio::test]
    async fn register_enhanced_route_creates_family_and_allows_export() {
        let pool = create_test_pool().await;

        let app = Router::new()
            .route("/api/v1/auth/register-enhanced", post(register_with_preferences))
            .route("/api/v1/transactions/export.csv", get(export_transactions_csv_stream))
            .with_state(pool.clone());

        let email = format!("enh_{}@example.com", Uuid::new_v4());
        let body = json!({
            "email": email,
            "password": "EnhE2e123!",
            "name": "EnhE2E",
            "country": "CN",
            "currency": "CNY",
            "language": "zh-CN",
            "timezone": "Asia/Shanghai",
            "date_format": "YYYY-MM-DD"
        });

        let req = Request::builder()
            .method("POST")
            .uri("/api/v1/auth/register-enhanced")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(body.to_string()))
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::OK, "register-enhanced should return 200");
        let bytes = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        let token = v.pointer("/data/token").and_then(|x| x.as_str()).unwrap_or("");
        assert!(!token.is_empty(), "token should be present");

        let req2 = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv?include_header=true")
            .header(header::AUTHORIZATION, format!("Bearer {}", token))
            .body(Body::empty())
            .unwrap();
        let resp2 = app.clone().oneshot(req2).await.unwrap();
        assert_eq!(resp2.status(), StatusCode::OK);
        let body_bytes = hyper::body::to_bytes(resp2.into_body()).await.unwrap();
        assert!(body_bytes.starts_with(b"Date,Description"), "CSV header missing or incorrect");
    }
}

