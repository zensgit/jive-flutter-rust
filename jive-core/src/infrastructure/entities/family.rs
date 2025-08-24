use super::*;

// Family entity - represents a household or organization
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Family {
    pub id: Uuid,
    pub name: String,
    pub currency: String,
    pub locale: String,
    pub timezone: Option<String>,
    pub currency_preferences: serde_json::Value,
    pub enable_payees: bool,
    pub auto_associate_payee_category: bool,
    pub data_enrichment_enabled: bool,
    pub sidebar_view: String, // 'groups', 'ledgers', or 'all'
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Entity for Family {
    type Id = Uuid;
    
    fn id(&self) -> Self::Id {
        self.id
    }
    
    fn created_at(&self) -> DateTime<Utc> {
        self.created_at
    }
    
    fn updated_at(&self) -> DateTime<Utc> {
        self.updated_at
    }
}

impl Family {
    pub fn new(name: String, currency: String, locale: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            name,
            currency,
            locale,
            timezone: None,
            currency_preferences: serde_json::json!({}),
            enable_payees: false,
            auto_associate_payee_category: false,
            data_enrichment_enabled: false,
            sidebar_view: "all".to_string(),
            created_at: now,
            updated_at: now,
        }
    }
    
    pub fn with_timezone(mut self, timezone: String) -> Self {
        self.timezone = Some(timezone);
        self
    }
    
    pub fn with_payees_enabled(mut self, enabled: bool) -> Self {
        self.enable_payees = enabled;
        self
    }
}