#[cfg(test)]
mod tests {
    use jive_money_api::{
        models::{
            family::{CreateFamilyRequest, UpdateFamilyRequest},
            permission::{MemberRole, Permission},
        },
        services::{FamilyService, MemberService, ServiceContext, ServiceError},
    };
    use uuid::Uuid;
    
    use crate::fixtures::{create_test_pool, create_test_user, create_test_context};
    
    #[tokio::test]
    async fn test_create_family() {
        // Arrange
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let service = FamilyService::new(pool.clone());
        
        let request = CreateFamilyRequest {
            name: "Test Family".to_string(),
            currency: Some("USD".to_string()),
            timezone: Some("America/New_York".to_string()),
            locale: Some("en-US".to_string()),
        };
        
        // Act
        let result = service.create_family(user.id, request).await;
        
        // Assert
        assert!(result.is_ok());
        let family = result.unwrap();
        assert_eq!(family.name, "Test Family");
        assert_eq!(family.owner_id, user.id);
        assert!(family.invite_code.is_some());
        assert_eq!(family.currency, "USD");
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, user.id).await;
    }
    
    #[tokio::test]
    async fn test_update_family() {
        // Arrange
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let family = crate::fixtures::create_test_family(&pool, user.id).await;
        let context = create_test_context(user.id, family.id, MemberRole::Owner);
        let service = FamilyService::new(pool.clone());
        
        let update_request = UpdateFamilyRequest {
            name: Some("Updated Family".to_string()),
            currency: Some("EUR".to_string()),
            timezone: None,
            locale: None,
            date_format: None,
        };
        
        // Act
        let result = service.update_family(&context, family.id, update_request).await;
        
        // Assert
        assert!(result.is_ok());
        let updated_family = result.unwrap();
        assert_eq!(updated_family.name, "Updated Family");
        assert_eq!(updated_family.currency, "EUR");
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, user.id).await;
    }
    
    #[tokio::test]
    async fn test_delete_family_requires_owner() {
        // Arrange
        let pool = create_test_pool().await;
        let owner = create_test_user(&pool).await;
        let member = create_test_user(&pool).await;
        let family = crate::fixtures::create_test_family(&pool, owner.id).await;
        
        // 添加member到family
        let member_service = MemberService::new(pool.clone());
        let owner_context = create_test_context(owner.id, family.id, MemberRole::Owner);
        member_service.add_member(&owner_context, member.id, MemberRole::Member).await.unwrap();
        
        // 创建member的上下文
        let member_context = create_test_context(member.id, family.id, MemberRole::Member);
        let service = FamilyService::new(pool.clone());
        
        // Act - member尝试删除family
        let result = service.delete_family(&member_context, family.id).await;
        
        // Assert
        assert!(result.is_err());
        match result.unwrap_err() {
            ServiceError::PermissionDenied => (),
            _ => panic!("Expected PermissionDenied error"),
        }
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, owner.id).await;
        crate::fixtures::cleanup_test_data(&pool, member.id).await;
    }
    
    #[tokio::test]
    async fn test_switch_family() {
        // Arrange
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let family1 = crate::fixtures::create_test_family(&pool, user.id).await;
        let family2 = crate::fixtures::create_test_family(&pool, user.id).await;
        let service = FamilyService::new(pool.clone());
        
        // Act
        let result = service.switch_family(user.id, family2.id).await;
        
        // Assert
        assert!(result.is_ok());
        
        // Verify current_family_id is updated
        let current_family_id: Option<Uuid> = sqlx::query_scalar(
            "SELECT current_family_id FROM users WHERE id = $1"
        )
        .bind(user.id)
        .fetch_one(&pool)
        .await
        .unwrap();
        
        assert_eq!(current_family_id, Some(family2.id));
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, user.id).await;
    }
    
    #[tokio::test]
    async fn test_regenerate_invite_code() {
        // Arrange
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let family = crate::fixtures::create_test_family(&pool, user.id).await;
        let context = create_test_context(user.id, family.id, MemberRole::Owner);
        let service = FamilyService::new(pool.clone());
        
        let original_code = family.invite_code.clone();
        
        // Act
        let result = service.regenerate_invite_code(&context, family.id).await;
        
        // Assert
        assert!(result.is_ok());
        let new_code = result.unwrap();
        assert_ne!(original_code, Some(new_code.clone()));
        assert_eq!(new_code.len(), 8);
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, user.id).await;
    }
    
    #[tokio::test]
    async fn test_get_user_families() {
        // Arrange
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let family1 = crate::fixtures::create_test_family(&pool, user.id).await;
        let family2 = crate::fixtures::create_test_family(&pool, user.id).await;
        let service = FamilyService::new(pool.clone());
        
        // Act
        let result = service.get_user_families(user.id).await;
        
        // Assert
        assert!(result.is_ok());
        let families = result.unwrap();
        assert_eq!(families.len(), 2);
        
        let family_ids: Vec<Uuid> = families.iter().map(|f| f.id).collect();
        assert!(family_ids.contains(&family1.id));
        assert!(family_ids.contains(&family2.id));
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, user.id).await;
    }
}