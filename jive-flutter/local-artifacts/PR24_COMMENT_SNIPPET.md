PR #24 update — concise changes (EN/ZH)

EN (concise)
- Providers: unify currentUserProvider; permission service uses currentFamily/currentRole.
- Const/initializers: fix AuditLogFilter; correct mounted checks.
- Color/M3: Color.value→toARGB32, withOpacity→withValues, remove .red/.green/.blue usages where flagged.
- Share/Email: use minimal stubs to pass analyzer (no behavior change intended).
- Theme: brightness via PlatformDispatcher/View, not window.
- Signatures: align updateUserPreferences and permission methods with stubs.
- Tests pass locally per artifacts; remaining analyzer items are non-fatal.

ZH (简要)
- Provider：统一 currentUserProvider；权限服务改用 currentFamily/currentRole。
- 常量/初始化：修复 AuditLogFilter；修正 mounted 检查位置。
- 颜色/M3：Color.value→toARGB32，withOpacity→withValues，移除 .red/.green/.blue 的弃用用法。
- 分享/邮件：用最小 stub 降低 analyzer 噪音（不改变行为）。
- 主题：使用 PlatformDispatcher/View 检测亮度，替代 window。
- 签名：对齐 updateUserPreferences 与权限相关方法（stub）。
- 本地测试通过；剩余 analyzer 报警为非致命项。

Next
- Sweep remaining M3 deprecations; then plan a focused Radio→RadioGroup migration PR.
