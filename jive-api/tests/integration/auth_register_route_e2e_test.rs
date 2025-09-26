#[cfg(test)]
mod tests {
    use axum::{Router, routing::{post, get}};
    use http::{Request, header, StatusCode};
    use hyper::Body;
    use tower::ServiceExt; // for oneshot
    use serde_json::json;
    use uuid::Uuid;

    use jive_money_api::handlers::{auth, transactions::export_transactions_csv_stream};
    use crate::fixtures::create_test_pool;

    #[tokio::test]
    async fn register_route_creates_family_and_default_ledger_and_allows_export() {
        let pool = create_test_pool().await;

        // Build minimal router for the two endpoints under test
        let app = Router::new()
            .route("/api/v1/auth/register", post(auth::register))
            .route("/api/v1/transactions/export.csv", get(export_transactions_csv_stream))
            .with_state(pool.clone());

        // Unique username-style email (no @) to exercise username path as well
        let uname = format!("route_e2e_{}", Uuid::new_v4());
        let body = json!({
            "email": uname,
            "password": "RouteE2e123!",
            "name": "RouteE2E"
        });
        let req = Request::builder()
            .method("POST")
            .uri("/api/v1/auth/register")
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(body.to_string()))
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), StatusCode::OK, "register should return 200");

        let bytes = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&bytes).unwrap();
        let token = v.get("token").and_then(|x| x.as_str()).unwrap_or("");
        assert!(!token.is_empty(), "token should be present in register response");

        // Find created user_id from response and assert family/ledger rows
        let user_id: Uuid = serde_json::from_value(v.get("user_id").cloned().unwrap()).unwrap();

        // families.owner_id must equal user_id
        let fam_row: Option<(Uuid, Uuid)> = sqlx::query_as(
            "SELECT id, owner_id FROM families WHERE owner_id = $1 ORDER BY created_at DESC LIMIT 1"
        )
        .bind(user_id)
        .fetch_optional(&pool)
        .await
        .expect("query families");
        let (family_id, owner_id) = fam_row.expect("family created");
        assert_eq!(owner_id, user_id, "families.owner_id should equal user_id");

        // default ledger exists with created_by = user_id and is_default = true
        #[derive(sqlx::FromRow, Debug)]
        struct LedgerRow { id: Uuid, is_default: Option<bool>, created_by: Option<Uuid> }
        let ledgers: Vec<LedgerRow> = sqlx::query_as(
            "SELECT id, is_default, created_by FROM ledgers WHERE family_id = $1"
        )
        .bind(family_id)
        .fetch_all(&pool)
        .await
        .expect("query ledgers");
        assert_eq!(ledgers.len(), 1, "exactly one default ledger expected");
        let l = &ledgers[0];
        assert_eq!(l.is_default.unwrap_or(false), true, "ledger should be default");
        assert_eq!(l.created_by.unwrap(), user_id, "ledger.created_by should equal user_id");

        // Now call export.csv using the token; expect header-only CSV
        let req2 = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv?include_header=true")
            .header(header::AUTHORIZATION, format!("Bearer {}", token))
            .body(Body::empty())
            .unwrap();
        let resp2 = app.clone().oneshot(req2).await.unwrap();
        assert_eq!(resp2.status(), StatusCode::OK, "export.csv should be 200");
        let body_bytes = hyper::body::to_bytes(resp2.into_body()).await.unwrap();
        let head = String::from_utf8_lossy(&body_bytes);
        assert!(head.starts_with("Date,Description"), "CSV header missing or incorrect");

        // Cleanup user rows (cascade should remove memberships/related rows)
        let _ = sqlx::query("DELETE FROM users WHERE id = $1")
            .bind(user_id)
            .execute(&pool)
            .await;
    }
}

