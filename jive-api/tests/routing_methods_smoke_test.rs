use axum::{
    body::Body,
    http::{Method, Request, StatusCode},
    routing::{delete, get, post, put},
    Router,
};
use tower::ServiceExt; // for `oneshot`

async fn call(app: Router, method: Method, path: &str) -> StatusCode {
    let req = Request::builder()
        .method(method)
        .uri(path)
        .body(Body::empty())
        .unwrap();
    let res = app.oneshot(req).await.unwrap();
    res.status()
}

#[tokio::test]
async fn routes_merge_across_methods_when_defined_separately() {
    // Same path, different methods registered via multiple `.route` calls should be merged.
    let app = Router::new()
        .route("/merge", get(|| async { "GET" }))
        .route("/merge", post(|| async { "POST" }));

    assert_eq!(
        call(app.clone(), Method::GET, "/merge").await,
        StatusCode::OK
    );
    assert_eq!(call(app, Method::POST, "/merge").await, StatusCode::OK);
}

#[tokio::test]
async fn routes_merge_across_methods_when_chained() {
    // Same path, different methods registered in a chained call should work.
    let app = Router::new().route(
        "/chain",
        get(|| async { "GET" })
            .post(|| async { "POST" })
            .put(|| async { "PUT" })
            .delete(|| async { "DELETE" }),
    );

    assert_eq!(
        call(app.clone(), Method::GET, "/chain").await,
        StatusCode::OK
    );
    assert_eq!(
        call(app.clone(), Method::POST, "/chain").await,
        StatusCode::OK
    );
    assert_eq!(
        call(app.clone(), Method::PUT, "/chain").await,
        StatusCode::OK
    );
    assert_eq!(call(app, Method::DELETE, "/chain").await, StatusCode::OK);
}

#[tokio::test]
#[should_panic(expected = "Overlapping method route")]
async fn duplicate_method_registration_should_panic() {
    // In Axum 0.7+, registering the same method twice on the same path will panic.
    // This test verifies that Axum prevents accidental duplicate registrations.
    let app: Router = Router::new()
        .route("/override", get(|| async { "FIRST" }))
        .route("/override", get(|| async { "SECOND" })); // This should panic

    // This line will never be reached due to panic above
    let _ = app;
}
