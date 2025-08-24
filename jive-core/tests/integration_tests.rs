//! Integration tests for Jive Core services
//! 
//! 综合测试验证所有核心服务的功能

use jive_core::*;
use chrono::Utc;

#[tokio::test]
async fn test_complete_user_workflow() {
    println!("🧪 测试完整用户工作流...");
    
    // 1. 创建用户服务
    let user_service = UserService::new();
    let auth_service = AuthService::new();
    
    // 2. 注册新用户
    let mut register_request = RegisterRequest::new(
        "integration_test@example.com".to_string(),
        "Integration Test User".to_string(),
        "TestPassword123".to_string(),
        "TestPassword123".to_string(),
    );
    register_request.set_accept_terms(true);
    
    let auth_response = auth_service._register(register_request).await;
    assert!(auth_response.is_ok(), "用户注册应该成功");
    
    let auth_response = auth_response.unwrap();
    println!("✅ 用户注册成功: {}", auth_response.user.email());
    
    // 3. 登录用户
    let login_request = LoginRequest::new(
        "integration_test@example.com".to_string(),
        "TestPassword123".to_string(),
    );
    
    let login_response = auth_service._login(login_request).await;
    assert!(login_response.is_ok(), "用户登录应该成功");
    
    let login_response = login_response.unwrap();
    println!("✅ 用户登录成功，令牌: {}", &login_response.access_token[..20]);
    
    // 4. 验证访问令牌
    let verified_user = auth_service._verify_token(login_response.access_token.clone()).await;
    assert!(verified_user.is_ok(), "令牌验证应该成功");
    
    println!("✅ 令牌验证成功");
}

#[tokio::test]
async fn test_complete_ledger_workflow() {
    println!("🧪 测试完整账本工作流...");
    
    let ledger_service = LedgerService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 创建账本
    let create_request = CreateLedgerRequest::new(
        "Integration Test Ledger".to_string(),
        "USD".to_string(),
    );
    
    let ledger = ledger_service._create_ledger(create_request, context.clone()).await;
    assert!(ledger.is_ok(), "账本创建应该成功");
    
    let ledger = ledger.unwrap();
    println!("✅ 账本创建成功: {}", ledger.name());
    
    // 2. 获取账本详情
    let retrieved_ledger = ledger_service._get_ledger(ledger.id(), context.clone()).await;
    assert!(retrieved_ledger.is_ok(), "获取账本应该成功");
    
    println!("✅ 账本获取成功");
    
    // 3. 更新账本
    let mut update_request = UpdateLedgerRequest::new();
    update_request.set_name(Some("Updated Test Ledger".to_string()));
    
    let updated_ledger = ledger_service._update_ledger(
        ledger.id(),
        update_request,
        context.clone(),
    ).await;
    assert!(updated_ledger.is_ok(), "账本更新应该成功");
    
    let updated_ledger = updated_ledger.unwrap();
    assert_eq!(updated_ledger.name(), "Updated Test Ledger");
    println!("✅ 账本更新成功");
}

#[tokio::test]
async fn test_complete_account_workflow() {
    println!("🧪 测试完整账户工作流...");
    
    let account_service = AccountService::new();
    let context = ServiceContext::new("test-user-123".to_string())
        .with_ledger("test-ledger-123".to_string());
    
    // 1. 创建账户
    let create_request = CreateAccountRequest::new(
        "Integration Test Account".to_string(),
        AccountType::Checking,
        "USD".to_string(),
    );
    
    let account = account_service._create_account(create_request, context.clone()).await;
    assert!(account.is_ok(), "账户创建应该成功");
    
    let account = account.unwrap();
    println!("✅ 账户创建成功: {}", account.name());
    
    // 2. 更新账户余额
    let updated_account = account_service._update_balance(
        account.id(),
        "1000.00".to_string(),
        context.clone(),
    ).await;
    assert!(updated_account.is_ok(), "账户余额更新应该成功");
    
    let updated_account = updated_account.unwrap();
    assert_eq!(updated_account.balance().to_string(), "1000");
    println!("✅ 账户余额更新成功: {}", updated_account.balance());
    
    // 3. 获取账户列表
    let filter = AccountFilter::new();
    let pagination = PaginationParams::new(1, 10);
    
    let accounts = account_service._search_accounts(filter, pagination, context).await;
    assert!(accounts.is_ok(), "获取账户列表应该成功");
    
    let accounts = accounts.unwrap();
    assert!(!accounts.is_empty(), "应该有至少一个账户");
    println!("✅ 账户列表获取成功，共 {} 个账户", accounts.len());
}

#[tokio::test]
async fn test_complete_transaction_workflow() {
    println!("🧪 测试完整交易工作流...");
    
    let transaction_service = TransactionService::new();
    let context = ServiceContext::new("test-user-123".to_string())
        .with_ledger("test-ledger-123".to_string());
    
    // 1. 创建交易
    let create_request = CreateTransactionRequest::new(
        "Test Transaction".to_string(),
        "100.00".to_string(),
        "from-account-123".to_string(),
        "to-account-456".to_string(),
    );
    
    let transaction = transaction_service._create_transaction(create_request, context.clone()).await;
    assert!(transaction.is_ok(), "交易创建应该成功");
    
    let transaction = transaction.unwrap();
    println!("✅ 交易创建成功: {}", transaction.description());
    
    // 2. 添加标签
    let tagged_transaction = transaction_service._add_tags(
        transaction.id(),
        vec!["test".to_string(), "integration".to_string()],
        context.clone(),
    ).await;
    assert!(tagged_transaction.is_ok(), "添加标签应该成功");
    
    let tagged_transaction = tagged_transaction.unwrap();
    assert_eq!(tagged_transaction.tags().len(), 2);
    println!("✅ 标签添加成功，共 {} 个标签", tagged_transaction.tags().len());
    
    // 3. 搜索交易
    let mut filter = TransactionFilter::new();
    filter.set_search_query(Some("Test".to_string()));
    
    let transactions = transaction_service._search_transactions(
        filter,
        PaginationParams::new(1, 10),
        context,
    ).await;
    assert!(transactions.is_ok(), "搜索交易应该成功");
    
    let transactions = transactions.unwrap();
    assert!(!transactions.is_empty(), "应该找到至少一个交易");
    println!("✅ 交易搜索成功，找到 {} 个交易", transactions.len());
}

#[tokio::test]
async fn test_complete_category_workflow() {
    println!("🧪 测试完整分类工作流...");
    
    let category_service = CategoryService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 创建父分类
    let parent_request = CreateCategoryRequest::new("Parent Category".to_string());
    
    let parent_category = category_service._create_category(parent_request, context.clone()).await;
    assert!(parent_category.is_ok(), "父分类创建应该成功");
    
    let parent_category = parent_category.unwrap();
    println!("✅ 父分类创建成功: {}", parent_category.name());
    
    // 2. 创建子分类
    let mut child_request = CreateCategoryRequest::new("Child Category".to_string());
    child_request.set_parent_id(Some(parent_category.id()));
    
    let child_category = category_service._create_category(child_request, context.clone()).await;
    assert!(child_category.is_ok(), "子分类创建应该成功");
    
    let child_category = child_category.unwrap();
    assert_eq!(child_category.parent_id(), Some(parent_category.id()));
    println!("✅ 子分类创建成功: {}", child_category.name());
    
    // 3. 获取分类树
    let category_tree = category_service._get_category_tree(None, context.clone()).await;
    assert!(category_tree.is_ok(), "获取分类树应该成功");
    
    let tree = category_tree.unwrap();
    println!("✅ 分类树获取成功，共 {} 个根分类", tree.len());
    
    // 4. 建议分类
    let suggestions = category_service._suggest_category(
        "McDonald's Restaurant".to_string(),
        context,
    ).await;
    assert!(suggestions.is_ok(), "分类建议应该成功");
    
    let suggestions = suggestions.unwrap();
    assert!(!suggestions.is_empty(), "应该有分类建议");
    println!("✅ 分类建议成功，共 {} 个建议", suggestions.len());
}

#[tokio::test]
async fn test_service_error_handling() {
    println!("🧪 测试服务错误处理...");
    
    let user_service = UserService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 测试无效邮箱
    let invalid_request = CreateUserRequest::new(
        "invalid-email".to_string(),
        "Test User".to_string(),
        "Password123".to_string(),
    );
    
    let result = user_service._create_user(invalid_request, context.clone()).await;
    assert!(result.is_err(), "无效邮箱应该返回错误");
    
    match result.unwrap_err() {
        JiveError::ValidationError { message } => {
            assert!(message.contains("email"), "错误消息应该提到邮箱");
            println!("✅ 邮箱验证错误处理正确: {}", message);
        }
        _ => panic!("应该是验证错误"),
    }
    
    // 2. 测试空名称
    let empty_name_request = CreateUserRequest::new(
        "test@example.com".to_string(),
        "".to_string(),
        "Password123".to_string(),
    );
    
    let result = user_service._create_user(empty_name_request, context).await;
    assert!(result.is_err(), "空名称应该返回错误");
    
    match result.unwrap_err() {
        JiveError::ValidationError { message } => {
            assert!(message.contains("Name"), "错误消息应该提到名称");
            println!("✅ 名称验证错误处理正确: {}", message);
        }
        _ => panic!("应该是验证错误"),
    }
}

#[tokio::test]
async fn test_service_context_usage() {
    println!("🧪 测试服务上下文使用...");
    
    // 1. 创建带有完整信息的上下文
    let context = ServiceContext::new("user-123".to_string())
        .with_ledger("ledger-456".to_string())
        .with_request_id("req-789".to_string());
    
    assert_eq!(context.user_id, "user-123");
    assert_eq!(context.current_ledger_id, Some("ledger-456".to_string()));
    assert_eq!(context.request_id, Some("req-789".to_string()));
    
    println!("✅ 服务上下文创建和设置正确");
    
    // 2. 测试权限检查
    let auth_service = AuthService::new();
    
    let permission_check = auth_service._check_permission(
        "user-123".to_string(),
        "accounts".to_string(),
        "read".to_string(),
        context,
    ).await;
    
    assert!(permission_check.is_ok(), "权限检查应该成功");
    println!("✅ 权限检查功能正常");
}

#[tokio::test]
async fn test_pagination_and_filtering() {
    println!("🧪 测试分页和过滤功能...");
    
    // 1. 测试分页参数
    let pagination = PaginationParams::new(2, 5);
    assert_eq!(pagination.page(), 2);
    assert_eq!(pagination.per_page(), 5);
    assert_eq!(pagination.offset(), 5);
    
    println!("✅ 分页参数计算正确");
    
    // 2. 测试批量结果
    let mut batch_result = BatchResult::new();
    batch_result.add_success();
    batch_result.add_success();
    batch_result.add_error("Test error".to_string());
    
    assert_eq!(batch_result.total(), 3);
    assert_eq!(batch_result.successful(), 2);
    assert_eq!(batch_result.failed(), 1);
    assert!((batch_result.success_rate() - 66.67).abs() < 0.1);
    
    println!("✅ 批量结果统计正确: 成功率 {:.2}%", batch_result.success_rate());
    
    // 3. 测试服务响应
    let success_response = ServiceResponse::success("test data".to_string());
    assert!(success_response.success);
    assert_eq!(success_response.data, Some("test data".to_string()));
    
    let error_response: ServiceResponse<String> = ServiceResponse::error(
        JiveError::ValidationError { message: "test error".to_string() }
    );
    assert!(!error_response.success);
    assert!(error_response.error.is_some());
    
    println!("✅ 服务响应结构正确");
}

#[tokio::test]
async fn test_business_logic_validation() {
    println!("🧪 测试业务逻辑验证...");
    
    let ledger_service = LedgerService::new();
    let context = ServiceContext::new("user-123".to_string());
    
    // 1. 测试账本权限
    let permission = ledger_service._check_permission("ledger-123".to_string(), context.clone()).await;
    assert!(permission.is_ok(), "权限检查应该成功");
    
    let permission = permission.unwrap();
    assert!(permission.can_edit(), "默认应该有编辑权限");
    assert!(permission.can_admin(), "默认应该有管理权限");
    assert!(permission.can_delete(), "默认应该有删除权限");
    
    println!("✅ 账本权限验证正确");
    
    // 2. 测试用户角色权限
    let auth_service = AuthService::new();
    
    // 测试普通用户权限
    let user_permission = auth_service._check_permission(
        "user-123".to_string(),
        "accounts".to_string(),
        "read".to_string(),
        context.clone(),
    ).await;
    assert!(user_permission.is_ok() && user_permission.unwrap(), "普通用户应该能读取账户");
    
    // 测试管理功能权限
    let admin_permission = auth_service._check_permission(
        "user-123".to_string(),
        "users".to_string(),
        "delete".to_string(),
        context,
    ).await;
    // 默认用户没有管理员权限，应该返回 false
    assert!(admin_permission.is_ok(), "权限检查不应该出错");
    
    println!("✅ 用户权限验证正确");
}

#[tokio::test]
async fn test_data_consistency() {
    println!("🧪 测试数据一致性...");
    
    // 1. 测试用户数据一致性
    let user = User::new("test@example.com".to_string(), "Test User".to_string());
    assert!(user.is_ok(), "用户创建应该成功");
    
    let mut user = user.unwrap();
    let original_updated_at = user.updated_at;
    
    // 模拟时间流逝
    tokio::time::sleep(tokio::time::Duration::from_millis(10)).await;
    
    user.activate();
    assert!(user.updated_at > original_updated_at, "更新时间应该改变");
    assert!(user.is_active(), "用户应该被激活");
    
    println!("✅ 用户数据一致性验证通过");
    
    // 2. 测试账户数据一致性
    let account = Account::builder()
        .name("Test Account".to_string())
        .account_type(AccountType::Checking)
        .currency("USD".to_string())
        .ledger_id("ledger-123".to_string())
        .build();
    
    assert!(account.is_ok(), "账户构建应该成功");
    
    let mut account = account.unwrap();
    assert_eq!(account.balance(), rust_decimal::Decimal::ZERO);
    
    let update_result = account.update_balance(rust_decimal::Decimal::from(1000));
    assert!(update_result.is_ok(), "余额更新应该成功");
    assert_eq!(account.balance(), rust_decimal::Decimal::from(1000));
    
    println!("✅ 账户数据一致性验证通过");
}

// 运行所有集成测试的辅助函数
pub async fn run_all_integration_tests() {
    println!("🚀 开始运行 Jive Core 集成测试...\n");
    
    test_complete_user_workflow().await;
    test_complete_ledger_workflow().await;
    test_complete_account_workflow().await;
    test_complete_transaction_workflow().await;
    test_complete_category_workflow().await;
    test_service_error_handling().await;
    test_service_context_usage().await;
    test_pagination_and_filtering().await;
    test_business_logic_validation().await;
    test_data_consistency().await;
    test_sync_service_workflow().await;
    test_import_service_workflow().await;
    test_export_service_workflow().await;
    test_report_service_workflow().await;
    test_budget_service_workflow().await;
    test_scheduled_transaction_service_workflow().await;
    test_rule_service_workflow().await;
    test_tag_service_workflow().await;
    test_payee_service_workflow().await;
    test_notification_service_workflow().await;
    
    println!("\n🎉 所有集成测试完成！");
    println!("📊 测试覆盖:");
    println!("  ✅ 用户管理工作流");
    println!("  ✅ 账本管理工作流"); 
    println!("  ✅ 账户管理工作流");
    println!("  ✅ 交易管理工作流");
    println!("  ✅ 分类管理工作流");
    println!("  ✅ 同步服务功能");
    println!("  ✅ 导入服务功能");
    println!("  ✅ 导出服务功能");
    println!("  ✅ 报表分析功能");
    println!("  ✅ 预算管理功能");
    println!("  ✅ 定期交易功能");
    println!("  ✅ 规则引擎功能");
    println!("  ✅ 标签管理功能");
    println!("  ✅ 错误处理机制");
    println!("  ✅ 权限验证系统");
    println!("  ✅ 分页和过滤");
    println!("  ✅ 业务逻辑验证");
    println!("  ✅ 数据一致性");
}

#[tokio::test]
async fn test_sync_service_workflow() {
    println!("🧪 测试同步服务工作流...");
    
    let sync_service = SyncService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 开始同步会话
    let session = sync_service.start_sync(context.clone()).await;
    assert!(session.success);
    assert!(session.data.is_some());
    println!("✅ 同步会话启动成功");
    
    // 2. 执行完整同步
    let full_sync_result = sync_service.full_sync(context.clone()).await;
    assert!(full_sync_result.success);
    println!("✅ 完整同步执行成功");
    
    // 3. 获取同步历史
    let history = sync_service.get_sync_history(10, context.clone()).await;
    assert!(history.success);
    assert!(history.data.is_some());
    println!("✅ 同步历史获取成功");
    
    // 4. 检查同步状态
    let status = sync_service.check_sync_status(context).await;
    assert!(status.success);
    println!("✅ 同步状态检查成功");
}

#[tokio::test]
async fn test_import_service_workflow() {
    println!("🧪 测试导入服务工作流...");
    
    let import_service = ImportService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 预览 CSV 导入
    let csv_data = "Date,Description,Amount,Category\n2024-01-01,Test Transaction,-50.00,Food".as_bytes().to_vec();
    let preview = import_service.preview_import(
        csv_data.clone(),
        ImportFormat::CSV,
        context.clone()
    ).await;
    assert!(preview.success);
    assert!(preview.data.is_some());
    println!("✅ CSV 预览成功");
    
    // 2. 开始导入任务
    let config = ImportConfig::default();
    let mappings = Vec::new();
    let task = import_service.start_import(
        csv_data,
        config,
        mappings,
        context.clone()
    ).await;
    assert!(task.success);
    assert!(task.data.is_some());
    println!("✅ 导入任务创建成功");
    
    // 3. 获取导入历史
    let history = import_service.get_import_history(10, context.clone()).await;
    assert!(history.success);
    assert!(history.data.is_some());
    println!("✅ 导入历史获取成功");
    
    // 4. 获取导入模板
    let templates = import_service.get_import_templates(context).await;
    assert!(templates.success);
    println!("✅ 导入模板获取成功");
}

#[tokio::test]
async fn test_export_service_workflow() {
    println!("🧪 测试导出服务工作流...");
    
    let export_service = ExportService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 创建导出任务
    let options = ExportOptions::default();
    let task = export_service.create_export_task(
        "Test Export".to_string(),
        options.clone(),
        context.clone()
    ).await;
    assert!(task.success);
    assert!(task.data.is_some());
    println!("✅ 导出任务创建成功");
    
    // 2. 导出到 CSV
    let csv_config = CsvExportConfig::default();
    let csv_export = export_service.export_to_csv(
        options.clone(),
        csv_config,
        context.clone()
    ).await;
    assert!(csv_export.success);
    assert!(csv_export.data.is_some());
    println!("✅ CSV 导出成功");
    
    // 3. 导出到 JSON
    let json_export = export_service.export_to_json(
        options,
        context.clone()
    ).await;
    assert!(json_export.success);
    assert!(json_export.data.is_some());
    println!("✅ JSON 导出成功");
    
    // 4. 获取导出历史
    let history = export_service.get_export_history(10, context.clone()).await;
    assert!(history.success);
    assert!(history.data.is_some());
    println!("✅ 导出历史获取成功");
    
    // 5. 获取导出模板
    let templates = export_service.get_export_templates(context).await;
    assert!(templates.success);
    println!("✅ 导出模板获取成功");
}

#[tokio::test]
async fn test_report_service_workflow() {
    println!("🧪 测试报表服务工作流...");
    
    let report_service = ReportService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 生成收支报表
    let date_from = chrono::NaiveDate::from_ymd_opt(2024, 1, 1).unwrap();
    let date_to = chrono::NaiveDate::from_ymd_opt(2024, 12, 31).unwrap();
    
    let income_statement = report_service.generate_income_statement(
        date_from,
        date_to,
        context.clone()
    ).await;
    assert!(income_statement.success);
    assert!(income_statement.data.is_some());
    println!("✅ 收支报表生成成功");
    
    // 2. 生成资产负债表
    let balance_sheet = report_service.generate_balance_sheet(
        date_to,
        context.clone()
    ).await;
    assert!(balance_sheet.success);
    assert!(balance_sheet.data.is_some());
    println!("✅ 资产负债表生成成功");
    
    // 3. 生成现金流量表
    let cash_flow = report_service.generate_cash_flow(
        date_from,
        date_to,
        context.clone()
    ).await;
    assert!(cash_flow.success);
    assert!(cash_flow.data.is_some());
    println!("✅ 现金流量表生成成功");
    
    // 4. 生成分类分析
    let category_analysis = report_service.generate_category_analysis(
        date_from,
        date_to,
        context.clone()
    ).await;
    assert!(category_analysis.success);
    assert!(category_analysis.data.is_some());
    println!("✅ 分类分析报表生成成功");
    
    // 5. 生成趋势分析
    let trend_analysis = report_service.generate_trend_analysis(
        12,
        ReportPeriod::Monthly,
        context.clone()
    ).await;
    assert!(trend_analysis.success);
    assert!(trend_analysis.data.is_some());
    println!("✅ 趋势分析报表生成成功");
    
    // 6. 获取报表模板
    let templates = report_service.get_report_templates(context).await;
    assert!(templates.success);
    println!("✅ 报表模板获取成功");
}

#[tokio::test]
async fn test_budget_service_workflow() {
    println!("🧪 测试预算服务工作流...");
    
    let budget_service = BudgetService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 创建预算
    let create_request = CreateBudgetRequest {
        name: "Monthly Budget".to_string(),
        budget_type: BudgetType::Monthly,
        amount: rust_decimal::Decimal::from(5000),
        period_start: chrono::NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
        period_end: chrono::NaiveDate::from_ymd_opt(2024, 1, 31).unwrap(),
        categories: vec!["Food".to_string(), "Transport".to_string()],
        tags: Vec::new(),
        rollover: false,
        alert_enabled: true,
        alert_threshold: rust_decimal::Decimal::from(80),
    };
    
    let budget = budget_service.create_budget(create_request, context.clone()).await;
    assert!(budget.success);
    assert!(budget.data.is_some());
    println!("✅ 预算创建成功");
    
    // 2. 获取预算进度
    if let Some(budget_data) = budget.data {
        let progress = budget_service.get_budget_progress(
            budget_data.id.clone(),
            context.clone()
        ).await;
        assert!(progress.success);
        assert!(progress.data.is_some());
        println!("✅ 预算进度获取成功");
        
        // 3. 获取预算历史
        let history = budget_service.get_budget_history(
            budget_data.id.clone(),
            context.clone()
        ).await;
        assert!(history.success);
        assert!(history.data.is_some());
        println!("✅ 预算历史获取成功");
    }
    
    // 4. 获取预算建议
    let suggestions = budget_service.get_budget_suggestions(
        BudgetType::Monthly,
        context.clone()
    ).await;
    assert!(suggestions.success);
    assert!(suggestions.data.is_some());
    println!("✅ 预算建议获取成功");
    
    // 5. 获取预算模板
    let templates = budget_service.get_budget_templates(context.clone()).await;
    assert!(templates.success);
    assert!(templates.data.is_some());
    println!("✅ 预算模板获取成功");
    
    // 6. 自动分配预算
    let auto_allocate = budget_service.auto_allocate_budget(
        rust_decimal::Decimal::from(10000),
        BudgetType::Monthly,
        context
    ).await;
    assert!(auto_allocate.success);
    assert!(auto_allocate.data.is_some());
    println!("✅ 自动预算分配成功");
}

#[tokio::test]
async fn test_scheduled_transaction_service_workflow() {
    println!("🧪 测试定期交易服务工作流...");
    
    let scheduled_service = ScheduledTransactionService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 创建定期交易
    let create_request = CreateScheduledTransactionRequest {
        name: "Monthly Rent".to_string(),
        description: Some("Apartment rent payment".to_string()),
        amount: rust_decimal::Decimal::from(1500),
        from_account_id: "checking-account".to_string(),
        to_account_id: Some("landlord-account".to_string()),
        category_id: Some("housing".to_string()),
        tags: vec!["rent".to_string(), "fixed".to_string()],
        recurrence_type: RecurrenceType::Monthly,
        recurrence_config: None,
        start_date: chrono::NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
        end_date: None,
        auto_confirm: true,
        reminder_enabled: true,
        reminder_days_before: 3,
    };
    
    let scheduled = scheduled_service.create_scheduled_transaction(
        create_request,
        context.clone()
    ).await;
    assert!(scheduled.success);
    assert!(scheduled.data.is_some());
    println!("✅ 定期交易创建成功");
    
    if let Some(scheduled_data) = scheduled.data {
        // 2. 获取定期交易详情
        let detail = scheduled_service.get_scheduled_transaction(
            scheduled_data.id.clone(),
            context.clone()
        ).await;
        assert!(detail.success);
        assert!(detail.data.is_some());
        println!("✅ 定期交易详情获取成功");
        
        // 3. 执行定期交易
        let execution = scheduled_service.execute_scheduled_transaction(
            scheduled_data.id.clone(),
            context.clone()
        ).await;
        assert!(execution.success);
        assert!(execution.data.is_some());
        println!("✅ 定期交易执行成功");
        
        // 4. 暂停定期交易
        let paused = scheduled_service.pause_scheduled_transaction(
            scheduled_data.id.clone(),
            context.clone()
        ).await;
        assert!(paused.success);
        println!("✅ 定期交易暂停成功");
        
        // 5. 恢复定期交易
        let resumed = scheduled_service.resume_scheduled_transaction(
            scheduled_data.id.clone(),
            context.clone()
        ).await;
        assert!(resumed.success);
        println!("✅ 定期交易恢复成功");
        
        // 6. 获取执行历史
        let history = scheduled_service.get_execution_history(
            scheduled_data.id.clone(),
            10,
            context.clone()
        ).await;
        assert!(history.success);
        println!("✅ 执行历史获取成功");
    }
    
    // 7. 获取即将到期的交易
    let upcoming = scheduled_service.get_upcoming_transactions(
        7,
        context.clone()
    ).await;
    assert!(upcoming.success);
    println!("✅ 即将到期交易获取成功");
    
    // 8. 获取统计信息
    let stats = scheduled_service.get_scheduled_statistics(context.clone()).await;
    assert!(stats.success);
    assert!(stats.data.is_some());
    println!("✅ 统计信息获取成功");
    
    // 9. 批量执行到期交易
    let batch_execution = scheduled_service.execute_due_transactions(context).await;
    assert!(batch_execution.success);
    println!("✅ 批量执行到期交易成功");
}

#[tokio::test]
async fn test_rule_service_workflow() {
    println!("🧪 测试规则引擎服务工作流...");
    
    let rule_service = RuleService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 创建规则
    let create_request = CreateRuleRequest {
        name: "Auto-categorize Groceries".to_string(),
        description: Some("Automatically categorize grocery transactions".to_string()),
        conditions: vec![
            RuleCondition {
                field: "merchant".to_string(),
                operator: ConditionOperator::Contains,
                value: "Walmart".to_string(),
            }
        ],
        condition_logic: ConditionLogic::Any,
        actions: vec![
            RuleAction {
                action_type: ActionType::SetCategory,
                parameters: {
                    let mut params = std::collections::HashMap::new();
                    params.insert("category_id".to_string(), "groceries".to_string());
                    params
                },
            }
        ],
        priority: 100,
        enabled: true,
        auto_apply: true,
        scope: RuleScope::Transactions,
        tags: vec!["auto".to_string(), "categorization".to_string()],
    };
    
    let rule = rule_service.create_rule(create_request, context.clone()).await;
    assert!(rule.success);
    assert!(rule.data.is_some());
    println!("✅ 规则创建成功");
    
    if let Some(rule_data) = rule.data {
        // 2. 获取规则详情
        let detail = rule_service.get_rule(rule_data.id.clone(), context.clone()).await;
        assert!(detail.success);
        assert!(detail.data.is_some());
        println!("✅ 规则详情获取成功");
        
        // 3. 测试规则
        let test_target = RuleTarget::Transaction(TransactionTarget {
            id: "txn_test".to_string(),
            amount: rust_decimal::Decimal::from(50),
            description: "Walmart purchase".to_string(),
            merchant: Some("Walmart".to_string()),
            category_id: None,
            date: chrono::NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
        });
        
        let test_result = rule_service.test_rule(
            rule_data.id.clone(),
            test_target.clone(),
            context.clone()
        ).await;
        assert!(test_result.success);
        assert!(test_result.data.is_some());
        println!("✅ 规则测试成功");
        
        // 4. 执行规则
        let execution = rule_service.execute_rule(
            rule_data.id.clone(),
            test_target,
            context.clone()
        ).await;
        assert!(execution.success);
        assert!(execution.data.is_some());
        assert!(execution.data.unwrap().matched);
        println!("✅ 规则执行成功");
        
        // 5. 获取执行历史
        let history = rule_service.get_execution_history(
            Some(rule_data.id.clone()),
            10,
            context.clone()
        ).await;
        assert!(history.success);
        println!("✅ 执行历史获取成功");
        
        // 6. 获取规则统计
        let stats = rule_service.get_rule_statistics(
            rule_data.id.clone(),
            context.clone()
        ).await;
        assert!(stats.success);
        println!("✅ 规则统计获取成功");
    }
    
    // 7. 获取规则模板
    let templates = rule_service.get_rule_templates(context.clone()).await;
    assert!(templates.success);
    assert!(templates.data.is_some());
    assert!(!templates.data.unwrap().is_empty());
    println!("✅ 规则模板获取成功");
    
    // 8. 批量执行规则
    let batch_target = RuleTarget::Transaction(TransactionTarget {
        id: "txn_batch".to_string(),
        amount: rust_decimal::Decimal::from(100),
        description: "Test transaction".to_string(),
        merchant: Some("Test Store".to_string()),
        category_id: None,
        date: chrono::NaiveDate::from_ymd_opt(2024, 1, 1).unwrap(),
    });
    
    let batch_execution = rule_service.execute_rules(batch_target, context.clone()).await;
    assert!(batch_execution.success);
    println!("✅ 批量规则执行成功");
    
    // 9. 优化规则顺序
    let optimization = rule_service.optimize_rule_order(context).await;
    assert!(optimization.success);
    println!("✅ 规则优化成功");
}

#[tokio::test]
async fn test_tag_service_workflow() {
    println!("🧪 测试标签管理服务工作流...");
    
    let tag_service = TagService::new();
    let context = ServiceContext::new("test-user-123".to_string());
    
    // 1. 创建标签
    let create_request = CreateTagRequest {
        name: "Important".to_string(),
        display_name: Some("⭐ Important".to_string()),
        description: Some("Important items that need attention".to_string()),
        color: Some("#FF6B6B".to_string()),
        icon: Some("⭐".to_string()),
        group_id: None,
        parent_id: None,
        order_index: Some(1),
    };
    
    let tag = tag_service.create_tag(create_request, context.clone()).await;
    assert!(tag.success);
    assert!(tag.data.is_some());
    println!("✅ 标签创建成功");
    
    if let Some(tag_data) = tag.data {
        // 2. 获取标签详情
        let detail = tag_service.get_tag(tag_data.id.clone(), context.clone()).await;
        assert!(detail.success);
        assert!(detail.data.is_some());
        println!("✅ 标签详情获取成功");
        
        // 3. 添加标签到实体
        let associations = tag_service.add_tags_to_entity(
            EntityType::Transaction,
            "txn_test_123".to_string(),
            vec![tag_data.id.clone()],
            context.clone()
        ).await;
        assert!(associations.success);
        println!("✅ 标签关联成功");
        
        // 4. 获取实体的标签
        let entity_tags = tag_service.get_entity_tags(
            EntityType::Transaction,
            "txn_test_123".to_string(),
            context.clone()
        ).await;
        assert!(entity_tags.success);
        assert_eq!(entity_tags.data.unwrap().len(), 1);
        println!("✅ 实体标签获取成功");
        
        // 5. 获取标签统计
        let stats = tag_service.get_tag_statistics(
            tag_data.id.clone(),
            context.clone()
        ).await;
        assert!(stats.success);
        println!("✅ 标签统计获取成功");
        
        // 6. 移除标签
        let removed = tag_service.remove_tags_from_entity(
            EntityType::Transaction,
            "txn_test_123".to_string(),
            vec![tag_data.id.clone()],
            context.clone()
        ).await;
        assert!(removed.success);
        println!("✅ 标签移除成功");
    }
    
    // 7. 创建标签组
    let group_request = CreateTagGroupRequest {
        name: "Priority Tags".to_string(),
        description: Some("Tags for priority levels".to_string()),
        color: Some("#45B7D1".to_string()),
        icon: Some("🏷️".to_string()),
        order_index: Some(1),
    };
    
    let group = tag_service.create_tag_group(group_request, context.clone()).await;
    assert!(group.success);
    println!("✅ 标签组创建成功");
    
    // 8. 获取标签组列表
    let groups = tag_service.list_tag_groups(context.clone()).await;
    assert!(groups.success);
    assert!(!groups.data.unwrap().is_empty());
    println!("✅ 标签组列表获取成功");
    
    // 9. 搜索标签
    let search_results = tag_service.search_tags(
        "Import".to_string(),
        10,
        context.clone()
    ).await;
    assert!(search_results.success);
    println!("✅ 标签搜索成功");
    
    // 10. 获取热门标签
    let popular = tag_service.get_popular_tags(10, context.clone()).await;
    assert!(popular.success);
    println!("✅ 热门标签获取成功");
    
    // 11. 获取标签树
    let tree = tag_service.get_tag_tree(None, context).await;
    assert!(tree.success);
    println!("✅ 标签树获取成功");
}

// 测试收款方服务完整工作流
#[tokio::test]
async fn test_payee_service_workflow() {
    println!("🧪 测试收款方管理服务工作流...");
    
    let mut payee_service = PayeeService::new();
    let context = ServiceContext::new("test-user-payee".to_string());

    // 1. 创建收款方
    let create_request = CreatePayeeRequest {
        name: "星巴克".to_string(),
        display_name: Some("Starbucks".to_string()),
        category: Some("restaurant".to_string()),
        description: Some("全球知名咖啡连锁店".to_string()),
        website: Some("https://www.starbucks.com".to_string()),
        phone: Some("+1-800-STARBUC".to_string()),
        email: Some("info@starbucks.com".to_string()),
        address: Some("Seattle, WA, USA".to_string()),
        logo_url: Some("https://logo.starbucks.com/logo.png".to_string()),
    };

    let payee = payee_service.create_payee(create_request, &context).await.unwrap();
    assert_eq!(payee.name, "星巴克");
    assert_eq!(payee.display_name, Some("Starbucks".to_string()));
    assert_eq!(payee.category, Some("restaurant".to_string()));
    assert!(payee.is_active);
    assert!(!payee.is_verified);
    println!("✅ 收款方创建成功: {}", payee.name);

    // 2. 获取收款方详情
    let retrieved_payee = payee_service.get_payee(&payee.id, &context).await.unwrap();
    assert_eq!(retrieved_payee.id, payee.id);
    assert_eq!(retrieved_payee.name, "星巴克");
    println!("✅ 收款方详情获取成功");

    // 3. 记录使用次数
    payee_service.record_usage(&payee.id, &context).await.unwrap();
    payee_service.record_usage(&payee.id, &context).await.unwrap();

    let updated_payee = payee_service.get_payee(&payee.id, &context).await.unwrap();
    assert_eq!(updated_payee.usage_count, 2);
    assert!(updated_payee.last_used_at.is_some());
    println!("✅ 使用次数记录成功: {}", updated_payee.usage_count);

    // 4. 创建更多收款方用于测试
    let other_payees = vec![
        ("麦当劳", "McDonald's", "restaurant"),
        ("苹果商店", "Apple Store", "retail"),
        ("星期天超市", "Sunday Market", "retail"),
    ];

    for (name, display_name, category) in other_payees {
        let request = CreatePayeeRequest {
            name: name.to_string(),
            display_name: Some(display_name.to_string()),
            category: Some(category.to_string()),
            description: None,
            website: None,
            phone: None,
            email: None,
            address: None,
            logo_url: None,
        };
        payee_service.create_payee(request, &context).await.unwrap();
    }
    println!("✅ 多个收款方创建成功");

    // 5. 搜索收款方
    let search_results = payee_service.search_payees("星", 10, &context).await.unwrap();
    assert_eq!(search_results.len(), 2); // 星巴克 和 星期天超市
    println!("✅ 收款方搜索成功，找到 {} 个结果", search_results.len());

    // 6. 获取热门收款方
    let popular_payees = payee_service.get_popular_payees(5, &context).await.unwrap();
    assert!(!popular_payees.is_empty());
    assert_eq!(popular_payees[0].id, payee.id); // 星巴克使用次数最多
    println!("✅ 热门收款方获取成功");

    // 7. 获取收款方统计
    let stats = payee_service.get_payee_stats(&payee.id, &context).await.unwrap();
    assert_eq!(stats.payee_id, payee.id);
    assert_eq!(stats.name, "星巴克");
    assert_eq!(stats.total_transactions, 2);
    println!("✅ 收款方统计获取成功");

    // 8. 获取收款方建议
    let suggestions = payee_service.suggest_payees("星巴克咖啡购买", 5, &context).await.unwrap();
    assert!(!suggestions.is_empty());
    assert!(suggestions[0].confidence_score > 0.0);
    println!("✅ 收款方建议获取成功，置信度: {:.2}", suggestions[0].confidence_score);

    // 9. 查询收款方列表（带过滤）
    let filter = PayeeFilter {
        category: Some("restaurant".to_string()),
        is_active: Some(true),
        is_verified: None,
        name_contains: None,
        min_usage_count: None,
        created_after: None,
        created_before: None,
    };

    let pagination = PaginationParams::new(1, 10);
    let filtered_payees = payee_service.get_payees(Some(filter), pagination, &context).await.unwrap();
    assert_eq!(filtered_payees.items.len(), 2); // 星巴克和麦当劳
    println!("✅ 带过滤的收款方查询成功，找到 {} 个餐厅类收款方", filtered_payees.items.len());

    // 10. 批量更新状态
    let payee_ids = vec![payee.id.clone()];
    let updated_count = payee_service.batch_update_status(payee_ids, false, &context).await.unwrap();
    assert_eq!(updated_count, 1);
    println!("✅ 批量状态更新成功，更新 {} 个收款方", updated_count);

    println!("✅ PayeeService workflow test completed successfully");
}

// 测试通知服务完整工作流
#[tokio::test]
async fn test_notification_service_workflow() {
    println!("🧪 测试通知管理服务工作流...");
    
    let mut notification_service = NotificationService::new();
    let context = ServiceContext::new("test-user-notification".to_string());

    // 1. 创建通知
    let create_request = CreateNotificationRequest {
        user_id: "test-user-notification".to_string(),
        notification_type: NotificationType::BudgetAlert,
        priority: NotificationPriority::High,
        title: "预算警告".to_string(),
        message: "您的餐饮预算已超出80%".to_string(),
        action_url: Some("/budgets/food".to_string()),
        data: Some("{\"category\": \"food\", \"percentage\": 80}".to_string()),
        channels: vec![NotificationChannel::InApp, NotificationChannel::Email],
        scheduled_at: None,
        expires_at: None,
        template_id: None,
        template_variables: None,
    };

    let notification = notification_service.create_notification(create_request, &context).await.unwrap();
    assert_eq!(notification.title, "预算警告");
    assert_eq!(notification.message, "您的餐饮预算已超出80%");
    assert_eq!(notification.notification_type, NotificationType::BudgetAlert);
    assert_eq!(notification.priority, NotificationPriority::High);
    assert_eq!(notification.status, NotificationStatus::Sent);
    println!("✅ 通知创建成功: {}", notification.title);

    // 2. 获取通知详情
    let retrieved_notification = notification_service.get_notification(&notification.id, &context).await.unwrap();
    assert_eq!(retrieved_notification.id, notification.id);
    assert_eq!(retrieved_notification.title, "预算警告");
    println!("✅ 通知详情获取成功");

    // 3. 标记通知为已读
    notification_service.mark_as_read(&notification.id, &context).await.unwrap();
    let read_notification = notification_service.get_notification(&notification.id, &context).await.unwrap();
    assert_eq!(read_notification.status, NotificationStatus::Read);
    assert!(read_notification.read_at.is_some());
    println!("✅ 通知标记已读成功");

    // 4. 创建多个不同类型的通知
    let notification_types = vec![
        (NotificationType::PaymentReminder, "付款提醒", "您有一笔付款即将到期"),
        (NotificationType::BillDue, "账单到期", "电费账单将在3天后到期"),
        (NotificationType::GoalAchievement, "目标达成", "恭喜您完成了储蓄目标！"),
        (NotificationType::SecurityAlert, "安全警告", "检测到异常登录活动"),
    ];

    let mut created_notifications = Vec::new();
    for (notification_type, title, message) in notification_types {
        let request = CreateNotificationRequest {
            user_id: "test-user-notification".to_string(),
            notification_type,
            priority: NotificationPriority::Medium,
            title: title.to_string(),
            message: message.to_string(),
            action_url: None,
            data: None,
            channels: vec![NotificationChannel::InApp],
            scheduled_at: None,
            expires_at: None,
            template_id: None,
            template_variables: None,
        };
        let created = notification_service.create_notification(request, &context).await.unwrap();
        created_notifications.push(created);
    }
    println!("✅ 多种类型通知创建成功，创建 {} 个通知", created_notifications.len());

    // 5. 查询通知列表（带过滤）
    let filter = NotificationFilter {
        user_id: Some("test-user-notification".to_string()),
        notification_type: None,
        priority: Some(NotificationPriority::High),
        status: None,
        is_read: None,
        channel: None,
        created_after: None,
        created_before: None,
        expires_after: None,
        expires_before: None,
    };

    let pagination = PaginationParams::new(1, 10);
    let high_priority_notifications = notification_service.get_notifications(Some(filter), pagination, &context).await.unwrap();
    assert_eq!(high_priority_notifications.items.len(), 1); // 只有第一个预算警告是高优先级
    println!("✅ 高优先级通知查询成功，找到 {} 个通知", high_priority_notifications.items.len());

    // 6. 批量创建通知
    let bulk_request = BulkNotificationRequest {
        user_ids: vec!["user1".to_string(), "user2".to_string(), "user3".to_string()],
        notification_type: NotificationType::SystemUpdate,
        priority: NotificationPriority::Low,
        title: "系统更新".to_string(),
        message: "系统将在今晚进行维护更新".to_string(),
        action_url: Some("/system/updates".to_string()),
        data: None,
        channels: vec![NotificationChannel::InApp, NotificationChannel::Email],
        scheduled_at: None,
        expires_at: None,
    };

    let bulk_notification_ids = notification_service.create_bulk_notifications(bulk_request, &context).await.unwrap();
    assert_eq!(bulk_notification_ids.len(), 3);
    println!("✅ 批量通知创建成功，创建 {} 个通知", bulk_notification_ids.len());

    // 7. 创建和使用模板
    let template = notification_service.create_template(
        "预算警告模板".to_string(),
        NotificationType::BudgetAlert,
        "{{category}}预算警告".to_string(),
        "您的{{category}}预算已超出{{percentage}}%".to_string(),
        &context,
    ).await.unwrap();
    assert_eq!(template.name, "预算警告模板");
    println!("✅ 通知模板创建成功: {}", template.name);

    // 8. 使用模板创建通知
    let mut template_variables = std::collections::HashMap::new();
    template_variables.insert("category".to_string(), "交通".to_string());
    template_variables.insert("percentage".to_string(), "150".to_string());

    let template_request = CreateNotificationRequest {
        user_id: "test-user-notification".to_string(),
        notification_type: NotificationType::BudgetAlert,
        priority: NotificationPriority::High,
        title: "".to_string(), // 将被模板替换
        message: "".to_string(), // 将被模板替换
        action_url: None,
        data: None,
        channels: vec![NotificationChannel::InApp],
        scheduled_at: None,
        expires_at: None,
        template_id: Some(template.id),
        template_variables: Some(template_variables),
    };

    let template_notification = notification_service.create_notification(template_request, &context).await.unwrap();
    assert_eq!(template_notification.title, "交通预算警告");
    assert_eq!(template_notification.message, "您的交通预算已超出150%");
    println!("✅ 模板通知创建成功: {}", template_notification.title);

    // 9. 获取通知统计
    let stats = notification_service.get_notification_stats(Some("test-user-notification".to_string()), &context).await.unwrap();
    assert!(stats.total_sent >= 6); // 至少6个通知（1个预算警告 + 4个其他类型 + 1个模板通知）
    assert!(stats.total_read >= 1); // 至少1个已读
    println!("✅ 通知统计获取成功，总发送: {}，已读率: {:.1}%", stats.total_sent, stats.read_rate);

    // 10. 批量标记为已读
    let marked_count = notification_service.mark_all_as_read("test-user-notification", &context).await.unwrap();
    assert!(marked_count > 0);
    println!("✅ 批量标记已读成功，标记 {} 个通知", marked_count);

    // 11. 获取模板列表
    let templates = notification_service.get_templates(Some(NotificationType::BudgetAlert), &context).await.unwrap();
    assert!(!templates.is_empty());
    println!("✅ 模板列表获取成功，找到 {} 个预算警告模板", templates.len());

    // 12. 设置用户通知偏好
    let mut preferences = NotificationPreferences::new("test-user-notification".to_string());
    preferences.enabled_channels = vec![NotificationChannel::InApp, NotificationChannel::Email];
    preferences.enabled_types = vec![
        NotificationType::BudgetAlert,
        NotificationType::SecurityAlert,
        NotificationType::PaymentReminder,
    ];
    preferences.quiet_hours_start = Some("22:00".to_string());
    preferences.quiet_hours_end = Some("08:00".to_string());

    notification_service.set_user_preferences(preferences, &context).await.unwrap();
    println!("✅ 用户通知偏好设置成功");

    // 13. 获取用户通知偏好
    let retrieved_preferences = notification_service.get_user_preferences("test-user-notification", &context).await.unwrap();
    assert_eq!(retrieved_preferences.user_id, "test-user-notification");
    assert_eq!(retrieved_preferences.enabled_channels.len(), 2);
    assert_eq!(retrieved_preferences.quiet_hours_start, Some("22:00".to_string()));
    println!("✅ 用户通知偏好获取成功");

    println!("✅ NotificationService workflow test completed successfully");
}