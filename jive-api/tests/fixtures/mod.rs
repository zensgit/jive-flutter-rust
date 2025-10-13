use chrono::Utc;
use sqlx::{PgPool, Postgres, Transaction};
use uuid::Uuid;

use jive_money_api::{
    models::{
        family::{CreateFamilyRequest, Family},
        membership::FamilyMember,
        permission::{MemberRole, Permission},
    },
    services::{
        auth_service::{AuthService, RegisterRequest},
        FamilyService, ServiceContext,
    },
};

/// 创建测试数据库连接池
pub async fn create_test_pool() -> PgPool {
    // Prefer explicit TEST_DATABASE_URL, then fallback to DATABASE_URL (CI), then a sane default
    let database_url = std::env::var("TEST_DATABASE_URL")
        .or_else(|_| std::env::var("DATABASE_URL"))
        .unwrap_or_else(|_| "postgresql://postgres:postgres@localhost:5432/jive_money_test".to_string());

    PgPool::connect(&database_url)
        .await
        .expect("Failed to connect to test database")
}

/// 创建测试事务（自动回滚）
pub async fn create_test_transaction(pool: &PgPool) -> Transaction<'_, Postgres> {
    pool.begin().await.expect("Failed to begin transaction")
}

/// 测试用户数据
pub struct TestUser {
    pub id: Uuid,
    pub email: String,
    pub password: String,
    pub name: String,
}

impl TestUser {
    pub fn new() -> Self {
        let id = Uuid::new_v4();
        Self {
            id,
            email: format!("test_{}@example.com", id),
            password: "Test123456!".to_string(),
            name: format!("Test User {}", id),
        }
    }
}

/// 测试Family数据
pub struct TestFamily {
    pub id: Uuid,
    pub name: String,
    pub owner_id: Uuid,
    pub invite_code: String,
}

impl TestFamily {
    pub fn new(owner_id: Uuid) -> Self {
        let id = Uuid::new_v4();
        Self {
            id,
            name: format!("Test Family {}", id),
            owner_id,
            invite_code: generate_test_invite_code(),
        }
    }
}

/// 创建测试用户
pub async fn create_test_user(pool: &PgPool) -> TestUser {
    let test_user = TestUser::new();
    
    // 使用Argon2哈希密码
    let password_hash = hash_password(&test_user.password);
    
    sqlx::query(
        r#"
        INSERT INTO users (id, email, name, password_hash, created_at, updated_at)
        VALUES ($1, $2, $3, $4, $5, $6)
        "#
    )
    .bind(test_user.id)
    .bind(&test_user.email)
    .bind(&test_user.name)
    .bind(password_hash)
    .bind(Utc::now())
    .bind(Utc::now())
    .execute(pool)
    .await
    .expect("Failed to create test user");
    
    test_user
}

/// 创建测试Family
pub async fn create_test_family(pool: &PgPool, owner_id: Uuid) -> Family {
    let service = FamilyService::new(pool.clone());
    let request = CreateFamilyRequest {
        name: format!("Test Family {}", Uuid::new_v4()),
        currency: Some("CNY".to_string()),
        timezone: Some("Asia/Shanghai".to_string()),
        locale: Some("zh-CN".to_string()),
    };
    
    service.create_family(owner_id, request)
        .await
        .expect("Failed to create test family")
}

/// 创建测试服务上下文
pub fn create_test_context(user_id: Uuid, family_id: Uuid, role: MemberRole) -> ServiceContext {
    ServiceContext::new(
        user_id,
        family_id,
        role,
        role.default_permissions(),
        "test@example.com".to_string(),
        Some("Test User".to_string()),
    )
}

/// 生成测试邀请码
fn generate_test_invite_code() -> String {
    format!("TEST{:04}", rand::random::<u16>() % 10000)
}

/// 哈希密码（简化版）
fn hash_password(password: &str) -> String {
    use argon2::{
        password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
        Argon2,
    };
    
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();
    
    argon2
        .hash_password(password.as_bytes(), &salt)
        .expect("Failed to hash password")
        .to_string()
}

/// 清理测试数据
pub async fn cleanup_test_data(pool: &PgPool, user_id: Uuid) {
    // 删除用户相关的所有数据（级联删除）
    sqlx::query("DELETE FROM users WHERE id = $1")
        .bind(user_id)
        .execute(pool)
        .await
        .expect("Failed to cleanup test data");
}

/// 创建完整的测试环境
pub struct TestEnvironment {
    pub pool: PgPool,
    pub user: TestUser,
    pub family: Family,
    pub context: ServiceContext,
}

impl TestEnvironment {
    pub async fn new() -> Self {
        let pool = create_test_pool().await;
        let user = create_test_user(&pool).await;
        let family = create_test_family(&pool, user.id).await;
        let context = create_test_context(user.id, family.id, MemberRole::Owner);
        
        Self {
            pool,
            user,
            family,
            context,
        }
    }
    
    pub async fn cleanup(self) {
        cleanup_test_data(&self.pool, self.user.id).await;
    }
}
