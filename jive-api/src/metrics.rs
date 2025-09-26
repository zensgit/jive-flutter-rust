use crate::AppState;
use axum::{http::StatusCode, response::IntoResponse};
use sqlx::PgPool;

// Produce Prometheus-style metrics text.
pub async fn metrics_handler(
    axum::extract::State(state): axum::extract::State<AppState>,
) -> impl IntoResponse {
    let pool: &PgPool = &state.pool;
    // Query hash distribution (best-effort)
    let (b2a, b2b, b2y, a2id) = if let Ok(row) = sqlx::query(
        "SELECT \
            COUNT(*) FILTER (WHERE password_hash LIKE '$2a$%') AS b2a,\
            COUNT(*) FILTER (WHERE password_hash LIKE '$2b$%') AS b2b,\
            COUNT(*) FILTER (WHERE password_hash LIKE '$2y$%') AS b2y,\
            COUNT(*) FILTER (WHERE password_hash LIKE '$argon2id$%') AS a2id\
         FROM users",
    )
    .fetch_one(pool)
    .await
    {
        use sqlx::Row;
        (
            row.try_get::<i64, _>("b2a").unwrap_or(0),
            row.try_get::<i64, _>("b2b").unwrap_or(0),
            row.try_get::<i64, _>("b2y").unwrap_or(0),
            row.try_get::<i64, _>("a2id").unwrap_or(0),
        )
    } else {
        (0, 0, 0, 0)
    };

    let rehash_count = state.metrics.get_rehash_count();
    let mut buf = String::new();
    buf.push_str("# HELP jive_password_rehash_total Total successful bcrypt to argon2id password rehashes.\n");
    buf.push_str("# TYPE jive_password_rehash_total counter\n");
    buf.push_str(&format!("jive_password_rehash_total {}\n", rehash_count));
    buf.push_str("# HELP jive_password_hash_users Users by password hash algorithm variant.\n");
    buf.push_str("# TYPE jive_password_hash_users gauge\n");
    buf.push_str(&format!(
        "jive_password_hash_users{{algo=\"bcrypt_2a\"}} {}\n",
        b2a
    ));
    buf.push_str(&format!(
        "jive_password_hash_users{{algo=\"bcrypt_2b\"}} {}\n",
        b2b
    ));
    buf.push_str(&format!(
        "jive_password_hash_users{{algo=\"bcrypt_2y\"}} {}\n",
        b2y
    ));
    buf.push_str(&format!(
        "jive_password_hash_users{{algo=\"argon2id\"}} {}\n",
        a2id
    ));

    (
        StatusCode::OK,
        [(
            axum::http::header::CONTENT_TYPE,
            "text/plain; version=0.0.4",
        )],
        buf,
    )
}
