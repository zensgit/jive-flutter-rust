#[cfg(test)]
mod tests {
    use axum::{routing::get, Router};
    use http::Request;
    use hyper::Body;
    use tower::ServiceExt; // for `oneshot`
    use rust_decimal::Decimal;
    use chrono::{Utc, Duration};

    use jive_money_api::services::currency_service::{CurrencyService, AddExchangeRateRequest};
    use jive_money_api::handlers::{currency_handler_enhanced};
    use crate::fixtures::create_test_pool;

    // HTTP-level test: spin a minimal router and hit the endpoint
    #[tokio::test]
    async fn manual_overrides_http_200() {
        let pool = create_test_pool().await;

        // Seed one manual override for today (USD->CNY)
        let svc = CurrencyService::new(pool.clone());
        let _ = svc
            .add_exchange_rate(AddExchangeRateRequest {
                from_currency: "USD".into(),
                to_currency: "CNY".into(),
                rate: Decimal::new(71234, 4), // 7.1234
                source: Some("manual".into()),
                manual_rate_expiry: Some(Utc::now() + Duration::days(1)),
            })
            .await
            .expect("seed manual override");

        // Build minimal app with the route under test
        let app = Router::new()
            .route(
                "/api/v1/currencies/manual-overrides",
                get(currency_handler_enhanced::get_manual_overrides),
            )
            .with_state(pool.clone());

        let req = Request::builder()
            .method("GET")
            .uri("/api/v1/currencies/manual-overrides?base_currency=USD")
            .body(Body::empty())
            .unwrap();

        let resp = app.oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);

        // Optionally read body to ensure structure contains data
        let bytes = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let text = String::from_utf8(bytes.to_vec()).unwrap();
        assert!(text.contains("\"overrides\""));
        assert!(text.contains("CNY"));
    }
}

