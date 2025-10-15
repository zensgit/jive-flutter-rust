//! Application Results - Result objects returned from use case execution
//!
//! Results encapsulate the outcome of command execution, including success
//! data or failure reasons. They provide a consistent response structure
//! across the application layer.

pub mod transaction_results;

pub use transaction_results::*;
