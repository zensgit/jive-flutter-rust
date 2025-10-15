//! Data Transfer Objects (DTOs)
//!
//! This module defines the HTTP API contract structures.
//! DTOs are deliberately separated from domain models for:
//!
//! - **API Versioning**: Change API without affecting domain
//! - **Validation Boundaries**: Validate at API boundary
//! - **Serialization Control**: Precise JSON format control
//! - **Backward Compatibility**: Maintain old API versions

pub mod transaction_dto;

pub use transaction_dto::*;
