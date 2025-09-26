// Jive Core - Rust API Server

use std::net::SocketAddr;

fn main() {
    println!("Starting Jive API Server...");

    // 设置日志
    env_logger::init();

    // 获取配置
    let port = std::env::var("API_PORT")
        .unwrap_or_else(|_| "8080".to_string())
        .parse::<u16>()
        .expect("Invalid port number");

    let addr = SocketAddr::from(([127, 0, 0, 1], port));

    println!("Jive API Server running at http://{}", addr);

    // 简单的服务器占位，实际应用需要使用 Actix-web 或 Rocket
    println!("Server is ready to accept connections");

    // 保持程序运行
    loop {
        std::thread::sleep(std::time::Duration::from_secs(60));
    }
}
