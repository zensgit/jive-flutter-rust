//! API Adapter Layer
//!
//! This module provides the interface between HTTP/REST API and the application layer.
//! It enforces the "interface-first" design strategy by:
//!
//! 1. **Preventing f64 Usage**: All monetary values come as strings, converted to Decimal
//! 2. **Type Safety**: Strong-typed IDs prevent UUID confusion
//! 3. **Validation Boundaries**: Input validation at API boundary
//! 4. **Clear Contracts**: DTOs define precise API contract independent of domain models
//!
//! # Architecture
//!
//! ```text
//! HTTP Request (JSON)
//!     ↓
//! DTOs (with string amounts)
//!     ↓
//! Validators (business rules)
//!     ↓
//! Mappers (DTO → Command, enforces Money/Decimal)
//!     ↓
//! Commands (application layer)
//!     ↓
//! Service (executes business logic)
//!     ↓
//! Results (application layer)
//!     ↓
//! Mappers (Result → DTO)
//!     ↓
//! DTOs (with string amounts)
//!     ↓
//! HTTP Response (JSON)
//! ```
//!
//! # Usage in jive-api
//!
//! ```rust,ignore
//! use jive_core::api::{
//!     dto::CreateTransactionRequest,
//!     validators::validate_create_transaction_request,
//!     mappers::{
//!         create_transaction_request_to_command,
//!         transaction_result_to_response,
//!     },
//! };
//!
//! // In HTTP handler
//! async fn create_transaction(
//!     Json(req): Json<CreateTransactionRequest>,
//!     State(service): State<Arc<dyn TransactionAppService>>,
//! ) -> Result<Json<TransactionResponse>, ApiError> {
//!     // 1. Validate at API boundary
//!     validate_create_transaction_request(&req)?;
//!
//!     // 2. Convert DTO → Command (enforces Money type)
//!     let command = create_transaction_request_to_command(req)?;
//!
//!     // 3. Execute business logic
//!     let result = service.create_transaction(command).await?;
//!
//!     // 4. Convert Result → Response DTO
//!     let response = transaction_result_to_response(result);
//!
//!     Ok(Json(response))
//! }
//! ```
//!
//! # Key Benefits
//!
//! - **No f64 in API Layer**: Impossible to accidentally use f64 for money
//! - **Type Safety**: Cannot mix up transaction IDs with account IDs
//! - **Early Validation**: Catch errors before expensive operations
//! - **API Versioning**: Change DTOs without affecting domain layer
//! - **Clear Separation**: Business logic stays in application layer

pub mod config;
pub mod dto;
pub mod validators;

// Mappers require application layer (Commands/Results)
#[cfg(all(feature = "server", feature = "db"))]
pub mod mappers;

// Re-export commonly used types
pub use config::ApiConfig;
pub use dto::*;
pub use validators::*;

#[cfg(all(feature = "server", feature = "db"))]
pub use mappers::*;
