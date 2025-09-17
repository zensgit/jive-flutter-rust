use uuid::Uuid;
use sqlx::PgPool;

use crate::fixtures::TestEnvironment;

#[tokio::test]
async fn delete_with_reassign_moves_transactions() {
    let env = TestEnvironment::new().await;
    let pool: PgPool = env.pool.clone();
    let ledger_id: Uuid = sqlx::query_scalar("INSERT INTO ledgers (id, family_id, name, is_default, created_by) VALUES ($1,$2,'L',false,$3) RETURNING id")
        .bind(Uuid::new_v4()).bind(env.family.id).bind(env.user.id)
        .fetch_one(&pool).await.unwrap();
    let src = Uuid::new_v4();
    let dst = Uuid::new_v4();
    sqlx::query("INSERT INTO categories (id, ledger_id, name, classification) VALUES ($1,$2,'A','expense')")
        .bind(src).bind(ledger_id).execute(&pool).await.unwrap();
    sqlx::query("INSERT INTO categories (id, ledger_id, name, classification) VALUES ($1,$2,'B','expense')")
        .bind(dst).bind(ledger_id).execute(&pool).await.unwrap();
    // A transaction pointing to src
    let txn = Uuid::new_v4();
    sqlx::query("INSERT INTO transactions (id, family_id, ledger_id, amount, currency, category_id) VALUES ($1,$2,$3,10,'CNY',$4)")
        .bind(txn).bind(env.family.id).bind(ledger_id).bind(src)
        .execute(&pool).await.unwrap();

    // Simulate handler behavior
    let mut tx = pool.begin().await.unwrap();
    sqlx::query("UPDATE transactions SET category_id=$1 WHERE category_id=$2")
        .bind(dst).bind(src).execute(&mut *tx).await.unwrap();
    sqlx::query("UPDATE categories SET is_deleted=true, deleted_at=NOW() WHERE id=$1")
        .bind(src).execute(&mut *tx).await.unwrap();
    tx.commit().await.unwrap();

    let reassigned: (Uuid,) = sqlx::query_as("SELECT category_id FROM transactions WHERE id=$1")
        .bind(txn).fetch_one(&pool).await.unwrap();
    assert_eq!(reassigned.0, dst);

    env.cleanup().await;
}

#[tokio::test]
async fn merge_soft_deletes_sources() {
    let env = TestEnvironment::new().await;
    let pool: PgPool = env.pool.clone();
    let ledger_id: Uuid = sqlx::query_scalar("INSERT INTO ledgers (id, family_id, name, is_default, created_by) VALUES ($1,$2,'L',false,$3) RETURNING id")
        .bind(Uuid::new_v4()).bind(env.family.id).bind(env.user.id)
        .fetch_one(&pool).await.unwrap();
    let tgt = Uuid::new_v4();
    let s1 = Uuid::new_v4();
    let s2 = Uuid::new_v4();
    sqlx::query("INSERT INTO categories (id, ledger_id, name, classification) VALUES ($1,$2,'T','expense')")
        .bind(tgt).bind(ledger_id).execute(&pool).await.unwrap();
    sqlx::query("INSERT INTO categories (id, ledger_id, name, classification) VALUES ($1,$2,'S1','expense')")
        .bind(s1).bind(ledger_id).execute(&pool).await.unwrap();
    sqlx::query("INSERT INTO categories (id, ledger_id, name, classification) VALUES ($1,$2,'S2','expense')")
        .bind(s2).bind(ledger_id).execute(&pool).await.unwrap();

    let mut tx = pool.begin().await.unwrap();
    sqlx::query("UPDATE transactions SET category_id=$1 WHERE category_id = ANY($2)")
        .bind(tgt).bind(&vec![s1, s2]).execute(&mut *tx).await.unwrap();
    sqlx::query("UPDATE categories SET is_deleted=true, deleted_at=NOW() WHERE ledger_id=$1 AND id = ANY($2) AND id <> $3")
        .bind(ledger_id).bind(&vec![s1, s2, tgt]).bind(tgt).execute(&mut *tx).await.unwrap();
    tx.commit().await.unwrap();

    let count: (i64,) = sqlx::query_as("SELECT COUNT(1) FROM categories WHERE is_deleted=true AND id IN ($1,$2)")
        .bind(s1).bind(s2).fetch_one(&pool).await.unwrap();
    assert!(count.0 >= 1);
    env.cleanup().await;
}

