//! Password verification and rehashing utilities
//!
//! Provides unified password verification supporting both Argon2id (preferred)
//! and bcrypt (legacy) formats with automatic rehashing capability.

use argon2::{
    password_hash::{rand_core::OsRng, PasswordHash, PasswordHasher, SaltString},
    Argon2, PasswordVerifier,
};

/// Result of password verification
#[derive(Debug)]
pub struct PasswordVerifyResult {
    /// Whether the password was verified successfully
    pub verified: bool,
    /// Whether the hash needs to be upgraded (bcrypt -> Argon2id)
    pub needs_rehash: bool,
    /// The new Argon2id hash if rehashing was performed
    pub new_hash: Option<String>,
}

/// Verify password against a hash and optionally rehash if it's in legacy format
///
/// # Arguments
/// * `password` - Plain text password to verify
/// * `current_hash` - Hash string from database (Argon2id or bcrypt format)
/// * `enable_rehash` - Whether to generate new Argon2id hash for bcrypt passwords
///
/// # Returns
/// `PasswordVerifyResult` with verification status and optional new hash
///
/// # Supported Formats
/// - Argon2id: `$argon2...`
/// - bcrypt: `$2a$`, `$2b$`, `$2y$`
/// - Unknown formats: attempted as Argon2id (best-effort)
pub fn verify_and_maybe_rehash(
    password: &str,
    current_hash: &str,
    enable_rehash: bool,
) -> PasswordVerifyResult {
    let hash = current_hash;

    // Try Argon2id format first (preferred)
    if hash.starts_with("$argon2") {
        match PasswordHash::new(hash) {
            Ok(parsed_hash) => {
                let argon2 = Argon2::default();
                let verified = argon2
                    .verify_password(password.as_bytes(), &parsed_hash)
                    .is_ok();

                return PasswordVerifyResult {
                    verified,
                    needs_rehash: false,
                    new_hash: None,
                };
            }
            Err(_) => {
                return PasswordVerifyResult {
                    verified: false,
                    needs_rehash: false,
                    new_hash: None,
                };
            }
        }
    }

    // Try bcrypt format (legacy)
    if hash.starts_with("$2") {
        let verified = bcrypt::verify(password, hash).unwrap_or(false);

        if !verified {
            return PasswordVerifyResult {
                verified: false,
                needs_rehash: false,
                new_hash: None,
            };
        }

        // Password verified successfully, optionally rehash
        if enable_rehash {
            match generate_argon2_hash(password) {
                Ok(new_hash) => {
                    return PasswordVerifyResult {
                        verified: true,
                        needs_rehash: true,
                        new_hash: Some(new_hash),
                    };
                }
                Err(_) => {
                    // Rehashing failed, but verification succeeded
                    return PasswordVerifyResult {
                        verified: true,
                        needs_rehash: false,
                        new_hash: None,
                    };
                }
            }
        }

        return PasswordVerifyResult {
            verified: true,
            needs_rehash: false,
            new_hash: None,
        };
    }

    // Unknown format: try Argon2id as best-effort
    match PasswordHash::new(hash) {
        Ok(parsed) => {
            let argon2 = Argon2::default();
            let verified = argon2.verify_password(password.as_bytes(), &parsed).is_ok();

            PasswordVerifyResult {
                verified,
                needs_rehash: false,
                new_hash: None,
            }
        }
        Err(_) => PasswordVerifyResult {
            verified: false,
            needs_rehash: false,
            new_hash: None,
        },
    }
}

/// Generate a new Argon2id hash for the given password
///
/// # Arguments
/// * `password` - Plain text password to hash
///
/// # Returns
/// Result containing the hash string or an error
pub fn generate_argon2_hash(password: &str) -> Result<String, argon2::password_hash::Error> {
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();

    argon2
        .hash_password(password.as_bytes(), &salt)
        .map(|hash| hash.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_verify_argon2_success() {
        // Generate a test hash
        let password = "test_password_123";
        let hash = generate_argon2_hash(password).unwrap();

        let result = verify_and_maybe_rehash(password, &hash, true);

        assert!(result.verified);
        assert!(!result.needs_rehash);
        assert!(result.new_hash.is_none());
    }

    #[test]
    fn test_verify_argon2_failure() {
        let password = "test_password_123";
        let hash = generate_argon2_hash(password).unwrap();

        let result = verify_and_maybe_rehash("wrong_password", &hash, true);

        assert!(!result.verified);
        assert!(!result.needs_rehash);
        assert!(result.new_hash.is_none());
    }

    #[test]
    fn test_verify_bcrypt_with_rehash() {
        // Pre-generated bcrypt hash for "test123"
        let bcrypt_hash = bcrypt::hash("test123", bcrypt::DEFAULT_COST).unwrap();

        let result = verify_and_maybe_rehash("test123", &bcrypt_hash, true);

        assert!(result.verified);
        assert!(result.needs_rehash);
        assert!(result.new_hash.is_some());

        // Verify the new hash is Argon2id
        let new_hash = result.new_hash.unwrap();
        assert!(new_hash.starts_with("$argon2"));
    }

    #[test]
    fn test_verify_bcrypt_without_rehash() {
        let bcrypt_hash = bcrypt::hash("test123", bcrypt::DEFAULT_COST).unwrap();

        let result = verify_and_maybe_rehash("test123", &bcrypt_hash, false);

        assert!(result.verified);
        assert!(!result.needs_rehash);
        assert!(result.new_hash.is_none());
    }

    #[test]
    fn test_verify_bcrypt_failure() {
        let bcrypt_hash = bcrypt::hash("test123", bcrypt::DEFAULT_COST).unwrap();

        let result = verify_and_maybe_rehash("wrong_password", &bcrypt_hash, true);

        assert!(!result.verified);
        assert!(!result.needs_rehash);
        assert!(result.new_hash.is_none());
    }

    #[test]
    fn test_verify_unknown_format() {
        let result = verify_and_maybe_rehash("test123", "invalid_hash_format", true);

        assert!(!result.verified);
        assert!(!result.needs_rehash);
        assert!(result.new_hash.is_none());
    }
}
