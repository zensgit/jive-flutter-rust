use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, FromRow)]
pub struct Family {
    pub id: Uuid,
    pub name: String,
    #[sqlx(default)]
    pub currency: String,
    #[sqlx(default)]
    pub timezone: String,
    #[sqlx(default)]
    pub locale: String,
    #[sqlx(default)]
    pub fiscal_year_start: Option<i32>,
    #[sqlx(default)]
    pub invite_code: Option<String>,
    #[sqlx(default)]
    pub settings: Option<serde_json::Value>,
    #[sqlx(default)]
    pub member_count: Option<i32>,
    #[sqlx(default)]
    pub deleted_at: Option<DateTime<Utc>>,
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
    pub name: Option<String>,
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
    pub fn new(name: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            name,
            currency: "CNY".to_string(),
            timezone: "Asia/Shanghai".to_string(),
            locale: "zh-CN".to_string(),
            fiscal_year_start: Some(1),
            invite_code: Some(Self::generate_invite_code()),
            settings: Some(serde_json::json!({})),
            member_count: Some(1),
            deleted_at: None,
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
            date_format: "YYYY-MM-DD".to_string(),
        }
    }

    pub fn update_settings(&mut self, settings: FamilySettings) {
        self.currency = settings.currency;
        self.timezone = settings.timezone;
        self.locale = settings.locale;
        self.updated_at = Utc::now();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_family() {
        let family = Family::new("Test Family".to_string());
        
        assert_eq!(family.name, "Test Family");
        assert_eq!(family.currency, "CNY");
        assert_eq!(family.timezone, "Asia/Shanghai");
        assert_eq!(family.locale, "zh-CN");
    }

    #[test]
    fn test_generate_invite_code() {
        let code = Family::generate_invite_code();
        assert_eq!(code.len(), 8);
        assert!(code.chars().all(|c| c.is_ascii_alphanumeric()));
    }
}
