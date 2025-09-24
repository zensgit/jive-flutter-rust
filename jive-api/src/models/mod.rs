#![allow(dead_code)]

pub mod audit;
pub mod family;
pub mod invitation;
pub mod membership;
pub mod permission;
pub mod transaction;

#[allow(unused_imports)]
pub use audit::{AuditAction, AuditLog, AuditLogFilter, CreateAuditLogRequest};
#[allow(unused_imports)]
pub use family::{CreateFamilyRequest, Family, FamilySettings, UpdateFamilyRequest};
#[allow(unused_imports)]
pub use invitation::{
    AcceptInvitationRequest, CreateInvitationRequest, Invitation, InvitationResponse,
    InvitationStatus,
};
#[allow(unused_imports)]
pub use membership::{CreateMemberRequest, FamilyMember, MemberWithUserInfo, UpdateMemberRequest};
#[allow(unused_imports)]
pub use permission::{MemberRole, Permission};

use thiserror::Error;

#[derive(Error, Debug)]
#[allow(dead_code)]
pub enum DomainError {
    #[error("Permission denied")]
    PermissionDenied,

    #[error("Invalid role: {0}")]
    InvalidRole(String),

    #[error("Family not found")]
    FamilyNotFound,

    #[error("User not found")]
    UserNotFound,

    #[error("Member already exists")]
    MemberAlreadyExists,

    #[error("Member not found")]
    MemberNotFound,

    #[error("Invitation expired")]
    InvitationExpired,

    #[error("Invitation not found")]
    InvitationNotFound,

    #[error("Invalid invitation")]
    InvalidInvitation,

    #[error("Cannot remove family owner")]
    CannotRemoveOwner,

    #[error("Cannot change owner role")]
    CannotChangeOwnerRole,

    #[error("Database error: {0}")]
    DatabaseError(String),

    #[error("Validation error: {0}")]
    ValidationError(String),
}
