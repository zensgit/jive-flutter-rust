use axum::{
    extract::{Query, State},
    response::Json,
};
use serde::Deserialize;
use sqlx::{PgPool, QueryBuilder};

use crate::error::{ApiError, ApiResult};
use crate::models::bank::Bank;

#[derive(Debug, Deserialize)]
pub struct BankQuery {
    pub search: Option<String>,
    pub is_crypto: Option<bool>,
    pub limit: Option<i64>,
}

pub async fn list_banks(
    Query(params): Query<BankQuery>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<Vec<Bank>>> {
    let mut query = QueryBuilder::new(
        "SELECT id, code, name, name_cn, name_en, icon_filename, is_crypto
         FROM banks WHERE is_active = true"
    );

    if let Some(search) = params.search {
        query.push(" AND (");
        query.push("name_cn ILIKE ");
        query.push_bind(format!("%{}%", search));
        query.push(" OR name ILIKE ");
        query.push_bind(format!("%{}%", search));
        query.push(" OR name_en ILIKE ");
        query.push_bind(format!("%{}%", search));
        query.push(" OR name_cn_pinyin ILIKE ");
        query.push_bind(format!("%{}%", search));
        query.push(" OR name_cn_abbr ILIKE ");
        query.push_bind(format!("%{}%", search));
        query.push(")");
    }

    if let Some(is_crypto) = params.is_crypto {
        query.push(" AND is_crypto = ");
        query.push_bind(is_crypto);
    }

    query.push(" ORDER BY sort_order DESC, name_cn, name");
    query.push(" LIMIT ");
    query.push_bind(params.limit.unwrap_or(100));

    let banks = query
        .build()
        .fetch_all(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let mut response = Vec::new();
    for row in banks {
        response.push(Bank {
            id: row.get("id"),
            code: row.get("code"),
            name: row.get("name"),
            name_cn: row.get("name_cn"),
            name_en: row.get("name_en"),
            icon_filename: row.get("icon_filename"),
            is_crypto: row.get("is_crypto"),
        });
    }

    Ok(Json(response))
}