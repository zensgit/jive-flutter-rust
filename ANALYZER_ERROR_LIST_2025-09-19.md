# Flutter Analyzer错误清单 - PR #24
*生成时间: 2025-09-19 22:10*

## 统计摘要
- **总问题数**: 3,035个
- **Errors**: 934个
- **Warnings**: 137个
- **Info**: 1,964个

## 主要错误类别

### 1. 语法错误 (影响build_runner)
以下文件的语法错误阻塞了build_runner运行：

#### 缺失逗号 (,) - 18个位置
- `lib/ui/components/cards/transaction_card.dart:114`
- `lib/ui/components/dashboard/budget_summary.dart:312`
- `lib/ui/components/transactions/transaction_list_item.dart:48`
- `lib/ui/components/budget/budget_form.dart:198`
- `lib/ui/components/accounts/account_list.dart:255`
- `lib/screens/settings/settings_screen.dart:575`
- `lib/screens/family/family_permissions_audit_screen.dart:212,424`
- `lib/screens/dashboard/dashboard_screen.dart:308`
- `lib/screens/family/family_permissions_editor_screen.dart:554`
- `lib/screens/transactions/transaction_add_screen.dart:214,270`
- `lib/screens/family/family_settings_screen.dart:129,205,215`
- `lib/screens/audit/audit_logs_screen.dart:513`
- `lib/widgets/sheets/generate_invite_code_sheet.dart:203`
- `lib/screens/invitations/invitation_management_screen.dart:329`
- `lib/widgets/tag_edit_dialog.dart:421`
- `lib/screens/budgets/budgets_screen.dart:344`
- `lib/main_simple.dart:2993`
- `lib/widgets/family_switcher.dart:51,98`

#### 缺失分号 (;) - 22个位置
- `lib/ui/components/cards/transaction_card.dart:279`
- `lib/ui/components/dashboard/budget_summary.dart:411`
- `lib/ui/components/transactions/transaction_list_item.dart:165`
- `lib/ui/components/budget/budget_form.dart:420`
- `lib/ui/components/accounts/account_list.dart:302`
- `lib/screens/settings/settings_screen.dart:615`
- `lib/ui/components/accounts/account_form.dart:281,546,630`
- `lib/screens/family/family_permissions_audit_screen.dart:979`
- `lib/models/travel_event.dart:161`
- `lib/models/transaction.dart:192`
- `lib/screens/dashboard/dashboard_screen.dart:349`
- `lib/screens/family/family_permissions_editor_screen.dart:714`
- `lib/screens/transactions/transaction_add_screen.dart:593`
- `lib/screens/management/crypto_selection_page.dart:88`
- `lib/screens/audit/audit_logs_screen.dart:773`
- `lib/widgets/sheets/generate_invite_code_sheet.dart:488`
- `lib/screens/invitations/invitation_management_screen.dart:399`
- `lib/widgets/permission_guard.dart:194,243`
- `lib/widgets/tag_edit_dialog.dart:451`
- `lib/screens/management/travel_event_management_page.dart:573`
- `lib/screens/budgets/budgets_screen.dart:454`
- `lib/widgets/family_switcher.dart:358`

#### 其他语法错误
- `lib/screens/management/travel_event_management_page.dart:503` - 缺失 }
- `lib/widgets/tag_create_dialog.dart:440` - 缺失 ]

### 2. Const相关错误示例 (前100个)

```
lib/main_simple.dart:1832 - invalid_constant
lib/main_simple.dart:1916 - const_with_non_const
lib/main_simple.dart:2993 - undefined_identifier (Selectableconst)
lib/main_simple.dart:3441 - invalid_constant
lib/main_simple.dart:3445 - const_with_non_const
lib/models/transaction.dart:47 - not_initialized_non_nullable_instance_field (getCategoryconst)
lib/models/travel_event.dart:161 - not_initialized_non_nullable_variable (getTemplateconst)
lib/screens/admin/currency_admin_screen.dart:233 - const_with_non_const
lib/screens/admin/currency_admin_screen.dart:372 - invalid_constant
lib/screens/audit/audit_logs_screen.dart:748 - invalid_constant
lib/screens/auth/admin_login_screen.dart:245 - invalid_constant
lib/screens/auth/login_screen.dart:442 - invalid_constant
lib/screens/auth/register_screen.dart:332 - invalid_constant
lib/screens/auth/wechat_register_form_screen.dart:401 - invalid_constant
lib/screens/budgets/budgets_screen.dart:10 - const_constructor_with_non_final_field
```

### 3. 未定义标识符错误
- `currentUserProvider` - 多处未定义
- `AccountClassification` - 多处未定义
- `LoadingWidget` - 不是类
- `AuditService` - 方法未定义

### 4. 类型不匹配错误
- IconData不能赋值给AuditActionType - 多处
- IconData不能赋值给String - 多处

### 5. 缺失导入错误
- `../../widgets/common/loading_widget.dart` - 不存在
- `../../widgets/common/error_widget.dart` - 不存在
- `../../services/audit_service.dart` - 不存在
- `../../utils/date_utils.dart` - 不存在

## 修复优先级

### 🔴 紧急 (阻塞build_runner)
1. 修复所有语法错误（逗号、分号、括号）
2. 移除错误的const标识符（如Selectableconst、getCategoryconst等）

### 🟡 重要
3. 修复未定义的类和方法
4. 修复类型不匹配错误
5. 修复缺失的导入

### 🟢 一般
6. 清理invalid_constant错误
7. 优化const使用

## 下一步行动
1. 先修复语法错误让build_runner能运行
2. 系统性移除错误的const添加
3. 修复导入和类型问题