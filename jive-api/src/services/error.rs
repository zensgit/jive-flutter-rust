use thiserror::Error;
use uuid::Uuid;

#[derive(Debug, Error)]
pub enum ServiceError {
    #[error("Database error: {0}")]
    DatabaseError(#[from] sqlx::Error),
    
    #[error("Serialization error: {0}")]
    SerializationError(#[from] serde_json::Error),
    
    #[error("Permission denied")]
    PermissionDenied,
    
    #[error("Resource not found: {resource_type} with id {id}")]
    NotFound {
        resource_type: String,
        id: String,
    },
    
    #[error("Validation error: {0}")]
    ValidationError(String),
    
    #[error("Business rule violation: {0}")]
    BusinessRuleViolation(String),
    
    #[error("Conflict: {0}")]
    Conflict(String),
    
    #[error("Invalid invitation")]
    InvalidInvitation,
    
    #[error("Invitation expired")]
    InvitationExpired,
    
    #[error("Member already exists")]
    MemberAlreadyExists,
    
    #[error("Cannot remove family owner")]
    CannotRemoveOwner,
    
    #[error("Cannot change owner role")]
    CannotChangeOwnerRole,
    
    #[error("Family limit reached")]
    FamilyLimitReached,
    
    #[error("Authentication error: {0}")]
    AuthenticationError(String),
    
    #[error("External API error: {message}")]
    ExternalApi {
        message: String,
    },
    
    #[error("Internal server error")]
    InternalError,
}

impl ServiceError {
    pub fn not_found(resource_type: &str, id: Uuid) -> Self {
        ServiceError::NotFound {
            resource_type: resource_type.to_string(),
            id: id.to_string(),
        }
    }
    
    pub fn validation(message: impl Into<String>) -> Self {
        ServiceError::ValidationError(message.into())
    }
    
    pub fn business_rule(message: impl Into<String>) -> Self {
        ServiceError::BusinessRuleViolation(message.into())
    }
    
    pub fn conflict(message: impl Into<String>) -> Self {
        ServiceError::Conflict(message.into())
    }
}