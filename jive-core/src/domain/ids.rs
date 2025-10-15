/// Domain ID types - type-safe identifiers for entities
///
/// This module provides newtype wrappers around UUID to ensure type safety
/// when working with different entity types. This prevents accidentally
/// using an AccountId where a TransactionId is expected.

use serde::{Deserialize, Serialize};
use std::fmt;
use uuid::Uuid;

/// Macro to define ID types with common implementations
macro_rules! define_id {
    ($name:ident, $doc:expr) => {
        #[doc = $doc]
        #[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
        #[serde(transparent)]
        pub struct $name(pub Uuid);

        impl $name {
            /// Creates a new random ID
            pub fn new() -> Self {
                Self(Uuid::new_v4())
            }

            /// Creates an ID from a UUID
            pub fn from_uuid(uuid: Uuid) -> Self {
                Self(uuid)
            }

            /// Returns the underlying UUID
            pub fn as_uuid(&self) -> Uuid {
                self.0
            }

            /// Returns the ID as a hyphenated string
            pub fn to_string(&self) -> String {
                self.0.to_string()
            }
        }

        impl Default for $name {
            fn default() -> Self {
                Self::new()
            }
        }

        impl From<Uuid> for $name {
            fn from(uuid: Uuid) -> Self {
                Self(uuid)
            }
        }

        impl From<$name> for Uuid {
            fn from(id: $name) -> Self {
                id.0
            }
        }

        impl fmt::Display for $name {
            fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
                write!(f, "{}", self.0)
            }
        }

        impl std::str::FromStr for $name {
            type Err = uuid::Error;

            fn from_str(s: &str) -> Result<Self, Self::Err> {
                Ok(Self(Uuid::parse_str(s)?))
            }
        }
    };
}

// Define all ID types
define_id!(AccountId, "Unique identifier for an Account");
define_id!(TransactionId, "Unique identifier for a Transaction");
define_id!(EntryId, "Unique identifier for an Entry (journal entry)");
define_id!(CategoryId, "Unique identifier for a Category");
define_id!(PayeeId, "Unique identifier for a Payee");
define_id!(LedgerId, "Unique identifier for a Ledger");
define_id!(FamilyId, "Unique identifier for a Family");
define_id!(UserId, "Unique identifier for a User");

/// Request ID for idempotency tracking
///
/// This ID is provided by the client to ensure that duplicate requests
/// (e.g., due to network retries) are not processed multiple times.
///
/// # Examples
///
/// ```
/// use jive_core::domain::ids::RequestId;
/// use uuid::Uuid;
///
/// let request_id = RequestId::new();
/// println!("Request ID: {}", request_id);
/// ```
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(transparent)]
pub struct RequestId(pub Uuid);

impl RequestId {
    /// Creates a new random request ID
    pub fn new() -> Self {
        Self(Uuid::new_v4())
    }

    /// Creates a request ID from a UUID
    pub fn from_uuid(uuid: Uuid) -> Self {
        Self(uuid)
    }

    /// Returns the underlying UUID
    pub fn as_uuid(&self) -> Uuid {
        self.0
    }

    /// Returns the ID as a hyphenated string
    pub fn to_string(&self) -> String {
        self.0.to_string()
    }
}

impl Default for RequestId {
    fn default() -> Self {
        Self::new()
    }
}

impl From<Uuid> for RequestId {
    fn from(uuid: Uuid) -> Self {
        Self(uuid)
    }
}

impl From<RequestId> for Uuid {
    fn from(id: RequestId) -> Self {
        id.0
    }
}

impl fmt::Display for RequestId {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl std::str::FromStr for RequestId {
    type Err = uuid::Error;

    fn from_str(s: &str) -> Result<Self, Self::Err> {
        Ok(Self(Uuid::parse_str(s)?))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_id_creation() {
        let account_id = AccountId::new();
        let transaction_id = TransactionId::new();

        // IDs should be different
        assert_ne!(account_id.as_uuid(), transaction_id.as_uuid());
    }

    #[test]
    fn test_id_type_safety() {
        let account_id = AccountId::new();
        let transaction_id = TransactionId::new();

        // This won't compile (type mismatch):
        // let _same: bool = account_id == transaction_id;

        // But we can compare UUIDs if needed:
        assert_ne!(account_id.as_uuid(), transaction_id.as_uuid());
    }

    #[test]
    fn test_id_serialization() {
        let id = AccountId::new();
        let json = serde_json::to_string(&id).unwrap();
        let deserialized: AccountId = serde_json::from_str(&json).unwrap();
        assert_eq!(id, deserialized);
    }

    #[test]
    fn test_request_id() {
        let req_id = RequestId::new();
        assert!(!req_id.to_string().is_empty());
    }

    #[test]
    fn test_id_from_string() {
        let uuid_str = "550e8400-e29b-41d4-a716-446655440000";
        let account_id: AccountId = uuid_str.parse().unwrap();
        assert_eq!(account_id.to_string(), uuid_str);
    }
}
