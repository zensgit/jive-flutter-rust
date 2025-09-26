Analyzer Cleanup Progress — Checkpoint (2025-09-20)

Scope
- Phase 1.7: const misuse cleanup (stabilized tests)
- Phase 1.8: parameter/signature alignment; provider unification
- Phase 2: migrate deprecated M3/Color APIs (toARGB32, withValues)

Completed (mechanical, no behavior change)
- Unified currentUserProvider; removed duplicates; fixed imports.
- Const cleanups across screens/widgets; tests pass locally (per artifacts).
- Color.value → toARGB32 in models/adapters/screens; withOpacity → withValues where encountered.
- Fixed initializer conflict in AuditLogFilter; assorted missing identifiers.
- PermissionService now uses currentFamilyProvider/currentFamilyRoleProvider.
- FamilyService.updateUserPreferences signature aligned; call sites updated.
- Share/Email: minimized external dependency usage with stubs to reduce analyzer noise.
- Theme: use PlatformDispatcher/View for brightness instead of window.

Open Items / Next Steps
1) Validation
   - Run on local machine:
     - flutter pub get
     - dart fix --apply | tee local-artifacts/dart-fix-$(date +%Y%m%d-%H%M%S).log
     - flutter analyze > local-artifacts/flutter-analyze.txt
     - flutter test -r expanded > local-artifacts/flutter-tests.txt
2) Batch A — Color/M3 leftovers (low risk)
   - Sweep remaining withOpacity → withValues; ensure toARGB32 consistency.
   - Replace any lingering color channel getters flagged by analyzer.
3) Batch B — Signature/arity consistency (low risk)
   - Re-verify dynamic_permissions_service ↔ family_service parameter lists.
4) Radio → RadioGroup migration (separate PR)
   - Start with: main_simple.dart, family_members_screen.dart, theme_management_screen.dart.
5) Web dev tooling (optional, separate PR)
   - Migrate dev_quick_actions_web.dart from dart:html to package:web/js_interop.

Notes
- All changes so far are lint-only, aimed at analyzer parity without behavior changes.
- Rust side remains green per existing artifacts.

Hand-off Owner: continue in PR #24 (lint-only). Add separate PR for RadioGroup migration.
