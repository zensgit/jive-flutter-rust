#![cfg(feature = "export_stream")]
#[cfg(test)]
mod tests {
    use axum::{Router, routing::get};
    use http::{Request, header, StatusCode};
    use hyper::Body;
    use tower::ServiceExt;
    use jive_money_api::handlers::transactions::export_transactions_csv_stream;
    use jive_money_api::auth::Claims;
    use uuid::Uuid;
    use jive_money_api::services::auth_service::{AuthService, RegisterRequest};
    use jive_money_api::services::FamilyService;
    use crate::fixtures::create_test_pool;

    // Minimal streaming smoke test: ensures endpoint returns 200 and non-empty body when header enabled.
    #[tokio::test]
    async fn streaming_export_smoke() {
        let pool = create_test_pool().await;
        let auth = AuthService::new(pool.clone());
        let user_ctx = auth.register_with_family(RegisterRequest { email: format!("stream_{}@example.com", Uuid::new_v4()), password: "Stream123!".into(), name: Some("Streamer".into()), username: None }).await.expect("register");
        let family_id = user_ctx.current_family_id.unwrap();
        // Insert one transaction (need at least one ledger & account; register_with_family created a ledger but may need account)
        // For simplicity rely on existing ledger and create a bare account.
        let ledger_id: (Uuid,) = sqlx::query_as("SELECT id FROM ledgers WHERE family_id=$1 LIMIT 1")
            .bind(family_id).fetch_one(&pool).await.expect("ledger");
        let account_id = Uuid::new_v4();
        sqlx::query("INSERT INTO accounts (id,ledger_id,name,account_type,currency,current_balance,created_at,updated_at) VALUES ($1,$2,'SAcc','cash','CNY',0,NOW(),NOW())")
            .bind(account_id).bind(ledger_id.0).execute(&pool).await.expect("account");
        sqlx::query("INSERT INTO transactions (id,ledger_id,account_id,transaction_type,amount,currency,transaction_date,description,created_at,updated_at) VALUES ($1,$2,$3,'expense',10,'CNY',CURRENT_DATE,'Test',NOW(),NOW())")
            .bind(Uuid::new_v4()).bind(ledger_id.0).bind(account_id).execute(&pool).await.expect("txn");

        let claims = Claims::new(user_ctx.user_id, user_ctx.email.clone(), Some(family_id));
        let token = claims.to_token().unwrap();

        let app = Router::new()
            .route("/api/v1/transactions/export.csv", get(export_transactions_csv_stream))
            .with_state(pool.clone());

        let req = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv?include_header=true")
            .header(header::AUTHORIZATION, format!("Bearer {}", token))
            .body(Body::empty())
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::OK);
        let body_bytes = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        assert!(body_bytes.starts_with(b"Date,Description"), "CSV header missing or incorrect");
    }
}

