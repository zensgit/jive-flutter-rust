Title: chore(api): feature-gate demo/placeholder modules to reduce #[allow] usage

Goal
- Move demo/placeholder routes and helper modules behind an explicit Cargo feature (e.g., `demo_endpoints`) so they are compiled only when needed, reducing the need for broad #[allow(dead_code)].
- No behavior changes for default builds; feature stays enabled by default initially. CI can later turn it off in clippy steps to keep lint clean without #[allow] noise.

Scope
- Handlers: placeholder.rs (and any other clearly demo-only endpoints).
- Optionally include: enhanced_profile.rs demo sections, tag_handler.rs sample utilities if not wired.
- Services: scheduled_tasks.rs (dev scheduler), avatar_service.rs demo helpers if not used in release.

Approach
1) Cargo feature
   - Add `demo_endpoints` feature in jive-api/Cargo.toml with `default-features = ["demo_endpoints"]` for now.
2) Gate modules
   - In handlers/mod.rs: `#[cfg(feature = "demo_endpoints")] pub mod placeholder;`
   - In main.rs: route wiring under `#[cfg(feature = "demo_endpoints")]` blocks.
3) Narrow allows
   - Remove broad module-level `#![allow(dead_code)]` in handlers/services/models roots where coverage is improved by gating.
   - Add targeted `#[allow(dead_code)]` only to the remaining unreferenced items.
4) CI toggle (follow-up)
   - In Rust clippy job, pass `--no-default-features` or `--features ""` to exclude demo code paths, once confirmed safe.

Verification
- cargo check/test/clippy pass with defaults (feature on).
- cargo check/test/clippy pass with `--no-default-features` (feature off) ensuring main API still compiles.

Notes
- Start with placeholder.rs and visibly demo-only endpoints to avoid risk.
- Do not move business endpoints behind the feature.

Checklist
- [ ] Add `demo_endpoints` feature
- [ ] Gate placeholder.rs in module and router
- [ ] Trim broad `#![allow(dead_code)]` where no longer needed
- [ ] Validate both feature on/off builds
- [ ] Consider CI clippy using feature-off build

