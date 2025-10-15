use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Serialize, Deserialize)]
pub struct Bank {
    pub id: Uuid,
    pub code: String,
    pub name: String,
    pub name_cn: Option<String>,
    pub name_en: Option<String>,
    pub icon_filename: Option<String>,
    pub is_crypto: bool,
}

impl Bank {
    pub fn display_name(&self) -> &str {
        self.name_cn.as_deref().unwrap_or(&self.name)
    }
}
