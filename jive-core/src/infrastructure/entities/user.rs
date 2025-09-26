use super::*;

// User entity
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct User {
    pub id: Uuid,
    pub family_id: Uuid,
    pub email: String,
    pub first_name: Option<String>,
    pub last_name: Option<String>,
    pub role: String, // 'admin' or 'member'
    pub preferences: serde_json::Value,
    pub last_seen_at: Option<DateTime<Utc>>,
    pub last_seen_version: Option<String>,
    pub remember_created_at: Option<DateTime<Utc>>,
    pub confirmed_at: Option<DateTime<Utc>>,
    pub confirmation_sent_at: Option<DateTime<Utc>>,
    pub confirmation_token: Option<String>,
    pub unconfirmed_email: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Entity for User {
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

impl User {
    pub fn new(family_id: Uuid, email: String, role: String) -> Self {
        let now = Utc::now();
        Self {
            id: Uuid::new_v4(),
            family_id,
            email,
            first_name: None,
            last_name: None,
            role,
            preferences: serde_json::json!({}),
            last_seen_at: None,
            last_seen_version: None,
            remember_created_at: None,
            confirmed_at: None,
            confirmation_sent_at: None,
            confirmation_token: None,
            unconfirmed_email: None,
            created_at: now,
            updated_at: now,
        }
    }

    pub fn full_name(&self) -> Option<String> {
        match (&self.first_name, &self.last_name) {
            (Some(first), Some(last)) => Some(format!("{} {}", first, last)),
            (Some(first), None) => Some(first.clone()),
            (None, Some(last)) => Some(last.clone()),
            _ => None,
        }
    }

    pub fn is_admin(&self) -> bool {
        self.role == "admin"
    }

    pub fn is_confirmed(&self) -> bool {
        self.confirmed_at.is_some()
    }
}

// Session entity
#[derive(Debug, Clone, Serialize, Deserialize, sqlx::FromRow)]
pub struct Session {
    pub id: Uuid,
    pub user_id: Uuid,
    pub logged_in_at: DateTime<Utc>,
    pub user_agent: Option<String>,
    pub ip_address: Option<String>,
    pub created_at: DateTime<Utc>,
    pub updated_at: DateTime<Utc>,
}

impl Entity for Session {
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
