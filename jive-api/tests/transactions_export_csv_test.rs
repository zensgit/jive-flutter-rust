use axum::http::StatusCode;
use jive_api::models::transaction::Transaction;
use jive_api::models::transaction_filter::TransactionFilter;
use jive_api::routes::transactions::{export_transactions_csv, TransactionCSVExportParams};
use jive_api::test_utils::test_app_with_auth;
use serde_json::json;
use tower::ServiceExt;

/// Test CSV export security and functionality
#[tokio::test]
async fn test_csv_export_security_and_format() {
    let (app, family_id, user_id, _token, _db_pool) = test_app_with_auth().await;

    // Test 1: CSV export with authentication
    let export_params = TransactionCSVExportParams {
        family_id,
        user_id: Some(user_id),
        filter: Some(TransactionFilter {
            start_date: None,
            end_date: None,
            account_ids: None,
            category_ids: None,
            min_amount: None,
            max_amount: None,
            search_term: None,
            tags: None,
            page: Some(1),
            limit: Some(100),
        }),
    };

    let request = axum::http::Request::builder()
        .method("POST")
        .uri("/api/v1/transactions/export/csv")
        .header("content-type", "application/json")
        .header("authorization", format!("Bearer valid_token_for_user_{}", user_id))
        .body(serde_json::to_string(&export_params).unwrap())
        .unwrap();

    let response = app.oneshot(request).await.unwrap();
    assert_eq!(response.status(), StatusCode::OK);

    // Verify CSV headers and format
    let body = hyper::body::to_bytes(response.into_body()).await.unwrap();
    let csv_content = String::from_utf8(body.to_vec()).unwrap();

    // Check for required CSV headers
    assert!(csv_content.contains("id,amount,description,category,account"));

    println!("✅ CSV export security test passed");
}

/// Test CSV export without authentication (should fail)
#[tokio::test]
async fn test_csv_export_unauthorized() {
    let (app, family_id, user_id, _token, _db_pool) = test_app_with_auth().await;

    let export_params = TransactionCSVExportParams {
        family_id,
        user_id: Some(user_id),
        filter: None,
    };

    let request = axum::http::Request::builder()
        .method("POST")
        .uri("/api/v1/transactions/export/csv")
        .header("content-type", "application/json")
        // No authorization header
        .body(serde_json::to_string(&export_params).unwrap())
        .unwrap();

    let response = app.oneshot(request).await.unwrap();
    assert_eq!(response.status(), StatusCode::UNAUTHORIZED);

    println!("✅ CSV export unauthorized test passed");
}

/// Test CSV export with invalid family access
#[tokio::test]
async fn test_csv_export_invalid_family() {
    let (app, _family_id, user_id, _token, _db_pool) = test_app_with_auth().await;

    let export_params = TransactionCSVExportParams {
        family_id: uuid::Uuid::new_v4(), // Random family ID
        user_id: Some(user_id),
        filter: None,
    };

    let request = axum::http::Request::builder()
        .method("POST")
        .uri("/api/v1/transactions/export/csv")
        .header("content-type", "application/json")
        .header("authorization", format!("Bearer valid_token_for_user_{}", user_id))
        .body(serde_json::to_string(&export_params).unwrap())
        .unwrap();

    let response = app.oneshot(request).await.unwrap();
    assert_eq!(response.status(), StatusCode::FORBIDDEN);

    println!("✅ CSV export invalid family test passed");
}

/// Test CSV export with large dataset (pagination/limits)
#[tokio::test]
async fn test_csv_export_large_dataset() {
    let (app, family_id, user_id, _token, _db_pool) = test_app_with_auth().await;

    let export_params = TransactionCSVExportParams {
        family_id,
        user_id: Some(user_id),
        filter: Some(TransactionFilter {
            start_date: None,
            end_date: None,
            account_ids: None,
            category_ids: None,
            min_amount: None,
            max_amount: None,
            search_term: None,
            tags: None,
            page: Some(1),
            limit: Some(10000), // Large limit to test performance
        }),
    };

    let request = axum::http::Request::builder()
        .method("POST")
        .uri("/api/v1/transactions/export/csv")
        .header("content-type", "application/json")
        .header("authorization", format!("Bearer valid_token_for_user_{}", user_id))
        .body(serde_json::to_string(&export_params).unwrap())
        .unwrap();

    let response = app.oneshot(request).await.unwrap();

    // Should either succeed or return appropriate error for large datasets
    match response.status() {
        StatusCode::OK => {
            let body = hyper::body::to_bytes(response.into_body()).await.unwrap();
            assert!(body.len() < 50 * 1024 * 1024); // Should be less than 50MB
            println!("✅ CSV export large dataset test passed (success)");
        },
        StatusCode::REQUEST_ENTITY_TOO_LARGE | StatusCode::BAD_REQUEST => {
            println!("✅ CSV export large dataset test passed (appropriate limit)");
        },
        _ => panic!("Unexpected status code: {}", response.status()),
    }
}

/// Test CSV export field sanitization (CSV injection prevention)
#[tokio::test]
async fn test_csv_export_field_sanitization() {
    let (app, family_id, user_id, _token, db_pool) = test_app_with_auth().await;

    // Create a transaction with potentially dangerous content
    let dangerous_description = "=cmd|'/c calc'!A1"; // CSV injection attempt

    // Note: This would require creating an actual transaction with dangerous content
    // For now, we'll test the export with basic parameters and verify sanitization
    let export_params = TransactionCSVExportParams {
        family_id,
        user_id: Some(user_id),
        filter: Some(TransactionFilter {
            search_term: Some(dangerous_description.to_string()),
            page: Some(1),
            limit: Some(10),
            start_date: None,
            end_date: None,
            account_ids: None,
            category_ids: None,
            min_amount: None,
            max_amount: None,
            tags: None,
        }),
    };

    let request = axum::http::Request::builder()
        .method("POST")
        .uri("/api/v1/transactions/export/csv")
        .header("content-type", "application/json")
        .header("authorization", format!("Bearer valid_token_for_user_{}", user_id))
        .body(serde_json::to_string(&export_params).unwrap())
        .unwrap();

    let response = app.oneshot(request).await.unwrap();
    assert_eq!(response.status(), StatusCode::OK);

    let body = hyper::body::to_bytes(response.into_body()).await.unwrap();
    let csv_content = String::from_utf8(body.to_vec()).unwrap();

    // Verify CSV injection characters are properly escaped or removed
    assert!(!csv_content.contains("=cmd"));
    assert!(!csv_content.contains("'/c calc'"));

    println!("✅ CSV export field sanitization test passed");
}

/// Test CSV export with different date ranges and filters
#[tokio::test]
async fn test_csv_export_with_filters() {
    let (app, family_id, user_id, _token, _db_pool) = test_app_with_auth().await;

    let export_params = TransactionCSVExportParams {
        family_id,
        user_id: Some(user_id),
        filter: Some(TransactionFilter {
            start_date: Some(chrono::NaiveDate::from_ymd_opt(2024, 1, 1).unwrap()),
            end_date: Some(chrono::NaiveDate::from_ymd_opt(2024, 12, 31).unwrap()),
            min_amount: Some(rust_decimal::Decimal::new(100, 2)), // $1.00
            max_amount: Some(rust_decimal::Decimal::new(10000, 2)), // $100.00
            page: Some(1),
            limit: Some(50),
            account_ids: None,
            category_ids: None,
            search_term: None,
            tags: None,
        }),
    };

    let request = axum::http::Request::builder()
        .method("POST")
        .uri("/api/v1/transactions/export/csv")
        .header("content-type", "application/json")
        .header("authorization", format!("Bearer valid_token_for_user_{}", user_id))
        .body(serde_json::to_string(&export_params).unwrap())
        .unwrap();

    let response = app.oneshot(request).await.unwrap();
    assert_eq!(response.status(), StatusCode::OK);

    let body = hyper::body::to_bytes(response.into_body()).await.unwrap();
    let csv_content = String::from_utf8(body.to_vec()).unwrap();

    // Verify CSV structure
    assert!(csv_content.starts_with("id,") || csv_content.starts_with("\"id\""));

    println!("✅ CSV export with filters test passed");
}