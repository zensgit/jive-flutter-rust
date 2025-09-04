#[cfg(test)]
mod tests {
    use jive_money_api::{
        models::{
            permission::{MemberRole, Permission},
        },
        services::{MemberService, ServiceError},
    };
    
    use crate::fixtures::{create_test_pool, create_test_user, create_test_family, create_test_context};
    
    #[tokio::test]
    async fn test_add_member() {
        // Arrange
        let pool = create_test_pool().await;
        let owner = create_test_user(&pool).await;
        let new_member = create_test_user(&pool).await;
        let family = create_test_family(&pool, owner.id).await;
        let context = create_test_context(owner.id, family.id, MemberRole::Owner);
        let service = MemberService::new(pool.clone());
        
        // Act
        let result = service.add_member(&context, new_member.id, MemberRole::Member).await;
        
        // Assert
        assert!(result.is_ok());
        let member = result.unwrap();
        assert_eq!(member.user_id, new_member.id);
        assert_eq!(member.family_id, family.id);
        assert_eq!(member.role, MemberRole::Member);
        assert!(member.is_active);
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, owner.id).await;
        crate::fixtures::cleanup_test_data(&pool, new_member.id).await;
    }
    
    #[tokio::test]
    async fn test_cannot_add_duplicate_member() {
        // Arrange
        let pool = create_test_pool().await;
        let owner = create_test_user(&pool).await;
        let family = create_test_family(&pool, owner.id).await;
        let context = create_test_context(owner.id, family.id, MemberRole::Owner);
        let service = MemberService::new(pool.clone());
        
        // Act - Try to add owner again
        let result = service.add_member(&context, owner.id, MemberRole::Member).await;
        
        // Assert
        assert!(result.is_err());
        match result.unwrap_err() {
            ServiceError::MemberAlreadyExists => (),
            _ => panic!("Expected MemberAlreadyExists error"),
        }
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, owner.id).await;
    }
    
    #[tokio::test]
    async fn test_remove_member() {
        // Arrange
        let pool = create_test_pool().await;
        let owner = create_test_user(&pool).await;
        let member = create_test_user(&pool).await;
        let family = create_test_family(&pool, owner.id).await;
        let context = create_test_context(owner.id, family.id, MemberRole::Owner);
        let service = MemberService::new(pool.clone());
        
        // Add member first
        service.add_member(&context, member.id, MemberRole::Member).await.unwrap();
        
        // Act
        let result = service.remove_member(&context, member.id).await;
        
        // Assert
        assert!(result.is_ok());
        
        // Verify member is removed
        let member_exists: bool = sqlx::query_scalar(
            "SELECT EXISTS(SELECT 1 FROM family_members WHERE family_id = $1 AND user_id = $2)"
        )
        .bind(family.id)
        .bind(member.id)
        .fetch_one(&pool)
        .await
        .unwrap();
        
        assert!(!member_exists);
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, owner.id).await;
        crate::fixtures::cleanup_test_data(&pool, member.id).await;
    }
    
    #[tokio::test]
    async fn test_cannot_remove_owner() {
        // Arrange
        let pool = create_test_pool().await;
        let owner = create_test_user(&pool).await;
        let family = create_test_family(&pool, owner.id).await;
        let context = create_test_context(owner.id, family.id, MemberRole::Owner);
        let service = MemberService::new(pool.clone());
        
        // Act
        let result = service.remove_member(&context, owner.id).await;
        
        // Assert
        assert!(result.is_err());
        match result.unwrap_err() {
            ServiceError::CannotRemoveOwner => (),
            _ => panic!("Expected CannotRemoveOwner error"),
        }
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, owner.id).await;
    }
    
    #[tokio::test]
    async fn test_update_member_role() {
        // Arrange
        let pool = create_test_pool().await;
        let owner = create_test_user(&pool).await;
        let member = create_test_user(&pool).await;
        let family = create_test_family(&pool, owner.id).await;
        let context = create_test_context(owner.id, family.id, MemberRole::Owner);
        let service = MemberService::new(pool.clone());
        
        // Add member first
        service.add_member(&context, member.id, MemberRole::Member).await.unwrap();
        
        // Act
        let result = service.update_member_role(&context, member.id, MemberRole::Admin).await;
        
        // Assert
        assert!(result.is_ok());
        let updated_member = result.unwrap();
        assert_eq!(updated_member.role, MemberRole::Admin);
        assert_eq!(updated_member.permissions.len(), MemberRole::Admin.default_permissions().len());
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, owner.id).await;
        crate::fixtures::cleanup_test_data(&pool, member.id).await;
    }
    
    #[tokio::test]
    async fn test_cannot_change_owner_role() {
        // Arrange
        let pool = create_test_pool().await;
        let owner = create_test_user(&pool).await;
        let family = create_test_family(&pool, owner.id).await;
        let context = create_test_context(owner.id, family.id, MemberRole::Owner);
        let service = MemberService::new(pool.clone());
        
        // Act
        let result = service.update_member_role(&context, owner.id, MemberRole::Admin).await;
        
        // Assert
        assert!(result.is_err());
        match result.unwrap_err() {
            ServiceError::CannotChangeOwnerRole => (),
            _ => panic!("Expected CannotChangeOwnerRole error"),
        }
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, owner.id).await;
    }
    
    #[tokio::test]
    async fn test_check_permission() {
        // Arrange
        let pool = create_test_pool().await;
        let owner = create_test_user(&pool).await;
        let member = create_test_user(&pool).await;
        let family = create_test_family(&pool, owner.id).await;
        let context = create_test_context(owner.id, family.id, MemberRole::Owner);
        let service = MemberService::new(pool.clone());
        
        // Add member
        service.add_member(&context, member.id, MemberRole::Member).await.unwrap();
        
        // Act
        let can_delete = service.check_permission(member.id, family.id, Permission::DeleteFamily).await.unwrap();
        let can_view = service.check_permission(member.id, family.id, Permission::ViewTransactions).await.unwrap();
        
        // Assert
        assert!(!can_delete); // Member cannot delete family
        assert!(can_view);    // Member can view transactions
        
        // Cleanup
        crate::fixtures::cleanup_test_data(&pool, owner.id).await;
        crate::fixtures::cleanup_test_data(&pool, member.id).await;
    }
}