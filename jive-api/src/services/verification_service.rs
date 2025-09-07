use rand::Rng;
use redis::aio::ConnectionManager;
use redis::AsyncCommands;
use std::time::Duration;

use super::ServiceError;

pub struct VerificationService {
    redis: Option<ConnectionManager>,
}

impl VerificationService {
    pub fn new(redis: Option<ConnectionManager>) -> Self {
        Self { redis }
    }
    
    /// Generate a 4-digit verification code
    pub fn generate_code() -> String {
        let mut rng = rand::thread_rng();
        let code: u32 = rng.gen_range(1000..10000);
        code.to_string()
    }
    
    /// Store verification code in Redis with expiration
    pub async fn store_verification_code(
        &self,
        user_id: &str,
        operation: &str,
        code: &str,
    ) -> Result<(), ServiceError> {
        if let Some(redis) = &self.redis {
            let mut conn = redis.clone();
            let key = format!("verification:{}:{}", user_id, operation);
            
            // Store code with 5 minutes expiration
            conn.set_ex(&key, code, 300)
                .await
                .map_err(|e| ServiceError::InternalError)?;
            
            Ok(())
        } else {
            // If Redis is not available, we can't store verification codes
            Err(ServiceError::ValidationError("验证码服务暂时不可用".to_string()))
        }
    }
    
    /// Verify the code provided by user
    pub async fn verify_code(
        &self,
        user_id: &str,
        operation: &str,
        provided_code: &str,
    ) -> Result<bool, ServiceError> {
        if let Some(redis) = &self.redis {
            let mut conn = redis.clone();
            let key = format!("verification:{}:{}", user_id, operation);
            
            // Get stored code
            let stored_code: Option<String> = conn.get(&key)
                .await
                .map_err(|e| ServiceError::InternalError)?;
            
            if let Some(code) = stored_code {
                if code == provided_code {
                    // Delete the code after successful verification
                    let _: () = conn.del(&key)
                        .await
                        .map_err(|e| ServiceError::InternalError)?;
                    
                    return Ok(true);
                }
            }
            
            Ok(false)
        } else {
            // If Redis is not available, we can't verify codes
            Err(ServiceError::ValidationError("验证码服务暂时不可用".to_string()))
        }
    }
    
    /// Send verification code (placeholder for email/SMS integration)
    pub async fn send_verification_code(
        &self,
        user_id: &str,
        operation: &str,
        destination: &str, // email or phone number
    ) -> Result<String, ServiceError> {
        let code = Self::generate_code();
        
        // Store the code
        self.store_verification_code(user_id, operation, &code).await?;
        
        // In production, this would send an email or SMS
        // For now, we'll just return the code for testing
        tracing::info!(
            "验证码 {} 已发送至 {} (操作: {})",
            code,
            destination,
            operation
        );
        
        Ok(code)
    }
}