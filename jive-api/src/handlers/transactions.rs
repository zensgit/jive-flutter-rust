//! 交易管理API处理器
//! 提供交易的CRUD操作接口

use axum::body::Body;
use axum::{
    extract::{Path, Query, State},
    http::{header, HeaderMap, StatusCode},
    response::{IntoResponse, Json},
};
use bytes::Bytes;
use chrono::{DateTime, NaiveDate, Utc};
use futures_util::{stream, StreamExt};
use rust_decimal::prelude::ToPrimitive;
use rust_decimal::Decimal;
use serde::{Deserialize, Serialize};
use sqlx::{Executor, PgPool, QueryBuilder, Row};
use std::convert::Infallible;
use std::pin::Pin;
use uuid::Uuid;

use crate::{
    auth::Claims,
    error::{ApiError, ApiResult},
};
use base64::Engine; // enable .encode on base64::engine
                    // Use core export when feature is enabled; otherwise fallback to local CSV writer
#[cfg(feature = "core_export")]
use jive_core::application::export_service::{
    CsvExportConfig, ExportService as CoreExportService, SimpleTransactionExport,
};

#[cfg(not(feature = "core_export"))]
#[derive(Clone)]
struct CsvExportConfig {
    delimiter: char,
    include_header: bool,
}

#[cfg(not(feature = "core_export"))]
impl Default for CsvExportConfig {
    fn default() -> Self {
        Self {
            delimiter: ',',
            include_header: true,
        }
    }
}

#[cfg(not(feature = "core_export"))]
fn csv_escape_cell(mut s: String, delimiter: char) -> String {
    // Basic CSV injection mitigation: prefix with ' if starts with = + - @
    if let Some(first) = s.chars().next() {
        if matches!(first, '=' | '+' | '-' | '@') {
            s.insert(0, '\'');
        }
    }
    let must_quote =
        s.contains(delimiter) || s.contains('"') || s.contains('\n') || s.contains('\r');
    let s = if s.contains('"') {
        s.replace('"', "\"\"")
    } else {
        s
    };
    if must_quote {
        format!("\"{}\"", s)
    } else {
        s
    }
}
use crate::models::permission::Permission;
use crate::services::context::ServiceContext;
use crate::services::{AuditService, AuthService};

/// 导出交易请求
#[derive(Debug, Deserialize)]
pub struct ExportTransactionsRequest {
    pub format: Option<String>, // csv, excel, pdf, json
    pub account_id: Option<Uuid>,
    pub ledger_id: Option<Uuid>,
    pub category_id: Option<Uuid>,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    // Whether to include header row in CSV output (default: true)
    pub include_header: Option<bool>,
}

/// 导出交易（返回 data:URL 形式的下载链接，避免服务器存储文件）
pub async fn export_transactions(
    State(pool): State<PgPool>,
    claims: Claims,
    headers: HeaderMap,
    Json(req): Json<ExportTransactionsRequest>,
) -> ApiResult<impl IntoResponse> {
    let user_id = claims.user_id()?; // 验证 JWT，提取用户ID
    let family_id = claims
        .family_id
        .ok_or(ApiError::BadRequest("缺少 family_id 上下文".to_string()))?;
    // 依据真实 membership 构造上下文并校验权限
    let auth_service = AuthService::new(pool.clone());
    let ctx = auth_service
        .validate_family_access(user_id, family_id)
        .await
        .map_err(|_| ApiError::Forbidden)?;
    ctx.require_permission(Permission::ExportData)
        .map_err(|_| ApiError::Forbidden)?;
    // 仅实现 CSV/JSON，其他格式返回错误提示
    let fmt = req.format.as_deref().unwrap_or("csv").to_lowercase();
    if fmt != "csv" && fmt != "json" {
        return Err(ApiError::BadRequest(format!(
            "不支持的导出格式: {} (仅支持 csv/json)",
            fmt
        )));
    }

    // 复用列表查询的过滤条件（限定在当前家庭）
    let mut query = QueryBuilder::new(
        "SELECT t.id, t.account_id, t.ledger_id, t.amount, t.transaction_type, t.transaction_date, \
         t.category_id, c.name as category_name, t.payee_id, p.name as payee_name, \
         t.description, t.notes \
         FROM transactions t \
         JOIN ledgers l ON t.ledger_id = l.id \
         LEFT JOIN categories c ON t.category_id = c.id \
         LEFT JOIN payees p ON t.payee_id = p.id \
         WHERE t.deleted_at IS NULL AND l.family_id = "
    );
    query.push_bind(ctx.family_id);

    if let Some(account_id) = req.account_id {
        query.push(" AND t.account_id = ");
        query.push_bind(account_id);
    }
    if let Some(ledger_id) = req.ledger_id {
        query.push(" AND t.ledger_id = ");
        query.push_bind(ledger_id);
    }
    if let Some(category_id) = req.category_id {
        query.push(" AND t.category_id = ");
        query.push_bind(category_id);
    }
    if let Some(start_date) = req.start_date {
        query.push(" AND t.transaction_date >= ");
        query.push_bind(start_date);
    }
    if let Some(end_date) = req.end_date {
        query.push(" AND t.transaction_date <= ");
        query.push_bind(end_date);
    }

    query.push(" ORDER BY t.transaction_date DESC, t.id DESC");

    let rows = query
        .build()
        .fetch_all(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(format!("查询交易失败: {}", e)))?;

    let file_name = format!(
        "transactions_export_{}.{}",
        Utc::now().format("%Y%m%d%H%M%S"),
        if fmt == "csv" { "csv" } else { "json" }
    );

    if fmt == "json" {
        let mut items = Vec::with_capacity(rows.len());
        for row in rows {
            items.push(serde_json::json!({
                "id": row.get::<Uuid,_>("id"),
                "account_id": row.get::<Uuid,_>("account_id"),
                "ledger_id": row.get::<Uuid,_>("ledger_id"),
                "amount": row.get::<Decimal,_>("amount"),
                "transaction_type": row.get::<String,_>("transaction_type"),
                "transaction_date": row.get::<NaiveDate,_>("transaction_date"),
                "category_id": row.try_get::<Uuid,_>("category_id").ok(),
                "category_name": row.try_get::<String,_>("category_name").ok(),
                "payee_id": row.try_get::<Uuid,_>("payee_id").ok(),
                "payee_name": row.try_get::<String,_>("payee_name").ok(),
                "description": row.try_get::<String,_>("description").ok(),
                "notes": row.try_get::<String,_>("notes").ok(),
            }));
        }
        let bytes =
            serde_json::to_vec_pretty(&items).map_err(|_e| ApiError::InternalServerError)?;
        let encoded = base64::engine::general_purpose::STANDARD.encode(&bytes);
        let url = format!("data:application/json;base64,{}", encoded);

        // Audit log (best-effort)
        let ua = headers
            .get(header::USER_AGENT)
            .and_then(|v| v.to_str().ok())
            .map(|s| s.to_string());
        let ip = headers
            .get("x-forwarded-for")
            .or_else(|| headers.get("x-real-ip"))
            .and_then(|v| v.to_str().ok())
            .map(|s| s.split(',').next().unwrap_or(s).trim().to_string());
        let audit_id = AuditService::new(pool.clone())
            .log_action_returning_id(
                ctx.family_id,
                ctx.user_id,
                crate::models::audit::CreateAuditLogRequest {
                    action: crate::models::audit::AuditAction::Export,
                    entity_type: "transactions".to_string(),
                    entity_id: None,
                    old_values: None,
                    new_values: Some(serde_json::json!({
                        "count": items.len(),
                        "format": "json",
                        "filters": {
                            "account_id": req.account_id,
                            "ledger_id": req.ledger_id,
                            "category_id": req.category_id,
                            "start_date": req.start_date,
                            "end_date": req.end_date,
                        }
                    })),
                },
                ip,
                ua,
            )
            .await
            .ok();
        // Also mirror audit id in header-like field for client convenience
        // Build response with optional X-Audit-Id header
        let mut resp_headers = HeaderMap::new();
        if let Some(aid) = audit_id {
            resp_headers.insert("x-audit-id", aid.to_string().parse().unwrap());
        }

        return Ok((
            resp_headers,
            Json(serde_json::json!({
                "success": true,
                "file_name": file_name,
                "mime_type": "application/json",
                "download_url": url,
                "size": bytes.len(),
                "audit_id": audit_id,
            })),
        ));
    }

    // 生成 CSV（core_export 启用时委托核心导出；否则使用本地安全 CSV 生成）
    #[cfg(feature = "core_export")]
    let (bytes, count_for_audit) = {
        let include_header = req.include_header.unwrap_or(true);
        let mapped: Vec<SimpleTransactionExport> = rows
            .into_iter()
            .map(|row| {
                let date: NaiveDate = row.get("transaction_date");
                let desc: String = row.try_get::<String, _>("description").unwrap_or_default();
                let amount: Decimal = row.get("amount");
                let category: Option<String> = row
                    .try_get::<String, _>("category_name")
                    .ok()
                    .and_then(|s| if s.is_empty() { None } else { Some(s) });
                let account_id: Uuid = row.get("account_id");
                let payee: Option<String> = row
                    .try_get::<String, _>("payee_name")
                    .ok()
                    .and_then(|s| if s.is_empty() { None } else { Some(s) });
                let ttype: String = row.get("transaction_type");

                SimpleTransactionExport {
                    date,
                    description: desc,
                    amount,
                    category,
                    account: account_id.to_string(),
                    payee,
                    transaction_type: ttype,
                }
            })
            .collect();
        let core = CoreExportService {};
        let cfg = CsvExportConfig::default().with_include_header(include_header);
        let out = core
            .generate_csv_simple(&mapped, Some(&cfg))
            .map_err(|_e| ApiError::InternalServerError)?;
        let mapped_len = mapped.len();
        (out, mapped_len)
    };

    #[cfg(not(feature = "core_export"))]
    let (bytes, count_for_audit) =
        {
            let cfg = CsvExportConfig {
                include_header: req.include_header.unwrap_or(true),
                ..CsvExportConfig::default()
            };
            let mut out = String::new();
            if cfg.include_header {
                out.push_str(&format!(
                    "Date{}Description{}Amount{}Category{}Account{}Payee{}Type\n",
                    cfg.delimiter,
                    cfg.delimiter,
                    cfg.delimiter,
                    cfg.delimiter,
                    cfg.delimiter,
                    cfg.delimiter
                ));
            }
            for row in rows.into_iter() {
                let date: NaiveDate = row.get("transaction_date");
                let desc: String = row.try_get::<String, _>("description").unwrap_or_default();
                let amount: Decimal = row.get("amount");
                let category: Option<String> = row
                    .try_get::<String, _>("category_name")
                    .ok()
                    .and_then(|s| if s.is_empty() { None } else { Some(s) });
                let account_id: Uuid = row.get("account_id");
                let payee: Option<String> = row
                    .try_get::<String, _>("payee_name")
                    .ok()
                    .and_then(|s| if s.is_empty() { None } else { Some(s) });
                let ttype: String = row.get("transaction_type");

                let fields = [
                    date.to_string(),
                    csv_escape_cell(desc, cfg.delimiter),
                    amount.to_string(),
                    csv_escape_cell(category.unwrap_or_default(), cfg.delimiter),
                    account_id.to_string(),
                    csv_escape_cell(payee.unwrap_or_default(), cfg.delimiter),
                    csv_escape_cell(ttype, cfg.delimiter),
                ];
                out.push_str(&fields.join(&cfg.delimiter.to_string()));
                out.push('\n');
            }
            let line_count = out.lines().count();
            let data_rows = if cfg.include_header {
                line_count.saturating_sub(1)
            } else {
                line_count
            };
            (out.into_bytes(), data_rows)
        };
    let encoded = base64::engine::general_purpose::STANDARD.encode(&bytes);
    let url = format!("data:text/csv;charset=utf-8;base64,{}", encoded);

    // Audit log (best-effort)
    let ua = headers
        .get(header::USER_AGENT)
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());
    let ip = headers
        .get("x-forwarded-for")
        .or_else(|| headers.get("x-real-ip"))
        .and_then(|v| v.to_str().ok())
        .map(|s| s.split(',').next().unwrap_or(s).trim().to_string());
    let audit_id = AuditService::new(pool.clone())
        .log_action_returning_id(
            ctx.family_id,
            ctx.user_id,
            crate::models::audit::CreateAuditLogRequest {
                action: crate::models::audit::AuditAction::Export,
                entity_type: "transactions".to_string(),
                entity_id: None,
                old_values: None,
                new_values: Some(serde_json::json!({
                    "count": count_for_audit,
                    "format": "csv",
                    "filters": {
                        "account_id": req.account_id,
                        "ledger_id": req.ledger_id,
                        "category_id": req.category_id,
                        "start_date": req.start_date,
                        "end_date": req.end_date,
                    }
                })),
            },
            ip,
            ua,
        )
        .await
        .ok();
    // Build response with optional X-Audit-Id header
    let mut resp_headers = HeaderMap::new();
    if let Some(aid) = audit_id {
        resp_headers.insert("x-audit-id", aid.to_string().parse().unwrap());
    }

    // Also mirror audit id in the JSON for POST CSV
    Ok((
        resp_headers,
        Json(serde_json::json!({
            "success": true,
            "file_name": file_name,
            "mime_type": "text/csv",
            "download_url": url,
            "size": bytes.len(),
            "audit_id": audit_id,
        })),
    ))
}

/// 流式 CSV 下载（更适合浏览器原生下载）
pub async fn export_transactions_csv_stream(
    State(pool): State<PgPool>,
    claims: Claims,
    headers: HeaderMap,
    Query(q): Query<ExportTransactionsRequest>,
) -> ApiResult<impl IntoResponse> {
    let user_id = claims.user_id()?;
    let family_id = claims
        .family_id
        .ok_or(ApiError::BadRequest("缺少 family_id 上下文".to_string()))?;
    let auth_service = AuthService::new(pool.clone());
    let ctx = auth_service
        .validate_family_access(user_id, family_id)
        .await
        .map_err(|_| ApiError::Forbidden)?;
    ctx.require_permission(Permission::ExportData)
        .map_err(|_| ApiError::Forbidden)?;

    // 复用查询逻辑（与 JSON/CSV data:URL 相同条件，限定家庭）
    let mut query = QueryBuilder::new(
        "SELECT t.id, t.account_id, t.ledger_id, t.amount, t.transaction_type, t.transaction_date, \
         t.category_id, c.name as category_name, t.payee_id, p.name as payee_name, \
         t.description, t.notes \
         FROM transactions t \
         JOIN ledgers l ON t.ledger_id = l.id \
         LEFT JOIN categories c ON t.category_id = c.id \
         LEFT JOIN payees p ON t.payee_id = p.id \
         WHERE t.deleted_at IS NULL AND l.family_id = "
    );
    query.push_bind(ctx.family_id);
    if let Some(account_id) = q.account_id {
        query.push(" AND t.account_id = ");
        query.push_bind(account_id);
    }
    if let Some(ledger_id) = q.ledger_id {
        query.push(" AND t.ledger_id = ");
        query.push_bind(ledger_id);
    }
    if let Some(category_id) = q.category_id {
        query.push(" AND t.category_id = ");
        query.push_bind(category_id);
    }
    if let Some(start_date) = q.start_date {
        query.push(" AND t.transaction_date >= ");
        query.push_bind(start_date);
    }
    if let Some(end_date) = q.end_date {
        query.push(" AND t.transaction_date <= ");
        query.push_bind(end_date);
    }
    query.push(" ORDER BY t.transaction_date DESC, t.id DESC");

    // When export_stream feature enabled, stream rows instead of buffering entire CSV
    #[cfg(feature = "export_stream")]
    {
        use futures::StreamExt;
        use tokio::sync::mpsc;
        use tokio_stream::wrappers::ReceiverStream;
        let include_header = q.include_header.unwrap_or(true);
        let (tx, rx) = mpsc::channel::<Result<bytes::Bytes, ApiError>>(8);
        let built = query.build();
        let pool_clone = pool.clone();
        tokio::spawn(async move {
            let mut stream = built.fetch_many(&pool_clone);
            // Header
            if include_header {
                if tx
                    .send(Ok(bytes::Bytes::from_static(
                        b"Date,Description,Amount,Category,Account,Payee,Type\n",
                    )))
                    .await
                    .is_err()
                {
                    return;
                }
            }
            while let Some(item) = stream.next().await {
                match item {
                    Ok(sqlx::Either::Right(row)) => {
                        use sqlx::Row;
                        let date: NaiveDate = row.get("transaction_date");
                        let desc: String =
                            row.try_get::<String, _>("description").unwrap_or_default();
                        let amount: Decimal = row.get("amount");
                        let category: Option<String> = row
                            .try_get::<String, _>("category_name")
                            .ok()
                            .filter(|s| !s.is_empty());
                        let account_id: Uuid = row.get("account_id");
                        let payee: Option<String> = row
                            .try_get::<String, _>("payee_name")
                            .ok()
                            .filter(|s| !s.is_empty());
                        let ttype: String = row.get("transaction_type");
                        let line = format!(
                            "{},{},{},{},{},{},{}\n",
                            date,
                            csv_escape_cell(desc, ','),
                            amount,
                            csv_escape_cell(category.clone().unwrap_or_default(), ','),
                            account_id,
                            csv_escape_cell(payee.clone().unwrap_or_default(), ','),
                            csv_escape_cell(ttype, ',')
                        );
                        if tx.send(Ok(bytes::Bytes::from(line))).await.is_err() {
                            return;
                        }
                    }
                    Ok(sqlx::Either::Left(_)) => { /* ignore query result count */ }
                    Err(e) => {
                        let _ = tx.send(Err(ApiError::DatabaseError(e.to_string()))).await;
                        return;
                    }
                }
            }
        });
        let byte_stream = ReceiverStream::new(rx).map(|r| match r {
            Ok(b) => Ok::<_, ApiError>(b),
            Err(e) => Err(e),
        });
        let body = Body::from_stream(byte_stream.map(|res| {
            res.map_err(|_| std::io::Error::new(std::io::ErrorKind::Other, "stream error"))
        }));
        // Build headers & return early (skip buffered path below)
        let mut headers_map = header::HeaderMap::new();
        headers_map.insert(
            header::CONTENT_TYPE,
            "text/csv; charset=utf-8".parse().unwrap(),
        );
        let filename = format!(
            "transactions_export_{}.csv",
            Utc::now().format("%Y%m%d%H%M%S")
        );
        headers_map.insert(
            header::CONTENT_DISPOSITION,
            format!("attachment; filename=\"{}\"", filename)
                .parse()
                .unwrap(),
        );
        return Ok((headers_map, body));
    }

    // Execute fully and build CSV body when streaming disabled
    let rows_all = query
        .build()
        .fetch_all(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(format!("查询交易失败: {}", e)))?;
    #[cfg(feature = "core_export")]
    let body_bytes: Vec<u8> = {
        let include_header = q.include_header.unwrap_or(true);
        let mapped: Vec<SimpleTransactionExport> = rows_all
            .into_iter()
            .map(|row| {
                let date: NaiveDate = row.get("transaction_date");
                let desc: String = row.try_get::<String, _>("description").unwrap_or_default();
                let amount: Decimal = row.get("amount");
                let category: Option<String> = row
                    .try_get::<String, _>("category_name")
                    .ok()
                    .and_then(|s| if s.is_empty() { None } else { Some(s) });
                let account_id: Uuid = row.get("account_id");
                let payee: Option<String> = row
                    .try_get::<String, _>("payee_name")
                    .ok()
                    .and_then(|s| if s.is_empty() { None } else { Some(s) });
                let ttype: String = row.get("transaction_type");

                SimpleTransactionExport {
                    date,
                    description: desc,
                    amount,
                    category,
                    account: account_id.to_string(),
                    payee,
                    transaction_type: ttype,
                }
            })
            .collect();
        let core = CoreExportService {};
        let cfg = CsvExportConfig::default().with_include_header(include_header);
        core.generate_csv_simple(&mapped, Some(&cfg))
            .map_err(|_e| ApiError::InternalServerError)?
    };

    #[cfg(not(feature = "core_export"))]
    let body_bytes: Vec<u8> =
        {
            let cfg = CsvExportConfig {
                include_header: q.include_header.unwrap_or(true),
                ..CsvExportConfig::default()
            };
            let mut out = String::new();
            if cfg.include_header {
                out.push_str(&format!(
                    "Date{}Description{}Amount{}Category{}Account{}Payee{}Type\n",
                    cfg.delimiter,
                    cfg.delimiter,
                    cfg.delimiter,
                    cfg.delimiter,
                    cfg.delimiter,
                    cfg.delimiter
                ));
            }
            for row in rows_all.iter() {
                let date: NaiveDate = row.get("transaction_date");
                let desc: String = row.try_get::<String, _>("description").unwrap_or_default();
                let amount: Decimal = row.get("amount");
                let category: Option<String> = row
                    .try_get::<String, _>("category_name")
                    .ok()
                    .and_then(|s| if s.is_empty() { None } else { Some(s) });
                let account_id: Uuid = row.get("account_id");
                let payee: Option<String> = row
                    .try_get::<String, _>("payee_name")
                    .ok()
                    .and_then(|s| if s.is_empty() { None } else { Some(s) });
                let ttype: String = row.get("transaction_type");
                let fields = [
                    date.to_string(),
                    csv_escape_cell(desc, cfg.delimiter),
                    amount.to_string(),
                    csv_escape_cell(category.clone().unwrap_or_default(), cfg.delimiter),
                    account_id.to_string(),
                    csv_escape_cell(payee.clone().unwrap_or_default(), cfg.delimiter),
                    csv_escape_cell(ttype, cfg.delimiter),
                ];
                out.push_str(&fields.join(&cfg.delimiter.to_string()));
                out.push('\n');
            }
            out.into_bytes()
        };

    // Audit log the export action (best-effort, ignore errors). We estimate row count via a COUNT query.
    let mut count_q = QueryBuilder::new(
        "SELECT COUNT(*) AS c FROM transactions t JOIN ledgers l ON t.ledger_id = l.id WHERE t.deleted_at IS NULL AND l.family_id = "
    );
    count_q.push_bind(ctx.family_id);
    if let Some(account_id) = q.account_id {
        count_q.push(" AND t.account_id = ");
        count_q.push_bind(account_id);
    }
    if let Some(ledger_id) = q.ledger_id {
        count_q.push(" AND t.ledger_id = ");
        count_q.push_bind(ledger_id);
    }
    if let Some(category_id) = q.category_id {
        count_q.push(" AND t.category_id = ");
        count_q.push_bind(category_id);
    }
    if let Some(start_date) = q.start_date {
        count_q.push(" AND t.transaction_date >= ");
        count_q.push_bind(start_date);
    }
    if let Some(end_date) = q.end_date {
        count_q.push(" AND t.transaction_date <= ");
        count_q.push_bind(end_date);
    }
    let estimated_count: i64 = count_q
        .build()
        .fetch_one(&pool)
        .await
        .ok()
        .and_then(|row| row.try_get::<i64, _>("c").ok())
        .unwrap_or(0);

    // Extract UA/IP for audit
    let ua = headers
        .get(header::USER_AGENT)
        .and_then(|v| v.to_str().ok())
        .map(|s| s.to_string());
    let ip = headers
        .get("x-forwarded-for")
        .or_else(|| headers.get("x-real-ip"))
        .and_then(|v| v.to_str().ok())
        .map(|s| s.split(',').next().unwrap_or(s).trim().to_string());

    let audit_id = AuditService::new(pool.clone())
        .log_action_returning_id(
            ctx.family_id,
            ctx.user_id,
            crate::models::audit::CreateAuditLogRequest {
                action: crate::models::audit::AuditAction::Export,
                entity_type: "transactions".to_string(),
                entity_id: None,
                old_values: None,
                new_values: Some(serde_json::json!({
                    "estimated_count": estimated_count,
                    "filters": {
                        "account_id": q.account_id,
                        "ledger_id": q.ledger_id,
                        "category_id": q.category_id,
                        "start_date": q.start_date,
                        "end_date": q.end_date,
                    }
                })),
            },
            ip,
            ua,
        )
        .await
        .ok();

    let filename = format!(
        "transactions_export_{}.csv",
        Utc::now().format("%Y%m%d%H%M%S")
    );
    let mut headers_map = header::HeaderMap::new();
    headers_map.insert(
        header::CONTENT_TYPE,
        "text/csv; charset=utf-8".parse().unwrap(),
    );
    headers_map.insert(
        header::CONTENT_DISPOSITION,
        format!("attachment; filename=\"{}\"", filename)
            .parse()
            .unwrap(),
    );
    if let Some(aid) = audit_id {
        headers_map.insert("x-audit-id", aid.to_string().parse().unwrap());
    }
    Ok((headers_map, Body::from(body_bytes)))
}

/// 交易查询参数
#[derive(Debug, Deserialize)]
pub struct TransactionQuery {
    pub account_id: Option<Uuid>,
    pub ledger_id: Option<Uuid>,
    pub category_id: Option<Uuid>,
    pub payee_id: Option<Uuid>,
    pub start_date: Option<NaiveDate>,
    pub end_date: Option<NaiveDate>,
    pub min_amount: Option<Decimal>,
    pub max_amount: Option<Decimal>,
    pub transaction_type: Option<String>,
    pub status: Option<String>,
    pub search: Option<String>,
    pub page: Option<u32>,
    pub per_page: Option<u32>,
    pub sort_by: Option<String>,
    pub sort_order: Option<String>,
}

/// 创建交易请求
#[derive(Debug, Deserialize)]
pub struct CreateTransactionRequest {
    pub account_id: Uuid,
    pub ledger_id: Uuid,
    pub amount: Decimal,
    pub transaction_type: String, // income, expense, transfer
    pub transaction_date: NaiveDate,
    pub category_id: Option<Uuid>,
    pub payee_id: Option<Uuid>,
    pub payee_name: Option<String>,
    pub description: Option<String>,
    pub notes: Option<String>,
    pub tags: Option<Vec<String>>,
    pub location: Option<String>,
    pub receipt_url: Option<String>,
    pub is_recurring: Option<bool>,
    pub recurring_rule: Option<String>,
}

/// 更新交易请求
#[derive(Debug, Deserialize)]
pub struct UpdateTransactionRequest {
    pub amount: Option<Decimal>,
    pub transaction_date: Option<NaiveDate>,
    pub category_id: Option<Uuid>,
    pub payee_id: Option<Uuid>,
    pub payee_name: Option<String>,
    pub description: Option<String>,
    pub notes: Option<String>,
    pub tags: Option<Vec<String>>,
    pub location: Option<String>,
    pub receipt_url: Option<String>,
    pub status: Option<String>,
}

/// 交易响应
#[derive(Debug, Serialize)]
pub struct TransactionResponse {
    pub id: Uuid,
    pub account_id: Uuid,
    pub ledger_id: Uuid,
    pub amount: Decimal,
    pub transaction_type: String,
    pub transaction_date: NaiveDate,
    pub category_id: Option<Uuid>,
    pub category_name: Option<String>,
    pub payee_id: Option<Uuid>,
    pub payee_name: Option<String>,
    pub description: Option<String>,
    pub notes: Option<String>,
    pub tags: Vec<String>,
    pub location: Option<String>,
    pub receipt_url: Option<String>,
    pub status: String,
    pub is_recurring: bool,
    pub recurring_rule: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

/// 交易统计
#[derive(Debug, Serialize)]
pub struct TransactionStatistics {
    pub total_count: i64,
    pub total_income: Decimal,
    pub total_expense: Decimal,
    pub net_amount: Decimal,
    pub average_transaction: Decimal,
    pub by_category: Vec<CategoryStatistics>,
    pub by_month: Vec<MonthlyStatistics>,
}

#[derive(Debug, Serialize)]
pub struct CategoryStatistics {
    pub category_id: Uuid,
    pub category_name: String,
    pub count: i64,
    pub total_amount: Decimal,
    pub percentage: f64,
}

#[derive(Debug, Serialize)]
pub struct MonthlyStatistics {
    pub month: String,
    pub income: Decimal,
    pub expense: Decimal,
    pub net: Decimal,
    pub transaction_count: i64,
}

/// 批量交易操作请求
#[derive(Debug, Deserialize)]
pub struct BulkTransactionRequest {
    pub transaction_ids: Vec<Uuid>,
    pub operation: String, // delete, update_category, update_status
    pub category_id: Option<Uuid>,
    pub status: Option<String>,
}

/// 获取交易列表
pub async fn list_transactions(
    Query(params): Query<TransactionQuery>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<Vec<TransactionResponse>>> {
    // 构建基础查询
    let mut query = QueryBuilder::new(
        "SELECT t.*, c.name as category_name, p.name as payee_name 
         FROM transactions t
         LEFT JOIN categories c ON t.category_id = c.id
         LEFT JOIN payees p ON t.payee_id = p.id
         WHERE t.deleted_at IS NULL",
    );

    // 添加过滤条件
    if let Some(account_id) = params.account_id {
        query.push(" AND t.account_id = ");
        query.push_bind(account_id);
    }

    if let Some(ledger_id) = params.ledger_id {
        query.push(" AND t.ledger_id = ");
        query.push_bind(ledger_id);
    }

    if let Some(category_id) = params.category_id {
        query.push(" AND t.category_id = ");
        query.push_bind(category_id);
    }

    if let Some(payee_id) = params.payee_id {
        query.push(" AND t.payee_id = ");
        query.push_bind(payee_id);
    }

    if let Some(start_date) = params.start_date {
        query.push(" AND t.transaction_date >= ");
        query.push_bind(start_date);
    }

    if let Some(end_date) = params.end_date {
        query.push(" AND t.transaction_date <= ");
        query.push_bind(end_date);
    }

    if let Some(min_amount) = params.min_amount {
        query.push(" AND ABS(t.amount) >= ");
        query.push_bind(min_amount);
    }

    if let Some(max_amount) = params.max_amount {
        query.push(" AND ABS(t.amount) <= ");
        query.push_bind(max_amount);
    }

    if let Some(transaction_type) = params.transaction_type {
        query.push(" AND t.transaction_type = ");
        query.push_bind(transaction_type);
    }

    if let Some(status) = params.status {
        query.push(" AND t.status = ");
        query.push_bind(status);
    }

    if let Some(search) = params.search {
        query.push(" AND (t.description ILIKE ");
        query.push_bind(format!("%{}%", search));
        query.push(" OR t.notes ILIKE ");
        query.push_bind(format!("%{}%", search));
        query.push(" OR p.name ILIKE ");
        query.push_bind(format!("%{}%", search));
        query.push(")");
    }

    // 排序 - 处理字段名映射
    let sort_by = params
        .sort_by
        .unwrap_or_else(|| "transaction_date".to_string());
    let sort_column = match sort_by.as_str() {
        "date" => "transaction_date",
        other => other,
    };
    let sort_order = params.sort_order.unwrap_or_else(|| "DESC".to_string());
    query.push(format!(" ORDER BY t.{} {}", sort_column, sort_order));

    // 分页
    let page = params.page.unwrap_or(1);
    let per_page = params.per_page.unwrap_or(50);
    let offset = ((page - 1) * per_page) as i64;

    query.push(" LIMIT ");
    query.push_bind(per_page as i64);
    query.push(" OFFSET ");
    query.push_bind(offset);

    // 执行查询
    let transactions = query
        .build()
        .fetch_all(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 转换为响应格式
    let mut response = Vec::new();
    for row in transactions {
        let tags_json: Option<serde_json::Value> = row.get("tags");
        let tags = if let Some(json_val) = tags_json {
            if let Some(arr) = json_val.as_array() {
                arr.iter()
                    .filter_map(|v| v.as_str().map(String::from))
                    .collect()
            } else {
                Vec::new()
            }
        } else {
            Vec::new()
        };

        response.push(TransactionResponse {
            id: row.get("id"),
            account_id: row.get("account_id"),
            ledger_id: row.get("ledger_id"),
            amount: row.get("amount"),
            transaction_type: row.get("transaction_type"),
            transaction_date: row.get("transaction_date"),
            category_id: row.get("category_id"),
            category_name: row.try_get("category_name").ok(),
            payee_id: row.get("payee_id"),
            payee_name: row
                .try_get("payee_name")
                .ok()
                .or_else(|| row.get("payee_name")),
            description: row.get("description"),
            notes: row.get("notes"),
            tags,
            location: row.get("location"),
            receipt_url: row.get("receipt_url"),
            status: row.get("status"),
            is_recurring: row.get("is_recurring"),
            recurring_rule: row.get("recurring_rule"),
            created_at: row.get("created_at"),
            updated_at: row.get("updated_at"),
        });
    }

    Ok(Json(response))
}

/// 获取单个交易
pub async fn get_transaction(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<TransactionResponse>> {
    let row = sqlx::query(
        r#"
        SELECT t.*, c.name as category_name, p.name as payee_name
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        LEFT JOIN payees p ON t.payee_id = p.id
        WHERE t.id = $1 AND t.deleted_at IS NULL
        "#,
    )
    .bind(id)
    .fetch_optional(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("Transaction not found".to_string()))?;

    let tags_json: Option<serde_json::Value> = row.get("tags");
    let tags = if let Some(json_val) = tags_json {
        if let Some(arr) = json_val.as_array() {
            arr.iter()
                .filter_map(|v| v.as_str().map(String::from))
                .collect()
        } else {
            Vec::new()
        }
    } else {
        Vec::new()
    };

    let response = TransactionResponse {
        id: row.get("id"),
        account_id: row.get("account_id"),
        ledger_id: row.get("ledger_id"),
        amount: row.get("amount"),
        transaction_type: row.get("transaction_type"),
        transaction_date: row.get("transaction_date"),
        category_id: row.get("category_id"),
        category_name: row.try_get("category_name").ok(),
        payee_id: row.get("payee_id"),
        payee_name: row.try_get("payee_name").ok(),
        description: row.get("description"),
        notes: row.get("notes"),
        tags,
        location: row.get("location"),
        receipt_url: row.get("receipt_url"),
        status: row.get("status"),
        is_recurring: row.get("is_recurring"),
        recurring_rule: row.get("recurring_rule"),
        created_at: row.get("created_at"),
        updated_at: row.get("updated_at"),
    };

    Ok(Json(response))
}

/// 创建交易
pub async fn create_transaction(
    State(pool): State<PgPool>,
    Json(req): Json<CreateTransactionRequest>,
) -> ApiResult<Json<TransactionResponse>> {
    let id = Uuid::new_v4();
    let _tags_json = req.tags.map(|t| serde_json::json!(t));

    // 开始事务
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 创建交易
    sqlx::query(
        r#"
        INSERT INTO transactions (
            id, account_id, ledger_id, amount, transaction_type,
            transaction_date, category_id, category_name, payee_id, payee,
            description, notes, location, receipt_url, status, 
            is_recurring, recurring_rule, created_at, updated_at
        ) VALUES (
            $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, 
            $11, $12, $13, $14, $15, $16, $17, NOW(), NOW()
        )
        "#,
    )
    .bind(id)
    .bind(req.account_id)
    .bind(req.ledger_id)
    .bind(req.amount)
    .bind(&req.transaction_type)
    .bind(req.transaction_date)
    .bind(req.category_id)
    .bind(
        req.payee_name
            .clone()
            .or_else(|| Some("Unknown".to_string())),
    )
    .bind(req.payee_id)
    .bind(req.payee_name.clone())
    .bind(req.description.clone())
    .bind(req.notes.clone())
    .bind(req.location.clone())
    .bind(req.receipt_url.clone())
    .bind("pending")
    .bind(req.is_recurring.unwrap_or(false))
    .bind(req.recurring_rule.clone())
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 更新账户余额
    let amount_change = if req.transaction_type == "expense" {
        -req.amount
    } else {
        req.amount
    };

    sqlx::query(
        r#"
        UPDATE accounts 
        SET current_balance = current_balance + $1,
            updated_at = NOW()
        WHERE id = $2
        "#,
    )
    .bind(amount_change)
    .bind(req.account_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 提交事务
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 查询完整的交易信息
    get_transaction(Path(id), State(pool)).await
}

/// 更新交易
pub async fn update_transaction(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
    Json(req): Json<UpdateTransactionRequest>,
) -> ApiResult<Json<TransactionResponse>> {
    // 构建动态更新查询
    let mut query = QueryBuilder::new("UPDATE transactions SET updated_at = NOW()");

    if let Some(amount) = req.amount {
        query.push(", amount = ");
        query.push_bind(amount);
    }

    if let Some(transaction_date) = req.transaction_date {
        query.push(", transaction_date = ");
        query.push_bind(transaction_date);
    }

    if let Some(category_id) = req.category_id {
        query.push(", category_id = ");
        query.push_bind(category_id);
    }

    if let Some(payee_id) = req.payee_id {
        query.push(", payee_id = ");
        query.push_bind(payee_id);
    }

    if let Some(payee_name) = &req.payee_name {
        query.push(", payee_name = ");
        query.push_bind(payee_name);
    }

    if let Some(description) = &req.description {
        query.push(", description = ");
        query.push_bind(description);
    }

    if let Some(notes) = &req.notes {
        query.push(", notes = ");
        query.push_bind(notes);
    }

    if let Some(tags) = req.tags {
        query.push(", tags = ");
        query.push_bind(serde_json::json!(tags));
    }

    if let Some(location) = &req.location {
        query.push(", location = ");
        query.push_bind(location);
    }

    if let Some(receipt_url) = &req.receipt_url {
        query.push(", receipt_url = ");
        query.push_bind(receipt_url);
    }

    if let Some(status) = &req.status {
        query.push(", status = ");
        query.push_bind(status);
    }

    query.push(" WHERE id = ");
    query.push_bind(id);
    query.push(" AND deleted_at IS NULL");

    let result = query
        .build()
        .execute(&pool)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    if result.rows_affected() == 0 {
        return Err(ApiError::NotFound("Transaction not found".to_string()));
    }

    // 返回更新后的交易
    get_transaction(Path(id), State(pool)).await
}

/// 删除交易（软删除）
pub async fn delete_transaction(
    Path(id): Path<Uuid>,
    State(pool): State<PgPool>,
) -> ApiResult<StatusCode> {
    // 开始事务
    let mut tx = pool
        .begin()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 获取交易信息以便回滚余额
    let row = sqlx::query(
        "SELECT account_id, amount, transaction_type FROM transactions WHERE id = $1 AND deleted_at IS NULL"
    )
    .bind(id)
    .fetch_optional(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?
    .ok_or(ApiError::NotFound("Transaction not found".to_string()))?;

    let account_id: Uuid = row.get("account_id");
    let amount: Decimal = row.get("amount");
    let transaction_type: String = row.get("transaction_type");

    // 软删除交易
    sqlx::query("UPDATE transactions SET deleted_at = NOW(), updated_at = NOW() WHERE id = $1")
        .bind(id)
        .execute(&mut *tx)
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 回滚账户余额
    let amount_change = if transaction_type == "expense" {
        amount
    } else {
        -amount
    };

    sqlx::query(
        r#"
        UPDATE accounts 
        SET current_balance = current_balance + $1,
            updated_at = NOW()
        WHERE id = $2
        "#,
    )
    .bind(amount_change)
    .bind(account_id)
    .execute(&mut *tx)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    // 提交事务
    tx.commit()
        .await
        .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    Ok(StatusCode::NO_CONTENT)
}

/// 批量操作交易
pub async fn bulk_transaction_operations(
    State(pool): State<PgPool>,
    Json(req): Json<BulkTransactionRequest>,
) -> ApiResult<Json<serde_json::Value>> {
    match req.operation.as_str() {
        "delete" => {
            // 批量软删除
            let mut query = QueryBuilder::new(
                "UPDATE transactions SET deleted_at = NOW(), updated_at = NOW() WHERE id IN (",
            );

            let mut separated = query.separated(", ");
            for id in &req.transaction_ids {
                separated.push_bind(id);
            }
            query.push(") AND deleted_at IS NULL");

            let result = query
                .build()
                .execute(&pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            Ok(Json(serde_json::json!({
                "operation": "delete",
                "affected": result.rows_affected()
            })))
        }
        "update_category" => {
            let category_id = req
                .category_id
                .ok_or(ApiError::BadRequest("category_id is required".to_string()))?;

            let mut query = QueryBuilder::new("UPDATE transactions SET category_id = ");
            query.push_bind(category_id);
            query.push(", updated_at = NOW() WHERE id IN (");

            let mut separated = query.separated(", ");
            for id in &req.transaction_ids {
                separated.push_bind(id);
            }
            query.push(") AND deleted_at IS NULL");

            let result = query
                .build()
                .execute(&pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            Ok(Json(serde_json::json!({
                "operation": "update_category",
                "affected": result.rows_affected()
            })))
        }
        "update_status" => {
            let status = req
                .status
                .ok_or(ApiError::BadRequest("status is required".to_string()))?;

            let mut query = QueryBuilder::new("UPDATE transactions SET status = ");
            query.push_bind(status);
            query.push(", updated_at = NOW() WHERE id IN (");

            let mut separated = query.separated(", ");
            for id in &req.transaction_ids {
                separated.push_bind(id);
            }
            query.push(") AND deleted_at IS NULL");

            let result = query
                .build()
                .execute(&pool)
                .await
                .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

            Ok(Json(serde_json::json!({
                "operation": "update_status",
                "affected": result.rows_affected()
            })))
        }
        _ => Err(ApiError::BadRequest("Invalid operation".to_string())),
    }
}

/// 获取交易统计
pub async fn get_transaction_statistics(
    Query(params): Query<TransactionQuery>,
    State(pool): State<PgPool>,
) -> ApiResult<Json<TransactionStatistics>> {
    let ledger_id = params
        .ledger_id
        .ok_or(ApiError::BadRequest("ledger_id is required".to_string()))?;

    // 获取总体统计
    let stats = sqlx::query(
        r#"
        SELECT 
            COUNT(*) as total_count,
            SUM(CASE WHEN transaction_type = 'income' THEN amount ELSE 0 END) as total_income,
            SUM(CASE WHEN transaction_type = 'expense' THEN amount ELSE 0 END) as total_expense
        FROM transactions
        WHERE ledger_id = $1 AND deleted_at IS NULL
        "#,
    )
    .bind(ledger_id)
    .fetch_one(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total_count: i64 = stats.try_get("total_count").unwrap_or(0);
    let total_income: Option<Decimal> = stats.try_get("total_income").ok();
    let total_expense: Option<Decimal> = stats.try_get("total_expense").ok();
    let total_income = total_income.unwrap_or(Decimal::ZERO);
    let total_expense = total_expense.unwrap_or(Decimal::ZERO);
    let net_amount = total_income - total_expense;
    let average_transaction = if total_count > 0 {
        (total_income + total_expense) / Decimal::from(total_count)
    } else {
        Decimal::ZERO
    };

    // 按分类统计
    let category_stats = sqlx::query(
        r#"
        SELECT 
            category_id,
            category_name,
            COUNT(*) as count,
            SUM(amount) as total_amount
        FROM transactions
        WHERE ledger_id = $1 AND deleted_at IS NULL AND category_id IS NOT NULL
        GROUP BY category_id, category_name
        ORDER BY total_amount DESC
        "#,
    )
    .bind(ledger_id)
    .fetch_all(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let total_categorized = category_stats
        .iter()
        .map(|s| {
            let amount: Option<Decimal> = s.try_get("total_amount").ok();
            amount.unwrap_or(Decimal::ZERO)
        })
        .sum::<Decimal>();

    let by_category: Vec<CategoryStatistics> = category_stats
        .into_iter()
        .filter_map(|row| {
            let category_id: Option<Uuid> = row.try_get("category_id").ok();
            let category_name: Option<String> = row.try_get("category_name").ok();

            if let (Some(id), Some(name)) = (category_id, category_name) {
                let count: i64 = row.try_get("count").unwrap_or(0);
                let total_amount: Option<Decimal> = row.try_get("total_amount").ok();
                let amount = total_amount.unwrap_or(Decimal::ZERO);
                let percentage = if total_categorized > Decimal::ZERO {
                    (amount / total_categorized * Decimal::from(100))
                        .to_f64()
                        .unwrap_or(0.0)
                } else {
                    0.0
                };

                Some(CategoryStatistics {
                    category_id: id,
                    category_name: name,
                    count,
                    total_amount: amount,
                    percentage,
                })
            } else {
                None
            }
        })
        .collect();

    // 按月统计（最近12个月）
    let monthly_stats = sqlx::query(
        r#"
        SELECT 
            TO_CHAR(transaction_date, 'YYYY-MM') as month,
            SUM(CASE WHEN transaction_type = 'income' THEN amount ELSE 0 END) as income,
            SUM(CASE WHEN transaction_type = 'expense' THEN amount ELSE 0 END) as expense,
            COUNT(*) as transaction_count
        FROM transactions
        WHERE ledger_id = $1 
            AND deleted_at IS NULL
            AND transaction_date >= CURRENT_DATE - INTERVAL '12 months'
        GROUP BY TO_CHAR(transaction_date, 'YYYY-MM')
        ORDER BY month DESC
        "#,
    )
    .bind(ledger_id)
    .fetch_all(&pool)
    .await
    .map_err(|e| ApiError::DatabaseError(e.to_string()))?;

    let by_month: Vec<MonthlyStatistics> = monthly_stats
        .into_iter()
        .map(|row| {
            let month: String = row.try_get("month").unwrap_or_default();
            let income: Option<Decimal> = row.try_get("income").ok();
            let expense: Option<Decimal> = row.try_get("expense").ok();
            let transaction_count: i64 = row.try_get("transaction_count").unwrap_or(0);

            let income = income.unwrap_or(Decimal::ZERO);
            let expense = expense.unwrap_or(Decimal::ZERO);

            MonthlyStatistics {
                month,
                income,
                expense,
                net: income - expense,
                transaction_count,
            }
        })
        .collect();

    let response = TransactionStatistics {
        total_count,
        total_income,
        total_expense,
        net_amount,
        average_transaction,
        by_category,
        by_month,
    };

    Ok(Json(response))
}
