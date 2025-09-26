#[cfg(test)]
mod tests {
    use axum::{routing::{post, get}, Router};
    use http::{Request, header};
    use hyper::Body;
    use tower::ServiceExt;
    use serde_json::json;
    use uuid::Uuid;
    use chrono::NaiveDate;
    use rust_decimal::Decimal;

    use jive_money_api::handlers::transactions::{export_transactions, export_transactions_csv_stream};
    use jive_money_api::auth::Claims;
    use jive_money_api::AppState;

    use crate::fixtures::{create_test_pool, create_test_user, create_test_family};

    // Helper: bearer token
    async fn bearer_for(pool: &sqlx::PgPool, user_id: Uuid, family_id: Uuid) -> String {
        let claims = Claims::new(user_id, format!("test_{}@example.com", user_id), Some(family_id));
        format!("Bearer {}", claims.to_token().unwrap())
    }

    // Extract metric value from /metrics body (simple regex-less parse)
    fn find_metric(body: &str, name: &str) -> Option<u64> {
        for line in body.lines() {
            if line.starts_with('#') { continue; }
            if let Some(rest) = line.strip_prefix(name) {
                let parts: Vec<&str> = rest.trim().split_whitespace().collect();
                if let Some(val_str) = parts.last() {
                    if let Ok(v) = val_str.parse::<u64>() { return Some(v); }
                }
            }
        }
        None
    }

    #[tokio::test]
    async fn export_buffered_and_stream_metrics_increment() {
        // Use feature export_stream in test command to cover both paths; this test
        // tolerates absence of streaming feature by skipping that section if 404.
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let family = create_test_family(&pool, user.id).await;
        let token = bearer_for(&pool, user.id, family.id).await;

        // Seed default ledger id
        let default_ledger_id: Uuid = sqlx::query_scalar(
            "SELECT id FROM ledgers WHERE family_id = $1 AND is_default = true LIMIT 1"
        )
        .bind(family.id)
        .fetch_one(&pool)
        .await
        .expect("default ledger");

        // Seed account + a few transactions
        let account_id = Uuid::new_v4();
        sqlx::query(r#"INSERT INTO accounts (id, ledger_id, name, account_type, current_balance, created_at, updated_at)
                       VALUES ($1,$2,'Acct','checking',0,NOW(),NOW())"#)
            .bind(account_id)
            .bind(default_ledger_id)
            .execute(&pool).await.expect("insert account");

        for (idx, amt) in [1234, 5678, 9012].iter().enumerate() {
            let tx_id = Uuid::new_v4();
            sqlx::query(r#"INSERT INTO transactions (
                id, account_id, ledger_id, amount, transaction_type, transaction_date,
                description, status, is_recurring, created_at, updated_at)
                VALUES ($1,$2,$3,$4,'expense',$5,$6,'cleared',false,NOW(),NOW())"#)
                .bind(tx_id)
                .bind(account_id)
                .bind(default_ledger_id)
                .bind(Decimal::new(*amt, 2))
                .bind(NaiveDate::from_ymd_opt(2024, 9, 10 + idx as u32).unwrap())
                .bind(format!("Item{}", idx))
                .execute(&pool).await.expect("insert txn");
        }

        // Build AppState to expose metrics
        let state = AppState { pool: pool.clone(), ws_manager: None, redis: None, metrics: jive_money_api::AppMetrics::new() };
        let app = Router::new()
            .route("/api/v1/transactions/export", post(export_transactions))
            .route("/api/v1/transactions/export.csv", get(export_transactions_csv_stream))
            .route("/metrics", axum::routing::get(jive_money_api::metrics::metrics_handler))
            .with_state(state.clone());

        // Baseline metrics
        let m0 = app.clone().oneshot(Request::builder().uri("/metrics").body(Body::empty()).unwrap()).await.unwrap();
        assert_eq!(m0.status(), http::StatusCode::OK);
        let base_body = hyper::body::to_bytes(m0.into_body()).await.unwrap();
        let base = String::from_utf8(base_body.to_vec()).unwrap();
        let base_buf_req = find_metric(&base, "export_requests_buffered_total").unwrap_or(0);
        let base_buf_rows = find_metric(&base, "export_rows_buffered_total").unwrap_or(0);
        let base_stream_req = find_metric(&base, "export_requests_stream_total").unwrap_or(0);
        let base_stream_rows = find_metric(&base, "export_rows_stream_total").unwrap_or(0);

        // Buffered POST CSV
        let req_csv = Request::builder()
            .method("POST")
            .uri("/api/v1/transactions/export")
            .header(header::AUTHORIZATION, token.clone())
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(json!({"format":"csv"}).to_string()))
            .unwrap();
        let resp_csv = app.clone().oneshot(req_csv).await.unwrap();
        assert_eq!(resp_csv.status(), http::StatusCode::OK);

        // Buffered POST JSON
        let req_json = Request::builder()
            .method("POST")
            .uri("/api/v1/transactions/export")
            .header(header::AUTHORIZATION, token.clone())
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(json!({"format":"json"}).to_string()))
            .unwrap();
        let resp_json = app.clone().oneshot(req_json).await.unwrap();
        assert_eq!(resp_json.status(), http::StatusCode::OK);

        // Streaming GET (may be disabled). If 200, expect increments.
        let req_stream = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv")
            .header(header::AUTHORIZATION, token.clone())
            .body(Body::empty())
            .unwrap();
        let resp_stream = app.clone().oneshot(req_stream).await.unwrap();
        let streaming_enabled = resp_stream.status() == http::StatusCode::OK;
        if streaming_enabled {
            // drain body to ensure task completes
            let _ = hyper::body::to_bytes(resp_stream.into_body()).await.unwrap();
        }

        // Fetch metrics again
        let m1 = app.clone().oneshot(Request::builder().uri("/metrics").body(Body::empty()).unwrap()).await.unwrap();
        assert_eq!(m1.status(), http::StatusCode::OK);
        let body1 = hyper::body::to_bytes(m1.into_body()).await.unwrap();
        let txt1 = String::from_utf8(body1.to_vec()).unwrap();
        let buf_req_after = find_metric(&txt1, "export_requests_buffered_total").unwrap();
        let buf_rows_after = find_metric(&txt1, "export_rows_buffered_total").unwrap();
        assert_eq!(buf_req_after, base_buf_req + 2, "buffered request count mismatch");
        assert!(buf_rows_after >= base_buf_rows + 3, "expected at least 3 data rows added");
        if streaming_enabled {
            let stream_req_after = find_metric(&txt1, "export_requests_stream_total").unwrap();
            let stream_rows_after = find_metric(&txt1, "export_rows_stream_total").unwrap();
            assert_eq!(stream_req_after, base_stream_req + 1, "stream request count mismatch");
            assert!(stream_rows_after >= base_stream_rows + 3, "expected stream rows increment");
        }
    }
}

