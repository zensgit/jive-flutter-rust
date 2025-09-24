//! WASM bindings module (stub)
//!
//! This module exists to satisfy `pub mod wasm` behind the `wasm` feature
//! and avoid missing-module compile errors when enabling the `wasm` feature.
//! Actual wasm-exposed functions live in `lib.rs` and other modules guarded
//! with `#[cfg(feature = "wasm")]` and `#[cfg_attr(feature = "wasm", wasm_bindgen)]`.

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

#[cfg(feature = "wasm")]
#[wasm_bindgen]
pub fn ping() -> String {
    "ok".to_string()
}
