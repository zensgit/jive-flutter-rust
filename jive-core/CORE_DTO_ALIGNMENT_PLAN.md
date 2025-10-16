# Core DTO/Mapper Alignment Plan (Transactions)

Purpose
- Align jive-core transaction DTOs/mappers with the latest API/core types to restore cargo check and reduce drift.

Scope (PR‑B)
- transaction_results mapping
  - Remove/rename fields no longer present: `transaction_ids`, `from_account_new_balance`, `to_account_new_balance`, etc.
  - Use `from_transaction`/`to_transaction` and `from_balance`/`to_balance` per current structs.
- Import errors
  - Update `ImportError` usages: replace `index`→`row_index`, `error_code`→`external_id`, ensure `error_message` mapping.
- Import policy
  - Replace enum‑like associated items (e.g., `ImportPolicy::SkipDuplicates`) with the current representation in `domain::types::ImportPolicy`.
  - Update parsing/matching logic accordingly.
- JiveError variants
  - Update sites constructing `JiveError::ValidationError` and `JiveError::DatabaseError` to match current struct/fields.

Out of Scope
- Account repository/schema alignment (handled in PR‑A).
- Additional feature changes; this is a refactor for compatibility.

Validation
- `SQLX_OFFLINE=true cargo check --features "server,db"` (core)
- `cargo test -p jive-money-api` and API clippy remain green.
- No behavioral changes expected; compile‑time compatibility only.

Follow‑ups
- After PR‑B merges, consider re‑enabling selective SQLx checks in core modules.

