PR #24 — Analyzer Cleanup (Lint-Only) Update Notes

Summary
- Continue Phase 1.7–1.8 (const cleanup, signature alignment, provider unification) and begin Phase 2 (M3/Color APIs) with mechanical changes only. No behavior changes intended.

Key Changes (highlights)
- Providers: unify currentUserProvider; switch to currentFamilyProvider/currentFamilyRoleProvider in permission service.
- Const/Initializer: fix AuditLogFilter initializer conflict; correct mounted checks placement; general const hygiene across widgets.
- Color/M3: replace Color.value → toARGB32() in models/adapters/screens; withOpacity → withValues; remove .red/.green/.blue getters in favor of r/g/b math; keep Material 3 naming consistent in theme.
- Share/Email: reduce external type pressure with minimal stubs to pass analyzer; keep paths ready to flip back to SharePlus/mailer.
- Theme: detect platform brightness via PlatformDispatcher/View instead of window.

Validation
- Run locally (root/jive-flutter):
  - flutter pub get
  - dart fix --apply | tee local-artifacts/dart-fix-$(date +%Y%m%d-%H%M%S).log
  - flutter analyze > local-artifacts/flutter-analyze.txt
  - flutter test -r expanded > local-artifacts/flutter-tests.txt

Open Items / Next Steps
- Batch A (low risk): sweep remaining withOpacity → withValues; ensure toARGB32 consistency; remove any straggler color channel getters if analyzer flags.
- Batch B (low risk): re-verify dynamic_permissions_service ↔ family_service signatures; keep stubs aligned.
- Radio → RadioGroup (separate PR): start with main_simple.dart, family_members_screen.dart, theme_management_screen.dart.
- Web dev tooling (separate PR): migrate dev_quick_actions_web.dart to package:web/js_interop.

Notes
- Rust side remains green per existing artifacts.
- All changes are lint-only and meant to reduce analyzer noise without changing behavior.

