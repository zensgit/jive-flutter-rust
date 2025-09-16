Title: PR3 – Frontend wiring for Category APIs with caching

Problem
- Flutter uses integrated category service stubs; needs wiring to new backend endpoints and cache strategy.

Changes (planned)
- Service: implement list/create/update/delete/reorder/import in `lib/services/api/category_service_integrated.dart` against /api/v1/categories.*
- Providers: add `userCategoriesProvider` with family/ledger scoping and in-memory cache + stale-while-revalidate.
- UI: hook category screens to provider; optimistic updates with rollback on failure.
- Error UX: show conflict when deleting category in use; guide to reassign.

Files (tentative)
- jive-flutter/lib/services/api/category_service_integrated.dart
- jive-flutter/lib/providers/category_provider.dart (new)
- jive-flutter/lib/screens/management/category_management_page.dart (wire actions)
- jive-flutter/lib/widgets/draggable_category_list.dart (use reorder API)

Validation
- Run app with API in dev mode (CORS_DEV=1).
- Verify CRUD + reorder flows; confirm cache refresh after mutations.

Rollback Plan
- Revert provider and service changes; UI falls back to local list.

