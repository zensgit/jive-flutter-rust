#[cfg(test)]
mod tests {
    use axum::{routing::{post, get}, Router};
    use http::{Request, header};
    use hyper::Body;
    use tower::ServiceExt; // for `oneshot`
    use serde_json::json;
    use uuid::Uuid;
    use rust_decimal::Decimal;
    use chrono::NaiveDate;

    use jive_money_api::handlers::transactions::{export_transactions, export_transactions_csv_stream};
    use jive_money_api::services::auth_service::AuthService;
    use jive_money_api::models::permission::{Permission, MemberRole};
    use jive_money_api::auth::Claims;

    use crate::fixtures::{create_test_pool, create_test_user, create_test_family};

    // Helper to mint a Bearer token for tests
    async fn bearer_for_user_family(pool: &sqlx::PgPool, user_id: Uuid, family_id: Uuid) -> String {
        // In this codebase, Claims::new + to_token is sufficient; membership checks happen in handler
        let claims = Claims::new(user_id, format!("test_{}@example.com", user_id), Some(family_id));
        format!("Bearer {}", claims.to_token().unwrap())
    }

    #[tokio::test]
    async fn export_post_csv_and_json_ok() {
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let family = create_test_family(&pool, user.id).await;
        let token = bearer_for_user_family(&pool, user.id, family.id).await;

        // Seed minimal transaction rows in two ledgers to test filters
        // First, get default ledger id of the family
        let default_ledger_id: Uuid = sqlx::query_scalar(
            "SELECT id FROM ledgers WHERE family_id = $1 AND is_default = true LIMIT 1"
        )
        .bind(family.id)
        .fetch_one(&pool)
        .await
        .expect("fetch default ledger");

        // Create a secondary ledger
        let second_ledger_id = Uuid::new_v4();
        sqlx::query(
            r#"INSERT INTO ledgers (id, family_id, name, currency, owner_id, is_default, created_at, updated_at)
               VALUES ($1,$2,'Second','CNY',$3,false,NOW(),NOW())"#
        )
        .bind(second_ledger_id)
        .bind(family.id)
        .bind(user.id)
        .execute(&pool)
        .await
        .expect("seed second ledger");

        // Seed accounts for both ledgers
        let account_id = Uuid::new_v4();
        let txn_id = Uuid::new_v4();
        sqlx::query(r#"
            INSERT INTO accounts (id, ledger_id, name, account_type, current_balance, created_at, updated_at)
            VALUES ($1, $2, 'Test', 'checking', 0, NOW(), NOW())
        "#)
        .bind(account_id)
        .bind(default_ledger_id)
        .execute(&pool)
        .await
        .expect("seed account");

        sqlx::query(r#"
            INSERT INTO transactions (
                id, account_id, ledger_id, amount, transaction_type, transaction_date,
                description, status, is_recurring, created_at, updated_at
            ) VALUES ($1,$2,$3,$4,'expense',$5,'Lunch','cleared',false,NOW(),NOW())
        "#)
        .bind(txn_id)
        .bind(account_id)
        .bind(default_ledger_id)
        .bind(Decimal::new(1234, 2))
        .bind(NaiveDate::from_ymd_opt(2024, 9, 1).unwrap())
        .execute(&pool)
        .await
        .expect("seed transaction");

        // Seed another transaction in second ledger and out-of-range date
        let account2_id = Uuid::new_v4();
        let txn2_id = Uuid::new_v4();
        sqlx::query(r#"
            INSERT INTO accounts (id, ledger_id, name, account_type, current_balance, created_at, updated_at)
            VALUES ($1, $2, 'Test2', 'checking', 0, NOW(), NOW())
        "#)
        .bind(account2_id)
        .bind(second_ledger_id)
        .execute(&pool)
        .await
        .expect("seed account2");

        sqlx::query(r#"
            INSERT INTO transactions (
                id, account_id, ledger_id, amount, transaction_type, transaction_date,
                description, status, is_recurring, created_at, updated_at
            ) VALUES ($1,$2,$3,$4,'expense',$5,'Dinner','cleared',false,NOW(),NOW())
        "#)
        .bind(txn2_id)
        .bind(account2_id)
        .bind(second_ledger_id)
        .bind(Decimal::new(5678, 2))
        .bind(NaiveDate::from_ymd_opt(2024, 10, 1).unwrap())
        .execute(&pool)
        .await
        .expect("seed transaction2");

        // Build minimal app with routes under test
        let app = Router::new()
            .route("/api/v1/transactions/export", post(export_transactions))
            .route("/api/v1/transactions/export.csv", get(export_transactions_csv_stream))
            .with_state(pool.clone());

        // POST CSV
        let req = Request::builder()
            .method("POST")
            .uri("/api/v1/transactions/export")
            .header(header::AUTHORIZATION, token.clone())
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(json!({"format":"csv"}).to_string()))
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let headers_post_csv = resp.headers().clone();
        let body = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(v["success"], true);
        let url = v["download_url"].as_str().unwrap_or("");
        assert!(url.starts_with("data:text/csv"), "unexpected mime prefix: {}", url);
        assert!(url.contains("base64,"), "missing base64 marker: {}", url);
        // Validate base64 decodes and matches size
        let b64_idx = url.rfind("base64,").unwrap() + "base64,".len();
        let b64_part = &url[b64_idx..];
        let decoded = base64::engine::general_purpose::STANDARD.decode(b64_part).unwrap();
        let size = v["size"].as_u64().unwrap_or(0) as usize;
        assert_eq!(decoded.len(), size);
        // CSV should include header row
        let csv_text = String::from_utf8(decoded).unwrap();
        assert!(csv_text.starts_with("Date,"));
        // POST CSV should include X-Audit-Id header
        let audit_hdr = headers_post_csv.get("x-audit-id").expect("missing X-Audit-Id for POST CSV");
        let audit_str = audit_hdr.to_str().unwrap();
        assert!(Uuid::parse_str(audit_str).is_ok(), "invalid X-Audit-Id: {}", audit_str);

        // POST JSON
        let req = Request::builder()
            .method("POST")
            .uri("/api/v1/transactions/export")
            .header(header::AUTHORIZATION, token.clone())
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(json!({"format":"json"}).to_string()))
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let headers_post_json = resp.headers().clone();
        let body = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(v["success"], true);
        let url = v["download_url"].as_str().unwrap_or("");
        assert!(url.starts_with("data:application/json"));
        assert!(url.contains("base64,"));
        let b64_idx = url.rfind("base64,").unwrap() + "base64,".len();
        let b64_part = &url[b64_idx..];
        let decoded = base64::engine::general_purpose::STANDARD.decode(b64_part).unwrap();
        let _json: serde_json::Value = serde_json::from_slice(&decoded).unwrap();
        // POST JSON should include X-Audit-Id header
        let audit_hdr = headers_post_json.get("x-audit-id").expect("missing X-Audit-Id for POST JSON");
        let audit_str = audit_hdr.to_str().unwrap();
        assert!(Uuid::parse_str(audit_str).is_ok(), "invalid X-Audit-Id: {}", audit_str);

        // GET CSV streaming (also validate filename header)
        let req = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv")
            .header(header::AUTHORIZATION, token.clone())
            .body(Body::empty())
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let headers = resp.headers();
        assert_eq!(headers.get(header::CONTENT_TYPE).unwrap(), "text/csv; charset=utf-8");
        let cd = headers.get(header::CONTENT_DISPOSITION).unwrap().to_str().unwrap();
        assert!(cd.starts_with("attachment; filename=\"transactions_export_"));
        assert!(cd.ends_with(".csv\""));
        // X-Audit-Id header should be present and a valid UUID
        let audit = headers.get("x-audit-id").expect("missing X-Audit-Id header");
        let audit_str = audit.to_str().unwrap();
        assert!(Uuid::parse_str(audit_str).is_ok(), "invalid X-Audit-Id: {}", audit_str);

        // Filter: by ledger_id should include only rows for that ledger
        let req = Request::builder()
            .method("GET")
            .uri(&format!("/api/v1/transactions/export.csv?ledger_id={}", default_ledger_id))
            .header(header::AUTHORIZATION, token.clone())
            .body(Body::empty())
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let body = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let csv_text = String::from_utf8(body.to_vec()).unwrap();
        // header + 1 data row expected
        assert!(csv_text.lines().count() >= 2);
        assert!(csv_text.contains("Lunch"));
        assert!(!csv_text.contains("Dinner"));

        // Filter: date range to exclude the 2024-10-01 row
        let req = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv?start_date=2024-09-01&end_date=2024-09-30")
            .header(header::AUTHORIZATION, token)
            .body(Body::empty())
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let body = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let csv_text = String::from_utf8(body.to_vec()).unwrap();
        assert!(csv_text.contains("Lunch"));
        assert!(!csv_text.contains("Dinner"));

        // JSON payload field shape and date format check
        let req = Request::builder()
            .method("POST")
            .uri("/api/v1/transactions/export")
            .header(header::AUTHORIZATION, token_clone_for_json(&pool, user.id, family.id).await)
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(json!({"format":"json","start_date":"2024-09-01","end_date":"2024-09-30"}).to_string()))
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let body = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&body).unwrap();
        let url = v["download_url"].as_str().unwrap();
        let b64_idx = url.rfind("base64,").unwrap() + "base64,".len();
        let decoded = base64::engine::general_purpose::STANDARD.decode(&url[b64_idx..]).unwrap();
        let payload: serde_json::Value = serde_json::from_slice(&decoded).unwrap();
        assert!(payload.is_array());
        let first = &payload.as_array().unwrap()[0];
        // Expected keys
        for k in [
            "id","account_id","ledger_id","amount","transaction_type","transaction_date",
            "category_id","category_name","payee_id","payee_name","description","notes"
        ] { assert!(first.get(k).is_some(), "missing key: {}", k); }
        // Date format YYYY-MM-DD (serde default for NaiveDate)
        assert!(first["transaction_date"].as_str().unwrap().starts_with("2024-"));
    }

    #[tokio::test]
    async fn export_filters_account_and_category() {
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let family = create_test_family(&pool, user.id).await;
        let token = bearer_for_user_family(&pool, user.id, family.id).await;

        let ledger_id: Uuid = sqlx::query_scalar(
            "SELECT id FROM ledgers WHERE family_id = $1 AND is_default = true LIMIT 1"
        ).bind(family.id).fetch_one(&pool).await.expect("ledger");

        // Accounts
        let acc1 = Uuid::new_v4();
        let acc2 = Uuid::new_v4();
        for (acc, name) in [(acc1, "A1"), (acc2, "A2")] {
            sqlx::query("INSERT INTO accounts (id, ledger_id, name, account_type, current_balance, created_at, updated_at) VALUES ($1,$2,$3,'checking',0,NOW(),NOW())")
                .bind(acc).bind(ledger_id).bind(name).execute(&pool).await.expect("seed acc");
        }
        // Category
        let cat = Uuid::new_v4();
        sqlx::query("INSERT INTO categories (id, ledger_id, name, category_type, created_at, updated_at) VALUES ($1,$2,'CatX','expense',NOW(),NOW())")
            .bind(cat).bind(ledger_id).execute(&pool).await.expect("seed cat");

        // Txns
        sqlx::query("INSERT INTO transactions (id, account_id, ledger_id, amount, transaction_type, transaction_date, category_id, description, status, is_recurring, created_at, updated_at) VALUES ($1,$2,$3,$4,'expense',$5,$6,'X1','cleared',false,NOW(),NOW())")
            .bind(Uuid::new_v4()).bind(acc1).bind(ledger_id).bind(Decimal::new(100,0)).bind(NaiveDate::from_ymd_opt(2024,9,5).unwrap()).bind(cat)
            .execute(&pool).await.expect("txn1");
        sqlx::query("INSERT INTO transactions (id, account_id, ledger_id, amount, transaction_type, transaction_date, description, status, is_recurring, created_at, updated_at) VALUES ($1,$2,$3,$4,'expense',$5,'Y2','cleared',false,NOW(),NOW())")
            .bind(Uuid::new_v4()).bind(acc2).bind(ledger_id).bind(Decimal::new(200,0)).bind(NaiveDate::from_ymd_opt(2024,9,6).unwrap())
            .execute(&pool).await.expect("txn2");

        let app = Router::new()
            .route("/api/v1/transactions/export.csv", get(export_transactions_csv_stream))
            .with_state(pool.clone());

        // Filter by account_id = acc1 => should contain X1 not Y2
        let req = Request::builder().method("GET")
            .uri(&format!("/api/v1/transactions/export.csv?account_id={}", acc1))
            .header(header::AUTHORIZATION, token.clone())
            .body(Body::empty()).unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let csv = String::from_utf8(hyper::body::to_bytes(resp.into_body()).await.unwrap().to_vec()).unwrap();
        assert!(csv.contains("X1"));
        assert!(!csv.contains("Y2"));

        // Filter by category_id = cat => should contain X1 only
        let req = Request::builder().method("GET")
            .uri(&format!("/api/v1/transactions/export.csv?category_id={}", cat))
            .header(header::AUTHORIZATION, token)
            .body(Body::empty()).unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let csv = String::from_utf8(hyper::body::to_bytes(resp.into_body()).await.unwrap().to_vec()).unwrap();
        assert!(csv.contains("X1"));
        assert!(!csv.contains("Y2"));
    }

    #[tokio::test]
    async fn export_csv_injection_safety() {
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let family = create_test_family(&pool, user.id).await;
        let token = bearer_for_user_family(&pool, user.id, family.id).await;

        let ledger_id: Uuid = sqlx::query_scalar(
            "SELECT id FROM ledgers WHERE family_id = $1 AND is_default = true LIMIT 1"
        )
        .bind(family.id)
        .fetch_one(&pool)
        .await
        .expect("fetch default ledger");

        let account_id = Uuid::new_v4();
        sqlx::query(r#"
            INSERT INTO accounts (id, ledger_id, name, account_type, current_balance, created_at, updated_at)
            VALUES ($1, $2, 'Exp', 'checking', 0, NOW(), NOW())
        "#)
        .bind(account_id)
        .bind(ledger_id)
        .execute(&pool)
        .await
        .expect("seed account");

        // Description beginning with '=' to test Excel injection prevention
        sqlx::query(r#"
            INSERT INTO transactions (
                id, account_id, ledger_id, amount, transaction_type, transaction_date,
                description, status, is_recurring, created_at, updated_at
            ) VALUES ($1,$2,$3,$4,'expense',$5,'=HYPERLINK(""http://evil"";""x"")','cleared',false,NOW(),NOW())
        "#)
        .bind(Uuid::new_v4())
        .bind(account_id)
        .bind(ledger_id)
        .bind(Decimal::new(100, 0))
        .bind(NaiveDate::from_ymd_opt(2024, 9, 2).unwrap())
        .execute(&pool)
        .await
        .expect("seed injection row");

        let app = Router::new()
            .route("/api/v1/transactions/export.csv", get(export_transactions_csv_stream))
            .with_state(pool.clone());

        let req = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv")
            .header(header::AUTHORIZATION, token)
            .body(Body::empty())
            .unwrap();
        let resp = app.oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let body = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let csv_text = String::from_utf8(body.to_vec()).unwrap();
        // Expect a leading single quote in CSV cell to neutralize formula
        assert!(csv_text.contains("'=HYPERLINK"));
        // Expect internal quotes escaped by doubling
        assert!(csv_text.contains("\"\"http://evil\"\""));
    }

    // Helper to mint a token in nested scope where `token` is moved
    async fn token_clone_for_json(pool: &sqlx::PgPool, user_id: Uuid, family_id: Uuid) -> String {
        bearer_for_user_family(pool, user_id, family_id).await
    }

    #[tokio::test]
    async fn export_csv_escape_commas_and_quotes() {
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let family = create_test_family(&pool, user.id).await;
        let token = bearer_for_user_family(&pool, user.id, family.id).await;

        let ledger_id: Uuid = sqlx::query_scalar(
            "SELECT id FROM ledgers WHERE family_id = $1 AND is_default = true LIMIT 1"
        )
        .bind(family.id)
        .fetch_one(&pool)
        .await
        .expect("fetch default ledger");

        let category_id = Uuid::new_v4();
        sqlx::query(r#"
            INSERT INTO categories (id, ledger_id, name, category_type, created_at, updated_at)
            VALUES ($1,$2,'Food, Dining','expense',NOW(),NOW())
        "#)
        .bind(category_id)
        .bind(ledger_id)
        .execute(&pool)
        .await
        .expect("seed category");

        let payee_id = Uuid::new_v4();
        sqlx::query(r#"
            INSERT INTO payees (id, family_id, name, created_at, updated_at)
            VALUES ($1,$2,'He said ""Hi""',NOW(),NOW())
        "#)
        .bind(payee_id)
        .bind(family.id)
        .execute(&pool)
        .await
        .expect("seed payee");

        let account_id = Uuid::new_v4();
        sqlx::query(r#"
            INSERT INTO accounts (id, ledger_id, name, account_type, current_balance, created_at, updated_at)
            VALUES ($1,$2,'EscTest','checking',0,NOW(),NOW())
        "#)
        .bind(account_id)
        .bind(ledger_id)
        .execute(&pool)
        .await
        .expect("seed account");

        sqlx::query(r#"
            INSERT INTO transactions (
                id, account_id, ledger_id, amount, transaction_type, transaction_date,
                category_id, payee_id, description, status, is_recurring, created_at, updated_at
            ) VALUES ($1,$2,$3,$4,'expense',$5,$6,$7,'Comma & Quote','cleared',false,NOW(),NOW())
        "#)
        .bind(Uuid::new_v4())
        .bind(account_id)
        .bind(ledger_id)
        .bind(Decimal::new(2500, 2))
        .bind(NaiveDate::from_ymd_opt(2024, 9, 3).unwrap())
        .bind(category_id)
        .bind(payee_id)
        .execute(&pool)
        .await
        .expect("seed txn");

        let app = Router::new()
            .route("/api/v1/transactions/export.csv", get(export_transactions_csv_stream))
            .with_state(pool.clone());

        let req = Request::builder()
            .method("GET")
            .uri("/api/v1/transactions/export.csv")
            .header(header::AUTHORIZATION, token)
            .body(Body::empty())
            .unwrap();
        let resp = app.oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let body = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let csv_text = String::from_utf8(body.to_vec()).unwrap();
        // Category with comma should be quoted as a single field
        assert!(csv_text.contains("\"Food, Dining\""));
        // Payee with quotes should have doubled quotes and be quoted as a single field
        assert!(csv_text.contains("\"He said \"\"Hi\"\"\""));
    }

    #[tokio::test]
    async fn export_requires_permission() {
        let pool = create_test_pool().await;
        // Create owner and family (owner has ExportData by default)
        let owner = create_test_user(&pool).await;
        let family = create_test_family(&pool, owner.id).await;

        // Create a viewer (no ExportData permission by default)
        let viewer = create_test_user(&pool).await;
        let viewer_perms = MemberRole::Viewer.default_permissions();
        let perms_json = serde_json::to_value(&viewer_perms).unwrap();
        sqlx::query(
            r#"
            INSERT INTO family_members (family_id, user_id, role, permissions, invited_by, joined_at)
            VALUES ($1, $2, $3, $4, $5, NOW())
            "#
        )
        .bind(family.id)
        .bind(viewer.id)
        .bind("viewer")
        .bind(perms_json)
        .bind(owner.id)
        .execute(&pool)
        .await
        .expect("seed viewer membership");

        let token = bearer_for_user_family(&pool, viewer.id, family.id).await;

        // Build minimal app
        let app = Router::new()
            .route("/api/v1/transactions/export", post(export_transactions))
            .with_state(pool.clone());

        let req = Request::builder()
            .method("POST")
            .uri("/api/v1/transactions/export")
            .header(header::AUTHORIZATION, token.clone())
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(json!({"format":"csv"}).to_string()))
            .unwrap();
        let resp = app.oneshot(req).await.unwrap();
        // Viewer should be forbidden to export
        assert_eq!(resp.status(), http::StatusCode::FORBIDDEN);
    }

    #[tokio::test]
    async fn export_indexes_present_and_explain_plan() {
        use chrono::NaiveDate;
        let pool = create_test_pool().await;

        // 1) Check presence of export-related indexes on transactions
        let rows = sqlx::query_as::<_, (String, String)>(
            r#"SELECT indexname, indexdef
               FROM pg_indexes
               WHERE schemaname = 'public' AND tablename = 'transactions'"#
        )
        .fetch_all(&pool)
        .await
        .expect("query pg_indexes");
        let names: Vec<String> = rows.iter().map(|(n, _)| n.clone()).collect();
        assert!(names.iter().any(|n| n == "idx_transactions_export"), "missing idx_transactions_export");
        assert!(names.iter().any(|n| n == "idx_transactions_date"), "missing idx_transactions_date");
        assert!(names.iter().any(|n| n == "idx_transactions_export_covering"), "missing idx_transactions_export_covering");

        // 2) Seed minimal data and print EXPLAIN plan for a typical export query
        let user = create_test_user(&pool).await;
        let family = create_test_family(&pool, user.id).await;
        let ledger_id: Uuid = sqlx::query_scalar(
            "SELECT id FROM ledgers WHERE family_id = $1 AND is_default = true LIMIT 1"
        )
        .bind(family.id)
        .fetch_one(&pool)
        .await
        .expect("fetch default ledger");

        // Ensure there is at least one transaction in range
        let account_id = Uuid::new_v4();
        sqlx::query(
            r#"INSERT INTO accounts (id, ledger_id, name, account_type, current_balance, created_at, updated_at)
               VALUES ($1,$2,'IdxTest','checking',0,NOW(),NOW())
            "#
        )
        .bind(account_id)
        .bind(ledger_id)
        .execute(&pool)
        .await
        .expect("seed idx account");

        sqlx::query(
            r#"INSERT INTO transactions (
                    id, account_id, ledger_id, amount, transaction_type, transaction_date,
                    description, status, is_recurring, created_at, updated_at
                ) VALUES ($1,$2,$3,$4,'expense',$5,'IdxPlan','cleared',false,NOW(),NOW())
            "#
        )
        .bind(Uuid::new_v4())
        .bind(account_id)
        .bind(ledger_id)
        .bind(Decimal::new(1000, 2))
        .bind(NaiveDate::from_ymd_opt(2024, 9, 15).unwrap())
        .execute(&pool)
        .await
        .expect("seed idx txn");

        // Print an EXPLAIN plan (no assertions on plan to avoid brittleness)
        let plans: Vec<String> = sqlx::query_scalar(
            r#"EXPLAIN (ANALYZE, BUFFERS)
                SELECT t.transaction_date, t.amount, t.description, t.category_id, t.account_id
                FROM transactions t
                JOIN ledgers l ON t.ledger_id = l.id
                WHERE t.deleted_at IS NULL
                  AND l.family_id = $1
                  AND t.transaction_date >= $2 AND t.transaction_date <= $3
                ORDER BY t.transaction_date DESC"#
        )
        .bind(family.id)
        .bind(NaiveDate::from_ymd_opt(2024, 9, 1).unwrap())
        .bind(NaiveDate::from_ymd_opt(2024, 10, 31).unwrap())
        .fetch_all(&pool)
        .await
        .expect("explain export query");
        for line in plans { println!("EXPLAIN: {}", line); }
    }

    #[tokio::test]
    async fn audit_list_and_cleanup_endpoints() {
        use jive_money_api::handlers::transactions::export_transactions;
        use axum::routing::post;

        let pool = create_test_pool().await;
        // Owner creates family; has ViewAuditLog + ManageSettings by default
        let owner = create_test_user(&pool).await;
        let family = create_test_family(&pool, owner.id).await;
        let token = bearer_for_user_family(&pool, owner.id, family.id).await;

        // Seed a trivial txn to allow export
        let ledger_id: Uuid = sqlx::query_scalar(
            "SELECT id FROM ledgers WHERE family_id = $1 AND is_default = true LIMIT 1"
        ).bind(family.id).fetch_one(&pool).await.unwrap();
        let acc = Uuid::new_v4();
        sqlx::query("INSERT INTO accounts (id, ledger_id, name, account_type, current_balance, created_at, updated_at) VALUES ($1,$2,'A','checking',0,NOW(),NOW())")
            .bind(acc).bind(ledger_id).execute(&pool).await.unwrap();
        sqlx::query("INSERT INTO transactions (id, account_id, ledger_id, amount, transaction_type, transaction_date, description, status, is_recurring, created_at, updated_at) VALUES ($1,$2,$3,$4,'expense',$5,'Z','cleared',false,NOW(),NOW())")
            .bind(Uuid::new_v4()).bind(acc).bind(ledger_id).bind(Decimal::new(1,0)).bind(NaiveDate::from_ymd_opt(2024,9,10).unwrap())
            .execute(&pool).await.unwrap();

        // Trigger an export to create an audit log
        let app = Router::new()
            .route("/api/v1/transactions/export", post(export_transactions))
            .with_state(pool.clone());
        let req = Request::builder()
            .method("POST")
            .uri("/api/v1/transactions/export")
            .header(header::AUTHORIZATION, token.clone())
            .header(header::CONTENT_TYPE, "application/json")
            .body(Body::from(json!({"format":"json"}).to_string()))
            .unwrap();
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);

        // Call audit list endpoint
        let req = Request::builder()
            .method("GET")
            .uri(&format!("/api/v1/families/{}/audit-logs?entity_type=transactions", family.id))
            .header(header::AUTHORIZATION, token.clone())
            .body(Body::empty())
            .unwrap();
        // Build minimal app for audit list
        use jive_money_api::handlers::audit_handler::get_audit_logs;
        use axum::Extension;
        use jive_money_api::services::ServiceContext;
        use jive_money_api::models::permission::MemberRole;
        let ctx = ServiceContext::new(owner.id, family.id, MemberRole::Owner, MemberRole::Owner.default_permissions(), owner.email.clone(), Some("Owner".to_string()));
        let app = Router::new()
            .route("/api/v1/families/:id/audit-logs", get(get_audit_logs))
            .layer(Extension(ctx))
            .with_state(pool.clone());
        let resp = app.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let body = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert!(v["success"].as_bool().unwrap_or(false));

        // Cleanup endpoint (should allow owner)
        use jive_money_api::handlers::audit_handler::cleanup_audit_logs;
        let app = Router::new()
            .route("/api/v1/families/:id/audit-logs/cleanup", post(cleanup_audit_logs))
            .layer(Extension(jive_money_api::services::ServiceContext::new(owner.id, family.id, MemberRole::Owner, MemberRole::Owner.default_permissions(), owner.email.clone(), Some("Owner".to_string()))))
            .with_state(pool.clone());
        let req = Request::builder()
            .method("POST")
            .uri(&format!("/api/v1/families/{}/audit-logs/cleanup?older_than_days=0&limit=10", family.id))
            .header(header::AUTHORIZATION, token)
            .body(Body::empty())
            .unwrap();
        let resp = app.oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
    }

    #[tokio::test]
    async fn audit_cleanup_requires_permission_and_respects_limit() {
        use jive_money_api::handlers::audit_handler::{cleanup_audit_logs, get_audit_logs};
        use axum::routing::{post, get};
        use axum::Extension;
        use jive_money_api::services::ServiceContext;

        let pool = create_test_pool().await;
        let owner = create_test_user(&pool).await;
        let family = create_test_family(&pool, owner.id).await;

        // Seed some audit logs directly for the family (older than 0 days)
        let now = chrono::Utc::now();
        for _ in 0..5 {
            sqlx::query(r#"
                INSERT INTO family_audit_logs (id, family_id, user_id, action, entity_type, entity_id, old_values, new_values, ip_address, user_agent, created_at)
                VALUES ($1,$2,$3,'EXPORT','transactions',NULL,NULL,NULL,NULL,NULL,$4)
            "#)
            .bind(Uuid::new_v4())
            .bind(family.id)
            .bind(owner.id)
            .bind(now - chrono::Duration::days(10))
            .execute(&pool)
            .await
            .unwrap();
        }

        // Build app with cleanup route and owner context (allowed)
        let app_allowed = Router::new()
            .route("/api/v1/families/:id/audit-logs/cleanup", post(cleanup_audit_logs))
            .layer(Extension(ServiceContext::new(
                owner.id,
                family.id,
                MemberRole::Owner,
                MemberRole::Owner.default_permissions(),
                owner.email.clone(),
                Some("Owner".to_string()),
            )))
            .with_state(pool.clone());

        // Cleanup with limit=2 should delete exactly 2 rows
        let req = Request::builder()
            .method("POST")
            .uri(&format!("/api/v1/families/{}/audit-logs/cleanup?older_than_days=0&limit=2", family.id))
            .body(Body::empty())
            .unwrap();
        let resp = app_allowed.clone().oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let body = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&body).unwrap();
        assert_eq!(v["success"], true);
        assert_eq!(v["data"]["deleted"].as_i64().unwrap(), 2);

        // Verify remaining count is 3 via list endpoint
        let app_list = Router::new()
            .route("/api/v1/families/:id/audit-logs", get(get_audit_logs))
            .layer(Extension(ServiceContext::new(
                owner.id,
                family.id,
                MemberRole::Owner,
                MemberRole::Owner.default_permissions(),
                owner.email.clone(),
                Some("Owner".to_string()),
            )))
            .with_state(pool.clone());

        let req = Request::builder()
            .method("GET")
            .uri(&format!("/api/v1/families/{}/audit-logs?entity_type=transactions", family.id))
            .body(Body::empty())
            .unwrap();
        let resp = app_list.oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::OK);
        let body = hyper::body::to_bytes(resp.into_body()).await.unwrap();
        let v: serde_json::Value = serde_json::from_slice(&body).unwrap();
        // Not asserting exact equals because there may be other audits, but at least 3 remain
        assert!(v["data"].as_array().unwrap().len() >= 3);

        // Build app with Member role (no ManageSettings) to test 403
        let app_forbidden = Router::new()
            .route("/api/v1/families/:id/audit-logs/cleanup", post(cleanup_audit_logs))
            .layer(Extension(ServiceContext::new(
                owner.id,
                family.id,
                MemberRole::Member,
                MemberRole::Member.default_permissions(),
                owner.email.clone(),
                Some("Member".to_string()),
            )))
            .with_state(pool.clone());

        let req = Request::builder()
            .method("POST")
            .uri(&format!("/api/v1/families/{}/audit-logs/cleanup?older_than_days=0&limit=1", family.id))
            .body(Body::empty())
            .unwrap();
        let resp = app_forbidden.oneshot(req).await.unwrap();
        assert_eq!(resp.status(), http::StatusCode::FORBIDDEN);
    }
}
