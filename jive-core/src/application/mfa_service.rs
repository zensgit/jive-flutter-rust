//! MFA Service - 多因素认证服务
//! 
//! 基于 Maybe 的 MFA 实现，使用 TOTP (Time-based One-Time Password) 算法

use std::time::{SystemTime, UNIX_EPOCH};
use serde::{Serialize, Deserialize};
use base32;
use hmac::{Hmac, Mac};
use sha1::Sha1;
use qrcode::{QrCode, Version, EcLevel};
use qrcode::render::svg;
use rand::Rng;

use crate::domain::User;
use crate::error::{JiveError, Result};

/// MFA 设置请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MfaSetupRequest {
    pub user_id: String,
    pub app_name: String,  // 例如 "Jive Finance"
}

/// MFA 设置响应
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MfaSetupResponse {
    pub secret: String,
    pub qr_code_svg: String,
    pub qr_code_url: String,
    pub backup_codes: Vec<String>,
}

/// MFA 验证请求
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MfaVerifyRequest {
    pub user_id: String,
    pub code: String,  // 6位数字代码
}

/// MFA 服务
pub struct MfaService;

impl MfaService {
    /// 设置 MFA - 生成密钥和二维码
    pub async fn setup_mfa(
        &self,
        request: MfaSetupRequest,
    ) -> Result<MfaSetupResponse> {
        // 1. 生成 32 字符的随机密钥
        let secret = self.generate_secret();
        
        // 2. 生成 otpauth URL
        let otpauth_url = self.generate_otpauth_url(
            &secret,
            &request.user_id,
            &request.app_name,
        );
        
        // 3. 生成二维码 SVG
        let qr_code_svg = self.generate_qr_code_svg(&otpauth_url)?;
        
        // 4. 生成备用码（8个8位数字）
        let backup_codes = self.generate_backup_codes(8);
        
        Ok(MfaSetupResponse {
            secret,
            qr_code_svg,
            qr_code_url: otpauth_url,
            backup_codes,
        })
    }
    
    /// 验证 TOTP 代码
    pub async fn verify_totp(
        &self,
        secret: &str,
        code: &str,
    ) -> Result<bool> {
        // 移除空格和连字符
        let code = code.replace(" ", "").replace("-", "");
        
        // 验证是否为6位数字
        if code.len() != 6 || !code.chars().all(|c| c.is_ascii_digit()) {
            return Ok(false);
        }
        
        // 获取当前时间戳
        let current_time = self.get_current_timestamp();
        
        // 验证当前时间窗口和前后各一个窗口（容错）
        for time_offset in -1..=1 {
            let time_counter = (current_time / 30) + time_offset as u64;
            let expected_code = self.generate_totp(secret, time_counter)?;
            
            if expected_code == code {
                return Ok(true);
            }
        }
        
        Ok(false)
    }
    
    /// 生成当前的 TOTP 代码（用于测试）
    pub fn generate_current_totp(&self, secret: &str) -> Result<String> {
        let time_counter = self.get_current_timestamp() / 30;
        self.generate_totp(secret, time_counter)
    }
    
    /// 生成 TOTP 代码
    fn generate_totp(&self, secret: &str, time_counter: u64) -> Result<String> {
        // Base32 解码密钥
        let key = base32::decode(base32::Alphabet::RFC4648 { padding: false }, secret)
            .ok_or_else(|| JiveError::InvalidData("Invalid base32 secret".into()))?;
        
        // 时间计数器转换为字节数组（大端序）
        let time_bytes = time_counter.to_be_bytes();
        
        // 使用 HMAC-SHA1 生成哈希
        type HmacSha1 = Hmac<Sha1>;
        let mut mac = HmacSha1::new_from_slice(&key)
            .map_err(|_| JiveError::InvalidData("Invalid key length".into()))?;
        mac.update(&time_bytes);
        let result = mac.finalize();
        let hash = result.into_bytes();
        
        // 动态截断
        let offset = (hash[hash.len() - 1] & 0xf) as usize;
        let code = ((hash[offset] & 0x7f) as u32) << 24
            | (hash[offset + 1] as u32) << 16
            | (hash[offset + 2] as u32) << 8
            | hash[offset + 3] as u32;
        
        // 生成6位数字
        let otp = code % 1_000_000;
        Ok(format!("{:06}", otp))
    }
    
    /// 生成随机密钥（32字符 Base32）
    fn generate_secret(&self) -> String {
        let mut rng = rand::thread_rng();
        let random_bytes: Vec<u8> = (0..20).map(|_| rng.gen()).collect();
        base32::encode(base32::Alphabet::RFC4648 { padding: false }, &random_bytes)
    }
    
    /// 生成 otpauth URL
    fn generate_otpauth_url(
        &self,
        secret: &str,
        user_email: &str,
        app_name: &str,
    ) -> String {
        format!(
            "otpauth://totp/{}:{}?secret={}&issuer={}",
            urlencoding::encode(app_name),
            urlencoding::encode(user_email),
            secret,
            urlencoding::encode(app_name)
        )
    }
    
    /// 生成二维码 SVG
    fn generate_qr_code_svg(&self, data: &str) -> Result<String> {
        let code = QrCode::new(data)
            .map_err(|e| JiveError::InvalidData(format!("Failed to generate QR code: {}", e)))?;
        
        let image = code.render::<svg::Color>()
            .min_dimensions(200, 200)
            .build();
        
        Ok(image)
    }
    
    /// 生成备用码
    fn generate_backup_codes(&self, count: usize) -> Vec<String> {
        let mut rng = rand::thread_rng();
        (0..count)
            .map(|_| {
                let code: u32 = rng.gen_range(10000000..99999999);
                format!("{:08}", code)
            })
            .collect()
    }
    
    /// 获取当前时间戳（秒）
    fn get_current_timestamp(&self) -> u64 {
        SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap()
            .as_secs()
    }
    
    /// 启用 MFA
    pub async fn enable_mfa(
        &self,
        user_id: &str,
        secret: &str,
        backup_codes: Vec<String>,
    ) -> Result<()> {
        // TODO: 保存到数据库
        // UPDATE users SET 
        //   otp_secret = $1,
        //   otp_backup_codes = $2,
        //   otp_required = true,
        //   mfa_enabled_at = NOW()
        // WHERE id = $3
        
        Ok(())
    }
    
    /// 禁用 MFA
    pub async fn disable_mfa(&self, user_id: &str) -> Result<()> {
        // TODO: 更新数据库
        // UPDATE users SET 
        //   otp_secret = NULL,
        //   otp_backup_codes = NULL,
        //   otp_required = false,
        //   mfa_enabled_at = NULL
        // WHERE id = $1
        
        Ok(())
    }
    
    /// 验证备用码
    pub async fn verify_backup_code(
        &self,
        user_id: &str,
        code: &str,
    ) -> Result<bool> {
        // TODO: 从数据库获取备用码并验证
        // 如果验证成功，需要将使用过的备用码从列表中移除
        
        Ok(false)
    }
    
    /// 重新生成备用码
    pub async fn regenerate_backup_codes(
        &self,
        user_id: &str,
    ) -> Result<Vec<String>> {
        let new_codes = self.generate_backup_codes(8);
        
        // TODO: 保存到数据库
        
        Ok(new_codes)
    }
}

/// MFA 会话管理
pub struct MfaSession {
    pub user_id: String,
    pub requires_mfa: bool,
    pub mfa_verified: bool,
    pub expires_at: SystemTime,
}

impl MfaSession {
    /// 创建需要 MFA 验证的会话
    pub fn new_pending(user_id: String) -> Self {
        Self {
            user_id,
            requires_mfa: true,
            mfa_verified: false,
            expires_at: SystemTime::now() + std::time::Duration::from_secs(300), // 5分钟过期
        }
    }
    
    /// 标记 MFA 验证完成
    pub fn mark_verified(&mut self) {
        self.mfa_verified = true;
        self.expires_at = SystemTime::now() + std::time::Duration::from_secs(86400); // 24小时
    }
    
    /// 检查会话是否有效
    pub fn is_valid(&self) -> bool {
        if !self.requires_mfa {
            return true;
        }
        
        self.mfa_verified && SystemTime::now() < self.expires_at
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[tokio::test]
    async fn test_totp_generation_and_verification() {
        let service = MfaService;
        let secret = service.generate_secret();
        
        // 生成当前 TOTP
        let code = service.generate_current_totp(&secret).unwrap();
        assert_eq!(code.len(), 6);
        assert!(code.chars().all(|c| c.is_ascii_digit()));
        
        // 验证代码
        let is_valid = service.verify_totp(&secret, &code).await.unwrap();
        assert!(is_valid);
        
        // 验证错误代码
        let is_valid = service.verify_totp(&secret, "000000").await.unwrap();
        assert!(!is_valid);
    }

    #[test]
    fn test_backup_code_generation() {
        let service = MfaService;
        let codes = service.generate_backup_codes(8);
        
        assert_eq!(codes.len(), 8);
        for code in codes {
            assert_eq!(code.len(), 8);
            assert!(code.chars().all(|c| c.is_ascii_digit()));
        }
    }

    #[test]
    fn test_otpauth_url_generation() {
        let service = MfaService;
        let url = service.generate_otpauth_url(
            "JBSWY3DPEHPK3PXP",
            "user@example.com",
            "Jive Finance",
        );
        
        assert!(url.starts_with("otpauth://totp/"));
        assert!(url.contains("secret=JBSWY3DPEHPK3PXP"));
        assert!(url.contains("issuer=Jive%20Finance"));
    }
}