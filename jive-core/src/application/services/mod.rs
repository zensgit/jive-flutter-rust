//! Application Services - Service trait definitions
//!
//! Service traits define the contract for application layer use cases.
//! Implementations can be provided by different infrastructure layers
//! (e.g., PostgreSQL, in-memory, mock for testing).

pub mod transaction_service;

pub use transaction_service::*;
