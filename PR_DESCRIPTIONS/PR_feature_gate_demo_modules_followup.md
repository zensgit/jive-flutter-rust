Title: chore(api): tighten feature-gating for demo endpoints and align clippy modes

Summary
- Gate demo/placeholder endpoints behind `demo_endpoints` feature without impacting default build.
- Refactor router construction in `main.rs` to avoid `mut` when feature is off.
- Align local CI script with GitHub Actions: `cargo check --all-features`, then `cargo clippy --no-default-features -D warnings`.

Changes
- jive-api/src/main.rs: build `Router` immutably; apply cfg-gated chain to add demo routes when feature enabled.
- jive-api/src/main_simple_ws.rs: use library modules instead of redeclaring; remove unused imports to satisfy clippy.
- scripts/ci_local.sh: mirror GH Actions rust steps for stability.

Validation
- Local: `SQLX_OFFLINE=true cargo clippy --all-features` passes.
- Local: `SQLX_OFFLINE=true cargo clippy --no-default-features -D warnings` passes.
- GitHub Actions: should remain green (Flutter analyze non-fatal).

Notes
- No behavior changes; endpoints and routes unchanged under default features.
