# jive-core Feature Conventions

## 📋 Overview

This document defines the feature flag conventions and compilation modes for the jive-core library, which serves as the shared business logic layer for the Jive Money application.

## 🎯 Design Philosophy

jive-core follows a **dual-mode architecture** to support both client-side (WASM) and server-side deployments:

1. **Default Mode (WASM)**: Minimal, pure business logic for browser/Flutter integration
2. **Server Mode**: Full backend functionality with I/O, database, and external services

## 🏗️ Architecture Layers

### Always Available (Default)
```
src/domain/
├── models/       # Domain entities (User, Account, Transaction, etc.)
├── errors/       # Error types and handling
├── values/       # Value objects (Money, Currency, etc.)
└── traits/       # Domain traits and interfaces
```

### Server-Only (--features server)
```
src/application/
├── services/     # Business services and use cases
├── middleware/   # Application-level middleware
└── ports/        # Input/output ports

src/infrastructure/
├── entities/     # Database entities
├── repos/        # Repository implementations
├── adapters/     # External service adapters
└── persistence/  # Database connections
```

## 🔧 Feature Flag Usage

### In Cargo.toml

#### jive-core/Cargo.toml
```toml
[features]
default = []  # WASM-compatible by default
server = ["sqlx", "redis", "tokio", "hyper"]  # Server dependencies

[dependencies]
# Always included
serde = "1.0"
chrono = "0.4"

# Server-only
sqlx = { version = "0.7", optional = true }
redis = { version = "0.24", optional = true }
```

#### jive-api/Cargo.toml
```toml
[dependencies]
jive-core = { path = "../jive-core", features = ["server"] }
```

#### jive-flutter (when using Rust FFI)
```toml
[dependencies]
jive-core = { path = "../jive-core" }  # No server features
```

## 🛡️ Conditional Compilation

### Module-Level Guards

```rust
// src/lib.rs
pub mod domain;  // Always available

#[cfg(feature = "server")]
pub mod application;

#[cfg(feature = "server")]
pub mod infrastructure;
```

### Function-Level Guards

```rust
impl User {
    // Always available
    pub fn validate_email(&self) -> Result<(), ValidationError> {
        // Pure validation logic
    }

    #[cfg(feature = "server")]
    pub async fn save(&self, db: &Pool) -> Result<(), DbError> {
        // Database operation
    }
}
```

## ✅ Testing Strategy

### Local Development
```bash
# Test WASM mode
cargo test

# Test server mode
cargo test --features server

# Test both
cargo test && cargo test --features server
```

### CI Pipeline
The CI automatically tests both modes via the `rust-core-check` job:
- Matrix strategy: `server: [false, true]`
- Ensures compatibility across compilation targets

## 🚨 Common Pitfalls and Solutions

### Problem: Module Not Found in WASM
```rust
// ❌ Wrong
use crate::infrastructure::db;  // Fails in WASM

// ✅ Correct
#[cfg(feature = "server")]
use crate::infrastructure::db;
```

### Problem: Dependency Conflicts
```rust
// ❌ Wrong - tokio required even in WASM
use tokio::sync::Mutex;

// ✅ Correct - conditional dependency
#[cfg(feature = "server")]
use tokio::sync::Mutex;

#[cfg(not(feature = "server"))]
use std::sync::Mutex;
```

### Problem: Test Failures
```rust
// ❌ Wrong - test requires database
#[test]
async fn test_user_save() {
    // ...
}

// ✅ Correct - gate server tests
#[cfg(feature = "server")]
#[tokio::test]
async fn test_user_save() {
    // ...
}
```

## 📝 Development Guidelines

### Adding New Code

1. **Determine Layer**: Is it domain logic or infrastructure?
2. **Apply Guards**: Use `#[cfg(feature = "server")]` for server-only code
3. **Test Both**: Ensure code compiles in both modes
4. **Document**: Note any feature requirements in comments

### Code Review Checklist

- [ ] Domain code is WASM-compatible
- [ ] Server dependencies are feature-gated
- [ ] No I/O operations in domain layer
- [ ] Tests pass in both compilation modes
- [ ] CI checks pass for rust-core-check job

## 🔄 Migration Path

### Current State (Issues to Fix)
1. Module path conflicts (e.g., `user.rs` vs `user/mod.rs`)
2. Missing conditional compilation guards
3. Unorganized module structure

### Target State
1. Clean separation of domain/application/infrastructure
2. Proper feature gates throughout
3. Both modes compile successfully

### Migration Steps
1. **Phase 1**: Fix module conflicts
2. **Phase 2**: Add feature gates to existing code
3. **Phase 3**: Reorganize into proper layers
4. **Phase 4**: Validate via CI

## 📊 Performance Considerations

### WASM Mode
- Minimize binary size
- Avoid heavy dependencies
- Pure functions only
- No async runtime

### Server Mode
- Full async/await support
- Database connection pooling
- Redis caching
- External API integrations

## 🚀 Future Enhancements

### Planned Features
- `streaming`: Enable streaming exports
- `metrics`: Performance monitoring
- `tracing`: Distributed tracing support

### Potential Refactoring
- Split into multiple crates (jive-domain, jive-application)
- Introduce workspace structure
- Separate WASM and server builds completely

## 📚 References

- [Rust Feature Flags](https://doc.rust-lang.org/cargo/reference/features.html)
- [WASM Bindgen Guide](https://rustwasm.github.io/wasm-bindgen/)
- [Conditional Compilation](https://doc.rust-lang.org/reference/conditional-compilation.html)

---

**Last Updated**: 2025-09-23
**Status**: Active Convention
**Review Schedule**: Quarterly