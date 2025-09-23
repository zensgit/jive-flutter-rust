# jive-core

Core business logic library for Jive Money application, supporting both WASM (WebAssembly) and server deployments.

## 🏗️ Architecture

jive-core is designed as a dual-mode library that can compile to:
- **WASM** (default): For browser-based Flutter web applications
- **Server** (feature-gated): For backend API services

## 📦 Feature Flags

### Default Mode (WASM)
When compiled without features, jive-core exposes only:
- Domain models and types (`src/domain/`)
- Error definitions and handling
- Pure business logic without I/O operations
- WASM-compatible utilities

```bash
# Default compilation for WASM
cargo build
```

### Server Mode
When compiled with `--features server`, additional modules are exposed:
- Application layer (`src/application/`)
- Infrastructure layer (`src/infrastructure/`)
- Database repositories
- External service integrations
- Full backend functionality

```bash
# Compilation for server deployment
cargo build --features server
```

## 🔧 Usage

### For WASM/Flutter Integration
```toml
[dependencies]
jive-core = { path = "../jive-core" }
```

### For Server/API Integration
```toml
[dependencies]
jive-core = { path = "../jive-core", features = ["server"] }
```

## 🎯 Module Organization

```
src/
├── domain/           # Always available
│   ├── models/      # Domain entities
│   ├── errors/      # Error types
│   └── values/      # Value objects
├── application/     # Server-only (feature = "server")
│   ├── services/    # Business services
│   └── middleware/  # Application middleware
└── infrastructure/  # Server-only (feature = "server")
    ├── entities/    # Database entities
    └── repos/       # Repository implementations
```

## ⚙️ Conditional Compilation

Modules that require server features use conditional compilation:

```rust
#[cfg(feature = "server")]
pub mod application;

#[cfg(feature = "server")]
pub mod infrastructure;
```

## 🧪 Testing

```bash
# Test default mode
cargo test

# Test server mode
cargo test --features server

# Test both modes (CI)
cargo test && cargo test --features server
```

## 🚨 Known Issues

Current compilation errors that need resolution:
1. Module path conflicts (`user` module)
2. Missing module files (middleware, category, payee, tag)
3. Feature gate requirements for certain dependencies

These are being tracked and will be resolved in upcoming updates.

## 📝 Development Guidelines

1. **WASM Compatibility**: Code in `domain/` must be WASM-compatible
2. **Feature Gates**: Use `#[cfg(feature = "server")]` for server-only code
3. **No I/O in Domain**: Keep domain layer pure without I/O operations
4. **Dependency Management**: Server-only dependencies should be feature-gated

## 🔄 Migration Notes

When adding new modules:
1. Decide if it's domain (always available) or application/infrastructure (server-only)
2. Apply appropriate feature gates
3. Update CI configuration if needed
4. Test both compilation modes

## 📊 CI Integration

The CI pipeline tests both modes:
- `cargo check` (default/WASM mode)
- `cargo check --features server` (server mode)

See `.github/workflows/ci.yml` for the `rust-core-check` job configuration.