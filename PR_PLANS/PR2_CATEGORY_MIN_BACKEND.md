Title: PR2 – Minimal backend Category APIs with validation

Problem
- Frontend needs basic category CRUD operations to replace hardcoded data.
- Backend template management exists but lacks category-specific endpoints.
- Need validation rules for category constraints and relationships.

Changes
- Backend: implement /api/v1/categories endpoints (list, create, update, delete).
- Add category validation middleware for name uniqueness and hierarchy rules.
- Database: ensure category tables have proper constraints and indexing.
- Add category reordering endpoint for UI drag-and-drop support.

Files
- jive-api/src/handlers/category_handler.rs: Core CRUD operations
- jive-api/src/models/category.rs: Category data model with validation
- jive-api/src/services/category_service.rs: Business logic layer
- jive-api/src/main.rs: Route registration

Validation
- Run cargo check --all-features and cargo test
- Test endpoints via curl or Postman against local dev server
- Verify category constraints prevent invalid operations

Migration Notes
- Uses existing category table structure; no schema changes needed.

Rollback Plan
- Remove new routes; existing template system continues unchanged.