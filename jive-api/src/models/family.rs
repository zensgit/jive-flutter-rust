use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Family {
    pub id: Uuid,
    pub name: String,
    pub owner_id: Uuid,
    pub invite_code: Option<String>,
    #[sqlx(default)]
    pub currency: String,
    #[sqlx(default)]
    pub timezone: String,
    #[sqlx(default)]
    pub locale: String,
    #[sqlx(default)]
    pub date_format: String,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FamilySettings {
    pub currency: String,
    pub timezone: String,
    pub locale: String,
    pub date_format: String,
}

impl Default for FamilySettings {
    fn default() -> Self {
        Self {
            currency: "CNY".to_string(),
            timezone: "Asia/Shanghai".to_string(),
            locale: "zh-CN".to_string(),
            date_format: "YYYY-MM-DD".to_string(),
        }
    }
}

#[derive(Debug, Serialize, Deserialize)]
pub struct CreateFamilyRequest {
    pub name: String,
    pub currency: Option<String>,
    pub timezone: Option<String>,
    pub locale: Option<String>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct UpdateFamilyRequest {
    pub name: Option<String>,
    pub currency: Option<String>,
    pub timezone: Option<String>,
    pub locale: Option<String>,
    pub date_format: Option<String>,
}

impl Family {
    pub fn new(name: String, owner_id: Uuid) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            name,
            owner_id,
            invite_code: Some(Self::generate_invite_code()),
            currency: "CNY".to_string(),
            timezone: "Asia/Shanghai".to_string(),
            locale: "zh-CN".to_string(),
            date_format: "YYYY-MM-DD".to_string(),
            created_at: now,
            updated_at: now,
        }
    }

    pub fn generate_invite_code() -> String {
        use rand::Rng;
        const CHARSET: &[u8] = b"ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        let mut rng = rand::thread_rng();
        
        (0..8)
            .map(|_| {
                let idx = rng.gen_range(0..CHARSET.len());
                CHARSET[idx] as char
            })
            .collect()
    }

    pub fn get_settings(&self) -> FamilySettings {
        FamilySettings {
            currency: self.currency.clone(),
            timezone: self.timezone.clone(),
            locale: self.locale.clone(),
            date_format: self.date_format.clone(),
        }
    }

    pub fn update_settings(&mut self, settings: FamilySettings) {
        self.currency = settings.currency;
        self.timezone = settings.timezone;
        self.locale = settings.locale;
        self.date_format = settings.date_format;
        self.updated_at = Utc::now();
    }

    pub fn can_be_deleted_by(&self, user_id: Uuid) -> bool {
        self.owner_id == user_id
    }

    pub fn transfer_ownership(&mut self, new_owner_id: Uuid) {
        self.owner_id = new_owner_id;
        self.updated_at = Utc::now();
    }

    pub fn regenerate_invite_code(&mut self) {
        self.invite_code = Some(Self::generate_invite_code());
        self.updated_at = Utc::now();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_family() {
        let owner_id = Uuid::new_v4();
        let family = Family::new("Test Family".to_string(), owner_id);
        
        assert_eq!(family.name, "Test Family");
        assert_eq!(family.owner_id, owner_id);
        assert!(family.invite_code.is_some());
        assert_eq!(family.currency, "CNY");
    }

    #[test]
    fn test_generate_invite_code() {
        let code = Family::generate_invite_code();
        assert_eq!(code.len(), 8);
        assert!(code.chars().all(|c| c.is_ascii_alphanumeric()));
    }

    #[test]
    fn test_can_be_deleted_by() {
        let owner_id = Uuid::new_v4();
        let other_id = Uuid::new_v4();
        let family = Family::new("Test Family".to_string(), owner_id);
        
        assert!(family.can_be_deleted_by(owner_id));
        assert!(!family.can_be_deleted_by(other_id));
    }
}