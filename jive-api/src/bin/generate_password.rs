use argon2::{
    password_hash::{rand_core::OsRng, PasswordHasher, SaltString},
    Argon2,
};
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();
    let password = if args.len() > 1 { &args[1] } else { "test123" };

    println!("Generating hash for password: {}", password);

    // 使用与auth.rs相同的Argon2配置
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();

    match argon2.hash_password(password.as_bytes(), &salt) {
        Ok(hash) => {
            println!("\nGenerated hash:");
            println!("{}", hash);
            println!("\nSQL command to update user:");
            println!(
                "UPDATE users SET password_hash = '{}' WHERE email = 'YOUR_EMAIL';",
                hash
            );
        }
        Err(e) => eprintln!("Error generating hash: {}", e),
    }
}
