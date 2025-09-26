use axum::{
    extract::{Query, State},
    response::{IntoResponse, Json, Response},
    http::{HeaderMap, HeaderValue, StatusCode},
};
use axum::body::Body;
use chrono::NaiveDate;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
// use uuid::Uuid; // 未使用
use std::collections::HashMap;

use crate::auth::Claims;
use crate::error::{ApiError, ApiResult};
use crate::services::{CurrencyService, ExchangeRate, FamilyCurrencySettings};
use crate::services::currency_service::{UpdateCurrencySettingsRequest, AddExchangeRateRequest, CurrencyPreference};
use crate::services::currency_service::{ClearManualRateRequest, ClearManualRatesBatchRequest};
use super::family_handler::ApiResponse;

/// 获取所有支持的货币
pub async fn get_supported_currencies(
    State(pool): State<PgPool>,
    headers: HeaderMap,
) -> ApiResult<Response> {
    let service = CurrencyService::new(pool.clone());
    // Compute a simple ETag based on latest currencies updated_at max
    let etag_row = sqlx::query!(
        r#"SELECT to_char(MAX(updated_at), 'YYYYMMDDHH24MISS') AS max_ts FROM currencies WHERE is_active = true"#
    )
    .fetch_one(&pool)
    .await
    .map_err(|_| ApiError::InternalServerError)?;

    let mut current_etag = etag_row.max_ts.unwrap_or_else(|| "0".to_string());
    if current_etag.is_empty() { current_etag = "0".to_string(); }
    let current_etag_value = format!("W/\"curr-{}\"", current_etag);

    if let Some(if_none_match) = headers.get("if-none-match").and_then(|v| v.to_str().ok()) {
        if if_none_match == current_etag_value {
            // Not modified
            let resp = Response::builder()
                .status(StatusCode::NOT_MODIFIED)
                .header("ETag", HeaderValue::from_str(&current_etag_value).unwrap())
                .body(Body::empty())
                .unwrap();
            return Ok(resp);
        }
    }

    let currencies = service
        .get_supported_currencies()
        .await
        .map_err(|_e| ApiError::InternalServerError)?;

    let body = Json(ApiResponse::success(currencies));
    let mut resp = body.into_response();
    resp.headers_mut().insert("ETag", HeaderValue::from_str(&current_etag_value).unwrap());
    Ok(resp)
}

/// 获取用户的货币偏好
pub async fn get_user_currency_preferences(
    State(pool): State<PgPool>,
    claims: Claims,
) -> ApiResult<Json<ApiResponse<Vec<CurrencyPreference>>>> {
    let user_id = claims.user_id()?;
    let service = CurrencyService::new(pool);
    
    let preferences = service.get_user_currency_preferences(user_id).await
        .map_err(|_e| ApiError::InternalServerError)?;
    
    Ok(Json(ApiResponse::success(preferences)))
}

#[derive(Debug, Deserialize)]
pub struct SetCurrencyPreferencesRequest {
    pub currencies: Vec<String>,
    pub primary_currency: String,
}

/// 设置用户的货币偏好
pub async fn set_user_currency_preferences(
    State(pool): State<PgPool>,
    claims: Claims,
    Json(req): Json<SetCurrencyPreferencesRequest>,
) -> ApiResult<Json<ApiResponse<()>>> {
    let user_id = claims.user_id()?;
    let service = CurrencyService::new(pool);
    
    service.set_user_currency_preferences(user_id, req.currencies, req.primary_currency)
        .await
        .map_err(|_e| ApiError::InternalServerError)?;
    
    Ok(Json(ApiResponse::success(())))
}

/// 获取家庭的货币设置
pub async fn get_family_currency_settings(
    State(pool): State<PgPool>,
    claims: Claims,
) -> ApiResult<Json<ApiResponse<FamilyCurrencySettings>>> {
    let family_id = claims.family_id
        .ok_or_else(|| ApiError::BadRequest("No family selected".to_string()))?;
    
    let service = CurrencyService::new(pool);
    let settings = service.get_family_currency_settings(family_id).await
        .map_err(|_e| ApiError::InternalServerError)?;
    
    Ok(Json(ApiResponse::success(settings)))
}

/// 更新家庭的货币设置
pub async fn update_family_currency_settings(
    State(pool): State<PgPool>,
    claims: Claims,
    Json(req): Json<UpdateCurrencySettingsRequest>,
) -> ApiResult<Json<ApiResponse<FamilyCurrencySettings>>> {
    let family_id = claims.family_id
        .ok_or_else(|| ApiError::BadRequest("No family selected".to_string()))?;
    
    let service = CurrencyService::new(pool);
    let settings = service.update_family_currency_settings(family_id, req).await
        .map_err(|_e| ApiError::InternalServerError)?;
    
    Ok(Json(ApiResponse::success(settings)))
}

#[derive(Debug, Deserialize)]
pub struct GetExchangeRateQuery {
    pub from: String,
    pub to: String,
    pub date: Option<NaiveDate>,
}

/// 获取汇率
pub async fn get_exchange_rate(
    State(pool): State<PgPool>,
    Query(query): Query<GetExchangeRateQuery>,
) -> ApiResult<Json<ApiResponse<ExchangeRateResponse>>> {
    let service = CurrencyService::new(pool);
    let rate = service.get_exchange_rate(&query.from, &query.to, query.date).await
        .map_err(|_e| ApiError::NotFound("Exchange rate not found".to_string()))?;
    
    Ok(Json(ApiResponse::success(ExchangeRateResponse {
        from_currency: query.from,
        to_currency: query.to,
        rate,
        date: query.date.unwrap_or_else(|| chrono::Utc::now().date_naive()),
    })))
}

#[derive(Debug, Serialize)]
pub struct ExchangeRateResponse {
    pub from_currency: String,
    pub to_currency: String,
    pub rate: Decimal,
    pub date: NaiveDate,
}

#[derive(Debug, Deserialize)]
pub struct GetBatchExchangeRatesRequest {
    pub base_currency: String,
    pub target_currencies: Vec<String>,
    pub date: Option<NaiveDate>,
}

/// 批量获取汇率
pub async fn get_batch_exchange_rates(
    State(pool): State<PgPool>,
    Json(req): Json<GetBatchExchangeRatesRequest>,
) -> ApiResult<Json<ApiResponse<HashMap<String, Decimal>>>> {
    let service = CurrencyService::new(pool);
    let rates = service.get_exchange_rates(&req.base_currency, req.target_currencies, req.date)
        .await
        .map_err(|_e| ApiError::InternalServerError)?;
    
    Ok(Json(ApiResponse::success(rates)))
}

/// 添加或更新汇率
pub async fn add_exchange_rate(
    State(pool): State<PgPool>,
    _claims: Claims, // 需要管理员权限
    Json(req): Json<AddExchangeRateRequest>,
) -> ApiResult<Json<ApiResponse<ExchangeRate>>> {
    let service = CurrencyService::new(pool);
    let rate = service.add_exchange_rate(req).await
        .map_err(|_e| ApiError::InternalServerError)?;
    
    Ok(Json(ApiResponse::success(rate)))
}

/// 清除当日手动汇率（回退到自动来源）
pub async fn clear_manual_exchange_rate(
    State(pool): State<PgPool>,
    _claims: Claims, // 需要管理员/有权限
    Json(req): Json<ClearManualRateRequest>,
) -> ApiResult<Json<ApiResponse<serde_json::Value>>> {
    let service = CurrencyService::new(pool);
    service
        .clear_manual_rate(&req.from_currency, &req.to_currency)
        .await
        .map_err(|_e| ApiError::InternalServerError)?;
    Ok(Json(ApiResponse::success(serde_json::json!({
        "message": "Manual rate cleared for today"
    }))))
}

/// 批量清除手动汇率（按条件）
pub async fn clear_manual_exchange_rates_batch(
    State(pool): State<PgPool>,
    _claims: Claims,
    Json(req): Json<ClearManualRatesBatchRequest>,
) -> ApiResult<Json<ApiResponse<serde_json::Value>>> {
    let service = CurrencyService::new(pool);
    let affected = service.clear_manual_rates_batch(req).await
        .map_err(|_e| ApiError::InternalServerError)?;
    Ok(Json(ApiResponse::success(serde_json::json!({
        "message": "Manual rates cleared",
        "rows": affected
    }))))
}

#[derive(Debug, Deserialize)]
pub struct ConvertAmountRequest {
    pub amount: Decimal,
    pub from_currency: String,
    pub to_currency: String,
    pub date: Option<NaiveDate>,
}

#[derive(Debug, Serialize)]
pub struct ConvertAmountResponse {
    pub original_amount: Decimal,
    pub converted_amount: Decimal,
    pub from_currency: String,
    pub to_currency: String,
    pub exchange_rate: Decimal,
}

/// 货币转换
pub async fn convert_amount(
    State(pool): State<PgPool>,
    Json(req): Json<ConvertAmountRequest>,
) -> ApiResult<Json<ApiResponse<ConvertAmountResponse>>> {
    let service = CurrencyService::new(pool.clone());
    
    // 获取汇率
    let rate = service.get_exchange_rate(&req.from_currency, &req.to_currency, req.date)
        .await
        .map_err(|_e| ApiError::NotFound("Exchange rate not found".to_string()))?;
    
    // 获取货币信息以确定小数位数
    let currencies = service.get_supported_currencies().await
        .map_err(|_e| ApiError::InternalServerError)?;
    
    let from_currency_info = currencies.iter()
        .find(|c| c.code == req.from_currency)
        .ok_or_else(|| ApiError::NotFound("From currency not found".to_string()))?;
    
    let to_currency_info = currencies.iter()
        .find(|c| c.code == req.to_currency)
        .ok_or_else(|| ApiError::NotFound("To currency not found".to_string()))?;
    
    // 进行转换
    let converted = service.convert_amount(
        req.amount,
        rate,
        from_currency_info.decimal_places,
        to_currency_info.decimal_places,
    );
    
    Ok(Json(ApiResponse::success(ConvertAmountResponse {
        original_amount: req.amount,
        converted_amount: converted,
        from_currency: req.from_currency,
        to_currency: req.to_currency,
        exchange_rate: rate,
    })))
}

#[derive(Debug, Deserialize)]
pub struct GetExchangeRateHistoryQuery {
    pub from: String,
    pub to: String,
    pub days: Option<i32>,
}

/// 获取汇率历史
pub async fn get_exchange_rate_history(
    State(pool): State<PgPool>,
    Query(query): Query<GetExchangeRateHistoryQuery>,
) -> ApiResult<Json<ApiResponse<Vec<ExchangeRate>>>> {
    let service = CurrencyService::new(pool);
    let days = query.days.unwrap_or(30);
    
    let history = service.get_exchange_rate_history(&query.from, &query.to, days)
        .await
        .map_err(|_e| ApiError::InternalServerError)?;
    
    Ok(Json(ApiResponse::success(history)))
}

/// 获取常用汇率对
pub async fn get_popular_exchange_pairs(
    State(_pool): State<PgPool>,
) -> ApiResult<Json<ApiResponse<Vec<ExchangePair>>>> {
    // 定义常用的汇率对
    let pairs = vec![
        ExchangePair {
            from: "CNY".to_string(),
            to: "USD".to_string(),
            name: "人民币/美元".to_string(),
        },
        ExchangePair {
            from: "CNY".to_string(),
            to: "EUR".to_string(),
            name: "人民币/欧元".to_string(),
        },
        ExchangePair {
            from: "CNY".to_string(),
            to: "JPY".to_string(),
            name: "人民币/日元".to_string(),
        },
        ExchangePair {
            from: "CNY".to_string(),
            to: "HKD".to_string(),
            name: "人民币/港币".to_string(),
        },
        ExchangePair {
            from: "USD".to_string(),
            to: "EUR".to_string(),
            name: "美元/欧元".to_string(),
        },
        ExchangePair {
            from: "USD".to_string(),
            to: "JPY".to_string(),
            name: "美元/日元".to_string(),
        },
    ];
    
    Ok(Json(ApiResponse::success(pairs)))
}

#[derive(Debug, Serialize)]
pub struct ExchangePair {
    pub from: String,
    pub to: String,
    pub name: String,
}

/// 刷新汇率（从外部API获取）
pub async fn refresh_exchange_rates(
    State(pool): State<PgPool>,
    _claims: Claims, // 需要管理员权限
) -> ApiResult<Json<ApiResponse<()>>> {
    let service = CurrencyService::new(pool);
    
    // 为主要货币刷新汇率
    let base_currencies = vec!["CNY", "USD", "EUR"];
    
    for base in base_currencies {
        service.fetch_latest_rates(base).await
            .map_err(|_e| ApiError::InternalServerError)?;
    }
    
    Ok(Json(ApiResponse::success(())))
}
