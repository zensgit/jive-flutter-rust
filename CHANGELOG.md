# Changelog

## 2025-10-12

### Security: Transactions Domain
- Added payees table and FK from transactions.payee_id (043_create_payees_table.sql).
- Enforced RBAC permissions and family isolation across all transaction endpoints.
- Implemented SQL injection protection for sorting via strict allowlist.
- Added created_by audit field on transaction creation.
- Hardened CSV export against formula injection (ASCII + full-width) and special characters; clarified newline/carriage/tab handling.
- Added docs/TRANSACTION_SECURITY_OVERVIEW.md to summarize the architecture, implementation patterns, and rollout checklist.

