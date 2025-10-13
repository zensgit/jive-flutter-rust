use sqlx::{PgPool};
use uuid::Uuid;

use crate::fixtures::TestEnvironment;

#[tokio::test]
async fn category_unique_index_and_soft_delete_allows_reuse() {
    // Arrange test env and create a ledger under the test family
    let env = TestEnvironment::new().await;
    let pool: PgPool = env.pool.clone();

    let ledger_id = Uuid::new_v4();
    sqlx::query(
        r#"INSERT INTO ledgers (id, family_id, name, is_default, created_by)
           VALUES ($1,$2,'Test Ledger', false, $3)"#
    )
    .bind(ledger_id)
    .bind(env.family.id)
    .bind(env.user.id)
    .execute(&pool)
    .await
    .expect("insert ledger");

    // Insert first active category
    let cat1_id = Uuid::new_v4();
    sqlx::query(
        r#"INSERT INTO categories (id, ledger_id, name, classification, is_deleted)
           VALUES ($1,$2,$3,'expense', false)"#
    )
    .bind(cat1_id)
    .bind(ledger_id)
    .bind("Food")
    .execute(&pool)
    .await
    .expect("insert cat1");

    // Try to insert duplicate (case-insensitive) active category -> should fail due to uq index
    let dup_res = sqlx::query(
        r#"INSERT INTO categories (id, ledger_id, name, classification, is_deleted)
           VALUES ($1,$2,$3,'expense', false)"#
    )
    .bind(Uuid::new_v4())
    .bind(ledger_id)
    .bind("food")
    .execute(&pool)
    .await;
    assert!(dup_res.is_err(), "expected unique index violation for duplicate active name");

    // Soft delete the first, then insert should succeed
    sqlx::query("UPDATE categories SET is_deleted=true, deleted_at=NOW() WHERE id=$1")
        .bind(cat1_id)
        .execute(&pool)
        .await
        .expect("soft delete cat1");

    sqlx::query(
        r#"INSERT INTO categories (id, ledger_id, name, classification, is_deleted)
           VALUES ($1,$2,$3,'expense', false)"#
    )
    .bind(Uuid::new_v4())
    .bind(ledger_id)
    .bind("FOOD")
    .execute(&pool)
    .await
    .expect("insert duplicate after soft delete");

    env.cleanup().await;
}

#[tokio::test]
async fn backfill_positions_assigns_dense_order() {
    let env = TestEnvironment::new().await;
    let pool: PgPool = env.pool.clone();

    let ledger_id = Uuid::new_v4();
    sqlx::query(
        r#"INSERT INTO ledgers (id, family_id, name, is_default, created_by)
           VALUES ($1,$2,'Test Ledger 2', false, $3)"#
    )
    .bind(ledger_id)
    .bind(env.family.id)
    .bind(env.user.id)
    .execute(&pool)
    .await
    .expect("insert ledger");

    // Insert three categories with NULL positions
    for name in ["A", "B", "C"] {
        sqlx::query(
            r#"INSERT INTO categories (id, ledger_id, name, classification, position, is_deleted)
               VALUES ($1,$2,$3,'expense', NULL, false)"#
        )
        .bind(Uuid::new_v4())
        .bind(ledger_id)
        .bind(name)
        .execute(&pool)
        .await
        .expect("insert cat with null position");
    }

    // Run the backfill logic inline (mirrors migration 022)
    sqlx::query(
        r#"
        WITH ranked AS (
          SELECT c.id,
                 ROW_NUMBER() OVER (
                   PARTITION BY c.ledger_id, c.parent_id
                   ORDER BY c.position NULLS LAST, c.created_at NULLS LAST, LOWER(c.name)
                 ) - 1 AS new_pos
          FROM categories c
          WHERE c.is_deleted = false AND c.ledger_id = $1
        )
        UPDATE categories AS c
        SET position = r.new_pos
        FROM ranked r
        WHERE c.id = r.id AND COALESCE(c.position, -1) <> r.new_pos;
        "#
    )
    .bind(ledger_id)
    .execute(&pool)
    .await
    .expect("backfill positions");

    // Validate positions are 0..2 without gaps
    let positions: Vec<i32> = sqlx::query_scalar(
        "SELECT position FROM categories WHERE ledger_id=$1 AND is_deleted=false ORDER BY position"
    )
    .bind(ledger_id)
    .fetch_all(&pool)
    .await
    .expect("fetch positions");

    assert_eq!(positions.len(), 3);
    assert_eq!(positions, vec![0, 1, 2]);

    env.cleanup().await;
}

