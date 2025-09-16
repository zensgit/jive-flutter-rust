Title: PR4 – Category advanced behavior (delete/reassign, merge, audit)

Scope
- Safe deletion with reassignment target; forbid when in use without explicit reassignment.
- Merge categories; convert between category and tag per design doc.
- Permission checks (owner/admin), audit trail records.
- Template import idempotency and update flow.

API (planned)
- DELETE /api/v1/categories/:id?reassign_to=:id (soft delete + reassignment).
- POST /api/v1/categories/merge {source_ids:[], target_id}
- POST /api/v1/categories/convert {from:"tag"|"category", id, target_classification}

DB
- Add audit logs for category ops (reuse audit table).
- Constraints and indexes for reassignment performance.

Validation
- Cargo tests for merge/reassign edge cases.
- UI confirmations, undo snackbar for 5s window when feasible.

Rollback Plan
- Endpoints are additive; can be disabled by routing.

