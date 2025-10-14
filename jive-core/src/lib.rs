//! Jive Core Library
//!
//! This library contains the core business logic for the Jive financial application.
//! It's designed to work across multiple platforms through WASM bindings.

#[cfg(feature = "wasm")]
use wasm_bindgen::prelude::*;

// 导入核心模块
pub mod domain;

// 仅在服务端且启用数据库相关功能时暴露应用层与基础设施层
#[cfg(all(feature = "server", feature = "db"))]
pub mod application;
#[cfg(all(feature = "server", feature = "db"))]
pub mod infrastructure;

// API 适配层 (仅在服务端启用)
#[cfg(feature = "server")]
pub mod api;

#[cfg(feature = "wasm")]
pub mod wasm;

// 重新导出常用类型
pub use domain::*;

// 仅在服务端且启用数据库相关功能时重新导出应用层符号
#[cfg(all(feature = "server", feature = "db"))]
pub use application::*;

// 错误类型
pub mod error;
pub use error::{JiveError, Result};

// 工具模块
pub mod utils;

// WASM 初始化
#[cfg(feature = "wasm")]
#[wasm_bindgen(start)]
pub fn main() {
    // 设置 panic hook 用于更好的错误信息
    #[cfg(feature = "console_error_panic_hook")]
    console_error_panic_hook::set_once();

    // 初始化内存分配器
    #[cfg(feature = "wee_alloc")]
    {
        use wee_alloc::WeeAlloc;
        #[global_allocator]
        static ALLOC: WeeAlloc = WeeAlloc::INIT;
    }

    // 输出启动信息
    #[cfg(feature = "wasm")]
    web_sys::console::log_1(&"Jive Core initialized successfully".into());
}

// 版本信息
pub const VERSION: &str = env!("CARGO_PKG_VERSION");
pub const APP_NAME: &str = "Jive";

/// 获取库信息
#[cfg(feature = "wasm")]
#[wasm_bindgen]
pub fn get_version() -> String {
    VERSION.to_string()
}

#[cfg(feature = "wasm")]
#[wasm_bindgen]
pub fn get_app_name() -> String {
    APP_NAME.to_string()
}

/// 初始化日志（WASM环境）
#[cfg(feature = "wasm")]
#[wasm_bindgen]
pub fn init_logging() {
    web_sys::console::log_1(
        &format!("{} Core v{} - Logging initialized", APP_NAME, VERSION).into(),
    );
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert!(!VERSION.is_empty());
        assert_eq!(APP_NAME, "Jive");
    }

    #[test]
    fn test_library_exports() {
        // 确保所有主要模块都能导入
        use crate::domain::*;
        use crate::error::*;
        use crate::utils::*;
    }
}
