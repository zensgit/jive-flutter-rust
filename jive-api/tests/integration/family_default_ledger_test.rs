#[cfg(test)]
mod tests {
    use jive_money_api::services::{auth_service::{AuthService, RegisterRequest}, FamilyService};
    use crate::fixtures::create_test_pool;

    #[tokio::test]
    async fn family_creation_sets_default_ledger() {
        let pool = create_test_pool().await;
        let auth = AuthService::new(pool.clone());
        let email = format!("family_def_{}@example.com", uuid::Uuid::new_v4());
        let uc = auth.register_with_family(RegisterRequest {
            email: email.clone(),
            password: "FamilyDef123!".to_string(),
            name: Some("Family Owner".to_string()),
            username: None,
        }).await.expect("register user");

        let user_id = uc.user_id;
        let family_id = uc.current_family_id.expect("family id");

        // Query ledger(s)
        #[derive(sqlx::FromRow, Debug)]
        struct LedgerRow { id: uuid::Uuid, family_id: uuid::Uuid, is_default: Option<bool>, created_by: Option<uuid::Uuid>, name: String }
        let ledgers = sqlx::query_as::<_, LedgerRow>(
            "SELECT id, family_id, is_default, created_by, name FROM ledgers WHERE family_id = $1"
        )
        .bind(family_id)
        .fetch_all(&pool).await.expect("fetch ledgers");

        assert_eq!(ledgers.len(), 1, "exactly one default ledger expected");
        let ledger = &ledgers[0];
        assert_eq!(ledger.family_id, family_id);
        assert_eq!(ledger.is_default.unwrap_or(false), true, "ledger should be default");
        assert_eq!(ledger.created_by.unwrap(), user_id, "created_by should be owner user_id");
        assert_eq!(ledger.name, "默认账本");

        // Also ensure service context can fetch families list for sanity
        let fam_service = FamilyService::new(pool.clone());
        let families = fam_service.get_user_families(user_id).await.expect("user families");
        assert_eq!(families.len(), 1);

        sqlx::query("DELETE FROM users WHERE id = $1")
            .bind(user_id)
            .execute(&pool)
            .await
            .ok();
    }
}

