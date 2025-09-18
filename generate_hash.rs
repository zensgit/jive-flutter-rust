use argon2::{Argon2, PasswordHasher};
use argon2::password_hash::{SaltString, rand_core::OsRng};

fn main() {
    let password = "admin123";
    let salt = SaltString::generate(&mut OsRng);
    let argon2 = Argon2::default();

    let password_hash = argon2.hash_password(password.as_bytes(), &salt)
        .expect("Failed to hash password");

    println!("Password: {}", password);
    println!("Hash: {}", password_hash);
    println!("\nSQL Update Command:");
    println!("UPDATE users SET password_hash = '{}' WHERE email = 'superadmin@jive.money';", password_hash);
}