use anyhow::{Context, Result};
use pinyin::ToPinyin;
use serde::{Deserialize, Serialize};
use sqlx::PgPool;
use std::env;
use std::fs;

#[derive(Debug, Deserialize, Serialize)]
struct BankData {
    extraction_info: ExtractionInfo,
    banks: Vec<BankJson>,
}

#[derive(Debug, Deserialize, Serialize)]
struct ExtractionInfo {
    total_records: u32,
    regular_banks: u32,
    cryptocurrencies: u32,
}

#[derive(Debug, Deserialize, Serialize)]
struct BankJson {
    name: String,
    icon: String,
    name2: Option<String>,
    name3: Option<String>,
}

fn extract_code_from_url(url: &str) -> String {
    url.rsplit('/')
        .next()
        .unwrap_or("unknown")
        .trim_end_matches(".png")
        .to_string()
}

fn to_pinyin_full(text: &str) -> String {
    text.chars()
        .filter_map(|c| c.to_pinyin().map(|p| p.plain().to_lowercase()))
        .collect::<Vec<String>>()
        .join("")
}

fn to_pinyin_abbr(text: &str) -> String {
    text.chars()
        .filter_map(|c| c.to_pinyin().and_then(|p| p.plain().chars().next()))
        .collect::<String>()
        .to_lowercase()
}

#[tokio::main]
async fn main() -> Result<()> {
    dotenv::dotenv().ok();
    tracing_subscriber::fmt::init();

    let database_url = env::var("DATABASE_URL").context("DATABASE_URL must be set")?;

    let json_path = env::var("BANKS_JSON_PATH")
        .unwrap_or_else(|_| "/Users/huazhou/Library/CloudStorage/SynologyDrive-mac/github/resources/banks_complete.json".to_string());

    println!("📖 Reading bank data from: {}", json_path);
    let content = fs::read_to_string(&json_path).context("Failed to read banks JSON file")?;

    println!("🔍 Parsing JSON data...");
    let data: BankData = serde_json::from_str(&content).context("Failed to parse banks JSON")?;

    println!("📊 Statistics:");
    println!("  Total records: {}", data.extraction_info.total_records);
    println!("  Regular banks: {}", data.extraction_info.regular_banks);
    println!(
        "  Cryptocurrencies: {}",
        data.extraction_info.cryptocurrencies
    );

    println!("\n🔌 Connecting to database...");
    let pool = PgPool::connect(&database_url)
        .await
        .context("Failed to connect to database")?;

    println!("📥 Importing {} banks...", data.banks.len());
    let mut success_count = 0;
    let mut error_count = 0;

    for (idx, bank) in data.banks.iter().enumerate() {
        let code = extract_code_from_url(&bank.icon);
        let icon_filename = format!("{}.png", code);

        let name_cn = bank.name2.clone().or_else(|| Some(bank.name.clone()));
        let name_en = bank.name3.clone();

        let name_cn_pinyin = name_cn
            .as_ref()
            .map(|n| to_pinyin_full(n))
            .unwrap_or_default();

        let name_cn_abbr = name_cn
            .as_ref()
            .map(|n| to_pinyin_abbr(n))
            .unwrap_or_default();

        let is_crypto = bank.name.contains("币")
            || bank.name.contains("Coin")
            || bank.name.contains("Token")
            || name_cn.as_ref().map(|n| n.contains("币")).unwrap_or(false);

        let result = sqlx::query!(
            r#"
            INSERT INTO banks (
                code, name, name_cn, name_en,
                name_cn_pinyin, name_cn_abbr,
                icon_filename, icon_url, is_crypto
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
            ON CONFLICT (code) DO UPDATE SET
                name = EXCLUDED.name,
                name_cn = EXCLUDED.name_cn,
                name_en = EXCLUDED.name_en,
                name_cn_pinyin = EXCLUDED.name_cn_pinyin,
                name_cn_abbr = EXCLUDED.name_cn_abbr,
                icon_filename = EXCLUDED.icon_filename,
                icon_url = EXCLUDED.icon_url,
                is_crypto = EXCLUDED.is_crypto,
                updated_at = NOW()
            "#,
            code,
            bank.name,
            name_cn,
            name_en,
            name_cn_pinyin,
            name_cn_abbr,
            icon_filename,
            bank.icon,
            is_crypto
        )
        .execute(&pool)
        .await;

        match result {
            Ok(_) => {
                success_count += 1;
                if (idx + 1) % 50 == 0 {
                    println!("  Imported {} / {} banks...", idx + 1, data.banks.len());
                }
            }
            Err(e) => {
                error_count += 1;
                eprintln!("  ❌ Failed to import {}: {}", bank.name, e);
            }
        }
    }

    println!("\n✅ Import completed!");
    println!("  Success: {}", success_count);
    println!("  Errors: {}", error_count);
    println!("  Total: {}", data.banks.len());

    Ok(())
}
