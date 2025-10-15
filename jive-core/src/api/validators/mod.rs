//! Validators - Input Validation Logic
//!
//! This module provides comprehensive validation for API requests.
//! Validation happens at the API boundary before data reaches the application layer.
//!
//! # Validation Strategy
//!
//! 1. **Type Safety**: DTOs provide basic type checking (String, Uuid, etc.)
//! 2. **Business Rules**: Validators enforce business constraints (positive amounts, etc.)
//! 3. **Early Failure**: Catch invalid data before expensive operations
//! 4. **Clear Errors**: Return actionable error messages to API clients

pub mod transaction_validator;

pub use transaction_validator::*;
