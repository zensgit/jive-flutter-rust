//! Mappers - DTO ↔ Domain/Application Conversions
//!
//! This module provides bidirectional conversions between HTTP DTOs
//! and internal domain/application types.
//!
//! # Design Principles
//!
//! 1. **String → Decimal**: All monetary amounts come as strings from HTTP,
//!    preventing JavaScript/JSON floating-point precision issues
//!
//! 2. **No f64 Allowed**: Mappers enforce Money/Decimal usage, preventing
//!    accidental f64 usage in jive-api
//!
//! 3. **Validation Boundary**: Input validation happens here, catching
//!    invalid data before it reaches application layer
//!
//! 4. **Type Safety**: Strong-typed IDs prevent UUID mix-ups

pub mod transaction_mapper;

pub use transaction_mapper::*;
