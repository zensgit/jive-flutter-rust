use std::time::Instant;
use rand::Rng;
use sqlx::{PgPool, postgres::PgPoolOptions};
use chrono::{NaiveDate, Utc};
use rust_decimal::Decimal;
use rust_decimal::prelude::FromPrimitive;

// Simple benchmark harness for export CSV (buffered vs streaming).
// NOT part of CI. Run manually:
//   cargo run --bin benchmark_export_streaming --features export_stream -- \
//      --rows 5000 --database-url postgresql://.../jive_bench

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

    // NOTE: For real benchmark, call HTTP endpoints (buffered vs streaming) via reqwest.
    // Here we only simulate the query cost to establish a baseline.
    let start = Instant::now();
    let count: (i64,) = sqlx::query_as("SELECT COUNT(*) FROM transactions")
        .fetch_one(&pool).await?;
    let dur = start.elapsed();
    println!("Query COUNT(*) took {:?}, total rows {}", dur, count.0);
    println!("(Next step manually: compare curl timings for /export.csv with and without --features export_stream)");
    Ok(())
}

async fn seed(pool: &PgPool, rows: i64) -> anyhow::Result<()> {
    // Expect at least one ledger & account; if not, create minimal scaffolding.
    let ledger_id: Option<(uuid::Uuid,)> = sqlx::query_as("SELECT id FROM ledgers LIMIT 1")
        .fetch_optional(pool).await?;
    let ledger_id = if let Some((id,)) = ledger_id { id } else {
        let user_id = uuid::Uuid::new_v4();
        sqlx::query("INSERT INTO users (id,email,password_hash,name,is_active,created_at,updated_at) VALUES ($1,$2,'placeholder','Bench',true,NOW(),NOW())")
            .bind(user_id).bind(format!("bench_{}@example.com", user_id))
            .execute(pool).await?;
        let fam_id = uuid::Uuid::new_v4();
        sqlx::query("INSERT INTO families (id,name,owner_id,invite_code,member_count,created_at,updated_at) VALUES ($1,'Bench Family',$2,'BENCH',1,NOW(),NOW())")
            .bind(fam_id).bind(user_id).execute(pool).await?;
        sqlx::query("INSERT INTO family_members (family_id,user_id,role,permissions,joined_at) VALUES ($1,$2,'owner','{}',NOW())")
            .bind(fam_id).bind(user_id).execute(pool).await?;
        let l_id = uuid::Uuid::new_v4();
        sqlx::query("INSERT INTO ledgers (id,family_id,name,currency,is_default,is_active,created_by,created_at,updated_at) VALUES ($1,$2,'Bench Ledger','CNY',true,true,$3,NOW(),NOW())")
            .bind(l_id).bind(fam_id).bind(user_id).execute(pool).await?;
        l_id
    };
    let account_id: Option<(uuid::Uuid,)> = sqlx::query_as("SELECT id FROM accounts WHERE ledger_id=$1 LIMIT 1")
        .bind(ledger_id).fetch_optional(pool).await?;
    let account_id = if let Some((id,)) = account_id { id } else {
        let id = uuid::Uuid::new_v4();
        sqlx::query("INSERT INTO accounts (id,ledger_id,name,account_type,currency,current_balance,created_at,updated_at) VALUES ($1,$2,'Bench Account','cash','CNY',0,NOW(),NOW())")
            .bind(id).bind(ledger_id).execute(pool).await?; id
    };
    // Insert transactions
    let mut rng = rand::thread_rng();
    let batch = 1000;
    let mut inserted = 0;
    while inserted < rows {
        let take = std::cmp::min(batch, (rows - inserted) as i64);
        let mut qb = sqlx::QueryBuilder::new("INSERT INTO transactions (id,ledger_id,account_id,transaction_type,amount,currency,transaction_date,description,created_at,updated_at) VALUES ");
        let mut sep = qb.separated(",");
        for _ in 0..take { 
            let id = uuid::Uuid::new_v4();
            let amount = Decimal::from_f64(rng.gen_range(1.0..500.0)).unwrap();
            let date = NaiveDate::from_ymd_opt(2025, 9, rng.gen_range(1..=25)).unwrap();
            sep.push("(").push_bind(id)
                .push(",").push_bind(ledger_id)
                .push(",").push_bind(account_id)
                .push(",'expense',").push_bind(amount)
                .push(",'CNY',").push_bind(date)
                .push(",").push_bind(format!("Bench txn {}", inserted))
                .push(",NOW(),NOW())");
            inserted += 1;
        }
        qb.build().execute(pool).await?;
    }
    println!("Seeded {} transactions (ledger_id={})", rows, ledger_id);
    Ok(())
}

