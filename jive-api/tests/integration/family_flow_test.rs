#[cfg(test)]
mod tests {
    use jive_money_api::{
        models::{
            family::CreateFamilyRequest,
            invitation::{AcceptInvitationRequest, CreateInvitationRequest},
            permission::MemberRole,
        },
        services::{
            auth_service::{AuthService, RegisterRequest, LoginRequest},
            FamilyService,
            InvitationService,
            MemberService,
        },
    };
    use uuid::Uuid;
    
    use crate::fixtures::create_test_pool;
    
    #[tokio::test]
    async fn test_complete_family_flow() {
        let pool = create_test_pool().await;
        
        // 1. 用户注册
        let auth_service = AuthService::new(pool.clone());
        let register_request = RegisterRequest {
            email: format!("user_{}@example.com", Uuid::new_v4()),
            password: "Test123456!".to_string(),
            name: Some("Test User".to_string()),
        };
        
        let user_context = auth_service
            .register_with_family(register_request)
            .await
            .expect("Failed to register user");
        
        let user_id = user_context.user_id;
        let first_family_id = user_context.current_family_id.expect("Should have family");
        
        // 2. 创建第二个Family
        let family_service = FamilyService::new(pool.clone());
        let create_family_request = CreateFamilyRequest {
            name: "Second Family".to_string(),
            currency: Some("EUR".to_string()),
            timezone: Some("Europe/Berlin".to_string()),
            locale: Some("de-DE".to_string()),
        };
        
        let second_family = family_service
            .create_family(user_id, create_family_request)
            .await
            .expect("Failed to create second family");
        
        // 3. 邀请新成员
        let invitation_service = InvitationService::new(pool.clone());
        let member_service = MemberService::new(pool.clone());
        
        // 获取用户在第二个Family的上下文
        let context = member_service
            .get_member_context(user_id, second_family.id)
            .await
            .expect("Failed to get member context");
        
        let invite_request = CreateInvitationRequest {
            invitee_email: format!("invitee_{}@example.com", Uuid::new_v4()),
            role: MemberRole::Member,
            expires_in_days: Some(7),
        };
        
        let invitation = invitation_service
            .create_invitation(&context, invite_request.clone())
            .await
            .expect("Failed to create invitation");
        
        // 4. 新用户注册
        let new_user_register = RegisterRequest {
            email: invite_request.invitee_email.clone(),
            password: "NewUser123456!".to_string(),
            name: Some("New Member".to_string()),
        };
        
        let new_user_context = auth_service
            .register_with_family(new_user_register)
            .await
            .expect("Failed to register new user");
        
        // 5. 接受邀请
        let accept_request = AcceptInvitationRequest {
            invite_code: Some(invitation.invite_code.clone()),
            invite_token: None,
        };
        
        let joined_family_id = invitation_service
            .accept_invitation(
                accept_request.invite_code,
                accept_request.invite_token,
                new_user_context.user_id,
            )
            .await
            .expect("Failed to accept invitation");
        
        assert_eq!(joined_family_id, second_family.id);
        
        // 6. 验证成员关系
        let members = member_service
            .get_family_members(&context)
            .await
            .expect("Failed to get family members");
        
        assert_eq!(members.len(), 2); // Owner + New Member
        
        let new_member = members
            .iter()
            .find(|m| m.user_id == new_user_context.user_id)
            .expect("New member should exist");
        
        assert_eq!(new_member.role, MemberRole::Member);
        assert!(new_member.is_active);
        
        // 7. 切换Family
        let families = family_service
            .get_user_families(user_id)
            .await
            .expect("Failed to get user families");
        
        assert_eq!(families.len(), 2); // Personal + Second Family
        
        family_service
            .switch_family(user_id, first_family_id)
            .await
            .expect("Failed to switch family");
        
        // Cleanup
        sqlx::query("DELETE FROM users WHERE id IN ($1, $2)")
            .bind(user_id)
            .bind(new_user_context.user_id)
            .execute(&pool)
            .await
            .expect("Failed to cleanup");
    }
    
    #[tokio::test]
    async fn test_permission_flow() {
        let pool = create_test_pool().await;
        
        // 设置测试环境
        let auth_service = AuthService::new(pool.clone());
        let owner_email = format!("owner_{}@example.com", Uuid::new_v4());
        let admin_email = format!("admin_{}@example.com", Uuid::new_v4());
        let member_email = format!("member_{}@example.com", Uuid::new_v4());
        
        // 创建Owner
        let owner = auth_service
            .register_with_family(RegisterRequest {
                email: owner_email.clone(),
                password: "Owner123456!".to_string(),
                name: Some("Owner".to_string()),
            })
            .await
            .expect("Failed to register owner");
        
        let family_id = owner.current_family_id.expect("Should have family");
        
        // 创建Admin和Member
        let admin = auth_service
            .register_with_family(RegisterRequest {
                email: admin_email.clone(),
                password: "Admin123456!".to_string(),
                name: Some("Admin".to_string()),
            })
            .await
            .expect("Failed to register admin");
        
        let member = auth_service
            .register_with_family(RegisterRequest {
                email: member_email.clone(),
                password: "Member123456!".to_string(),
                name: Some("Member".to_string()),
            })
            .await
            .expect("Failed to register member");
        
        // 添加到同一个Family
        let member_service = MemberService::new(pool.clone());
        let owner_context = member_service
            .get_member_context(owner.user_id, family_id)
            .await
            .expect("Failed to get owner context");
        
        member_service
            .add_member(&owner_context, admin.user_id, MemberRole::Admin)
            .await
            .expect("Failed to add admin");
        
        member_service
            .add_member(&owner_context, member.user_id, MemberRole::Member)
            .await
            .expect("Failed to add member");
        
        // 测试权限
        use jive_money_api::models::permission::Permission;
        
        // Owner可以删除Family
        assert!(owner_context.can_perform(Permission::DeleteFamily));
        
        // Admin不能删除Family
        let admin_context = member_service
            .get_member_context(admin.user_id, family_id)
            .await
            .expect("Failed to get admin context");
        assert!(!admin_context.can_perform(Permission::DeleteFamily));
        assert!(admin_context.can_perform(Permission::InviteMembers));
        
        // Member不能邀请成员
        let member_context = member_service
            .get_member_context(member.user_id, family_id)
            .await
            .expect("Failed to get member context");
        assert!(!member_context.can_perform(Permission::InviteMembers));
        assert!(member_context.can_perform(Permission::ViewTransactions));
        
        // Cleanup
        sqlx::query("DELETE FROM users WHERE id IN ($1, $2, $3)")
            .bind(owner.user_id)
            .bind(admin.user_id)
            .bind(member.user_id)
            .execute(&pool)
            .await
            .expect("Failed to cleanup");
    }
    
    #[tokio::test]
    async fn test_invitation_expiry() {
        let pool = create_test_pool().await;
        
        // 创建用户和Family
        let auth_service = AuthService::new(pool.clone());
        let user = auth_service
            .register_with_family(RegisterRequest {
                email: format!("user_{}@example.com", Uuid::new_v4()),
                password: "Test123456!".to_string(),
                name: Some("Test User".to_string()),
            })
            .await
            .expect("Failed to register user");
        
        let family_id = user.current_family_id.expect("Should have family");
        
        // 创建过期的邀请
        let invitation_service = InvitationService::new(pool.clone());
        let member_service = MemberService::new(pool.clone());
        let context = member_service
            .get_member_context(user.user_id, family_id)
            .await
            .expect("Failed to get context");
        
        let invite_request = CreateInvitationRequest {
            invitee_email: format!("expired_{}@example.com", Uuid::new_v4()),
            role: MemberRole::Member,
            expires_in_days: Some(-1), // 已过期
        };
        
        let invitation = invitation_service
            .create_invitation(&context, invite_request)
            .await
            .expect("Failed to create invitation");
        
        // 尝试接受过期的邀请
        let new_user = auth_service
            .register_with_family(RegisterRequest {
                email: format!("new_{}@example.com", Uuid::new_v4()),
                password: "New123456!".to_string(),
                name: Some("New User".to_string()),
            })
            .await
            .expect("Failed to register new user");
        
        let result = invitation_service
            .accept_invitation(
                Some(invitation.invite_code),
                None,
                new_user.user_id,
            )
            .await;
        
        // 应该失败
        assert!(result.is_err());
        match result.unwrap_err() {
            jive_money_api::services::ServiceError::InvitationExpired => (),
            _ => panic!("Expected InvitationExpired error"),
        }
        
        // Cleanup
        sqlx::query("DELETE FROM users WHERE id IN ($1, $2)")
            .bind(user.user_id)
            .bind(new_user.user_id)
            .execute(&pool)
            .await
            .expect("Failed to cleanup");
    }
}