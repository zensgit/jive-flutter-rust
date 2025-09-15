Title: PR1 – Fix login, expose Tag Management, and base currency selection UX

Problem
- Intermittent 401 on /api/v1/auth/login due to missing/partial migrations and superadmin seed inconsistencies.
- Tag Management UI not consistently accessible from Settings in all router entries.
- Base currency selection in CurrencySelectionPage conflicted with ExpansionTile gestures, preventing selection.

Changes
- Backend ops docs: add upsert script for superadmin and reinforce local migration runner.
- Flutter: ensure Settings -> 标签管理 navigates to /settings/tags via app router and settings screen.
- Flutter: when isSelectingBaseCurrency=true, render simple ListTile to allow onTap selection, avoiding ExpansionTile.

Files
- jive-api/scripts/upsert_superadmin.sql (new): Idempotent superadmin upsert + family/ledger.
- jive-flutter/lib/screens/settings/settings_screen.dart: Add 标签管理 entry to Settings.
- jive-flutter/lib/core/router/app_router.dart: Register /settings/tags -> TagManagementPage.
- jive-flutter/lib/screens/management/currency_selection_page.dart: Fix base currency selection UI flow.

Validation
- Run jive-api/scripts/migrate_local.sh --force, then psql -f scripts/upsert_superadmin.sql.
- Verify login via test-login.html and Flutter login screen with superadmin@jive.money / SuperAdmin@123.
- Navigate Settings -> 标签管理 reaches TagManagementPage.
- From currency screens, pick base currency successfully and verify exchange rate calculations remain intact.

Migration Notes
- No schema change in PR1; operational script only.

Rollback Plan
- Revert Flutter UI changes; superadmin upsert script is idempotent and safe to leave.

