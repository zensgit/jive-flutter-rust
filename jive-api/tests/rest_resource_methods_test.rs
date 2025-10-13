use axum::{
    body::Body,
    http::{Method, Request, StatusCode},
    routing::{delete, get, post, put},
    Router,
};
use tower::ServiceExt;

async fn status(app: &Router, method: Method, path: &str) -> StatusCode {
    let req = Request::builder()
        .method(method)
        .uri(path)
        .body(Body::empty())
        .unwrap();
    app.clone().oneshot(req).await.unwrap().status()
}

#[tokio::test]
async fn rest_style_resource_methods_behave_as_expected() {
    // Simulate typical REST resource with collection + member routes
    let app = Router::new()
        .route(
            "/api/v1/accounts",
            get(|| async { "LIST" }).post(|| async { "CREATE" }),
        )
        .route(
            "/api/v1/accounts/:id",
            get(|| async { "SHOW" })
                .put(|| async { "UPDATE" })
                .delete(|| async { "DELETE" }),
        );

    // Collection
    assert_eq!(
        status(&app, Method::GET, "/api/v1/accounts").await,
        StatusCode::OK
    );
    assert_eq!(
        status(&app, Method::POST, "/api/v1/accounts").await,
        StatusCode::OK
    );
    assert_eq!(
        status(&app, Method::PATCH, "/api/v1/accounts").await,
        StatusCode::METHOD_NOT_ALLOWED
    );

    // Member
    assert_eq!(
        status(&app, Method::GET, "/api/v1/accounts/abc").await,
        StatusCode::OK
    );
    assert_eq!(
        status(&app, Method::PUT, "/api/v1/accounts/abc").await,
        StatusCode::OK
    );
    assert_eq!(
        status(&app, Method::DELETE, "/api/v1/accounts/abc").await,
        StatusCode::OK
    );
    assert_eq!(
        status(&app, Method::POST, "/api/v1/accounts/abc").await,
        StatusCode::METHOD_NOT_ALLOWED
    );

    // Unknown route
    assert_eq!(
        status(&app, Method::GET, "/api/v1/unknown").await,
        StatusCode::NOT_FOUND
    );
}
