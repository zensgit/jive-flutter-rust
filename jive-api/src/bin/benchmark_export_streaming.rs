use std::time::Instant;
use rand::Rng;
use sqlx::{postgres::PgPoolOptions, PgPool};
use chrono::{NaiveDate, Utc};
use rust_decimal::Decimal;
use rust_decimal::prelude::FromPrimitive;

// Run with (streaming enabled):
// cargo run -p jive-money-api --features export_stream --bin benchmark_export_streaming -- --rows 5000 --database-url postgresql://...

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    let mut rows: i64 = 5000;
    let mut db_url = std::env::var("DATABASE_URL").unwrap_or_default();
    let mut args = std::env::args().skip(1);
    while let Some(a) = args.next() {
        match a.as_str() {
            "--rows" => if let Some(v) = args.next() { rows = v.parse().unwrap_or(rows); },
            "--database-url" => if let Some(v) = args.next() { db_url = v; },
            _ => {}
        }
    }
    if db_url.is_empty() { eprintln!("Set --database-url or DATABASE_URL"); std::process::exit(1); }
    let pool = PgPoolOptions::new().max_connections(5).connect(&db_url).await?;

    println!("Preparing benchmark data: {} rows", rows);
    seed(&pool, rows).await?;

    let start = Instant::now();
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM transactions")
        .fetch_one(&pool).await?;
    let dur = start.elapsed();
    println!("COUNT(*) took {:?}, total rows {}", dur, count.0);
    println!("Next: measure export endpoint latency:");
    println!(" curl -s -o /dev/null -H 'Authorization: Bearer $TOKEN' 'http://localhost:8012/api/v1/transactions/export.csv?include_header=false'");
    Ok(())
}

async fn seed(pool: &PgPool, rows: i64) -> anyhow::Result<()> {
    // Ensure baseline data (one user/family/ledger/account)
    let ledger_row: Option<(uuid::Uuid, uuid::Uuid)> = sqlx::query_as("SELECT id, created_by FROM ledgers LIMIT 1")
        .fetch_optional(pool).await?;
    let (ledger_id, user_id) = if let Some(l) = ledger_row { l } else {
        let user_id = uuid::Uuid::new_v4();
        sqlx::query("INSERT INTO users (id,email,password_hash,name,is_active,created_at,updated_at) VALUES ($1,$2,'placeholder','Bench',true,NOW(),NOW())")
            .bind(user_id).bind(format!("bench_{}@example.com", user_id))
            .execute(pool).await?;
        let fam_id = uuid::Uuid::new_v4();
        sqlx::query("INSERT INTO families (id,name,owner_id,invite_code,member_count,created_at,updated_at) VALUES ($1,'Bench Family',$2,'BENCH',1,NOW(),NOW())")
            .bind(fam_id).bind(user_id).execute(pool).await?;
        sqlx::query("INSERT INTO family_members (family_id,user_id,role,permissions,joined_at) VALUES ($1,$2,'owner','{}',NOW())")
            .bind(fam_id).bind(user_id).execute(pool).await?;
        let ledger_id = uuid::Uuid::new_v4();
        sqlx::query("INSERT INTO ledgers (id,family_id,name,currency,is_default,is_active,created_by,created_at,updated_at) VALUES ($1,$2,'Bench Ledger','CNY',true,true,$3,NOW(),NOW())")
            .bind(ledger_id).bind(fam_id).bind(user_id).execute(pool).await?;
        let account_id = uuid::Uuid::new_v4();
        sqlx::query("INSERT INTO accounts (id,ledger_id,name,account_type,currency,current_balance,created_at,updated_at) VALUES ($1,$2,'Bench Account','cash','CNY',0,NOW(),NOW())")
            .bind(account_id).bind(ledger_id).execute(pool).await?;
        (ledger_id, user_id)
    };

    let account_id: (uuid::Uuid,) = sqlx::query_as("SELECT id FROM accounts WHERE ledger_id=$1 LIMIT 1")
        .bind(ledger_id).fetch_one(pool).await?;

    let mut rng = rand::thread_rng();
    let batch_size = 1000;
    let mut inserted = 0;
    while inserted < rows {
        let take = std::cmp::min(batch_size, (rows - inserted) as i64);
        let mut qb = sqlx::QueryBuilder::new("INSERT INTO transactions (id,ledger_id,account_id,transaction_type,amount,currency,transaction_date,description,created_at,updated_at) VALUES ");
        let mut sep = qb.separated(",");
        for _ in 0..take { 
            let id = uuid::Uuid::new_v4();
            let amount = Decimal::from_f64(rng.gen_range(1.0..500.0)).unwrap();
            let date = NaiveDate::from_ymd_opt(2025, 9, rng.gen_range(1..=25)).unwrap();
            sep.push("(").push_bind(id)
                .push(",").push_bind(ledger_id)
                .push(",").push_bind(account_id.0)
                .push(",'expense',").push_bind(amount)
                .push(",'CNY',").push_bind(date)
                .push(",").push_bind(format!("Bench txn {}", inserted))
                .push(",NOW(),NOW())");
            inserted += 1;
        }
        qb.build().execute(pool).await?;
    }
    println!("Seeded {} transactions (ledger_id={}, user_id={})", rows, ledger_id, user_id);
    Ok(())
}

