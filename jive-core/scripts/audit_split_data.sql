-- Historical Data Audit Script
-- Purpose: Check for existing data integrity issues in transaction splits
-- Created: 2025-10-14
-- Usage: psql -h localhost -p 5432 -U postgres -d jive_money -f audit_split_data.sql

\echo '=========================================='
\echo 'Transaction Split Data Integrity Audit'
\echo 'Started at:' `date`
\echo '=========================================='
\echo ''

-- Check 1: Splits with sum exceeding original amount
\echo '============================================'
\echo 'CHECK 1: Splits Exceeding Original Amount'
\echo '============================================'

WITH split_sums AS (
    SELECT
        ts.original_transaction_id,
        e_orig.amount::numeric as original_amount,
        SUM(e_split.amount::numeric) as split_total,
        COUNT(*) as split_count
    FROM transaction_splits ts
    JOIN entries e_orig ON e_orig.entryable_id = ts.original_transaction_id
        AND e_orig.entryable_type = 'Transaction'
    JOIN entries e_split ON e_split.entryable_id = ts.split_transaction_id
        AND e_split.entryable_type = 'Transaction'
    WHERE ts.deleted_at IS NULL
      AND e_orig.deleted_at IS NULL
      AND e_split.deleted_at IS NULL
    GROUP BY ts.original_transaction_id, e_orig.amount
    HAVING SUM(e_split.amount::numeric) > e_orig.amount::numeric
)
SELECT
    'CRITICAL' as severity,
    original_transaction_id,
    original_amount,
    split_total,
    split_total - original_amount as excess_amount,
    split_count
FROM split_sums
ORDER BY excess_amount DESC;

\echo ''
\echo 'Summary: If any rows returned, these transactions have money creation issues!'
\echo ''

-- Check 2: Negative or zero amounts
\echo '========================================'
\echo 'CHECK 2: Negative or Zero Amounts'
\echo '========================================'

SELECT
    'HIGH' as severity,
    id as entry_id,
    entryable_id as transaction_id,
    amount::numeric,
    'Negative/Zero amount in entry' as issue
FROM entries
WHERE amount::numeric <= 0
  AND deleted_at IS NULL
  AND entryable_type = 'Transaction'
ORDER BY amount::numeric;

\echo ''
\echo 'Summary: All amounts should be positive!'
\echo ''

-- Check 3: Duplicate split records
\echo '========================================'
\echo 'CHECK 3: Duplicate Split Records'
\echo '========================================'

WITH duplicate_splits AS (
    SELECT
        original_transaction_id,
        COUNT(*) as split_count
    FROM transaction_splits
    WHERE deleted_at IS NULL
    GROUP BY original_transaction_id
    HAVING COUNT(*) > 2
)
SELECT
    'MEDIUM' as severity,
    ds.original_transaction_id,
    ds.split_count,
    ARRAY_AGG(ts.split_transaction_id) as split_ids
FROM duplicate_splits ds
JOIN transaction_splits ts ON ts.original_transaction_id = ds.original_transaction_id
WHERE ts.deleted_at IS NULL
GROUP BY ds.original_transaction_id, ds.split_count
ORDER BY ds.split_count DESC;

\echo ''
\echo 'Summary: Transactions with unusual number of splits (>2)'
\echo ''

-- Check 4: Orphaned split records
\echo '========================================'
\echo 'CHECK 4: Orphaned Split Records'
\echo '========================================'

SELECT
    'MEDIUM' as severity,
    ts.id as split_id,
    ts.original_transaction_id,
    ts.split_transaction_id,
    'Original transaction not found' as issue
FROM transaction_splits ts
LEFT JOIN transactions t ON t.id = ts.original_transaction_id
WHERE t.id IS NULL
  AND ts.deleted_at IS NULL;

\echo ''

SELECT
    'MEDIUM' as severity,
    ts.id as split_id,
    ts.original_transaction_id,
    ts.split_transaction_id,
    'Split transaction not found' as issue
FROM transaction_splits ts
LEFT JOIN transactions t ON t.id = ts.split_transaction_id
WHERE t.id IS NULL
  AND ts.deleted_at IS NULL;

\echo ''
\echo 'Summary: Split records referencing non-existent transactions'
\echo ''

-- Check 5: Entry-Transaction consistency
\echo '========================================'
\echo 'CHECK 5: Entry-Transaction Consistency'
\echo '========================================'

SELECT
    'HIGH' as severity,
    t.id as transaction_id,
    t.entry_id,
    'Transaction references non-existent entry' as issue
FROM transactions t
LEFT JOIN entries e ON e.id = t.entry_id
WHERE e.id IS NULL;

\echo ''

SELECT
    'HIGH' as severity,
    e.id as entry_id,
    e.entryable_id as transaction_id,
    'Entry references non-existent transaction' as issue
FROM entries e
LEFT JOIN transactions t ON t.id = e.entryable_id
WHERE e.entryable_type = 'Transaction'
  AND t.id IS NULL
  AND e.deleted_at IS NULL;

\echo ''
\echo 'Summary: Entry-Transaction relationship integrity'
\echo ''

-- Check 6: Split amount consistency
\echo '========================================'
\echo 'CHECK 6: Split Amount Consistency'
\echo '========================================'

WITH split_amounts AS (
    SELECT
        ts.id as split_record_id,
        ts.original_transaction_id,
        ts.split_transaction_id,
        ts.amount as recorded_amount,
        e.amount as actual_amount
    FROM transaction_splits ts
    JOIN entries e ON e.entryable_id = ts.split_transaction_id
        AND e.entryable_type = 'Transaction'
    WHERE ts.deleted_at IS NULL
      AND e.deleted_at IS NULL
)
SELECT
    'MEDIUM' as severity,
    split_record_id,
    original_transaction_id,
    split_transaction_id,
    recorded_amount::numeric,
    actual_amount::numeric,
    'Amount mismatch between split record and entry' as issue
FROM split_amounts
WHERE recorded_amount::numeric != actual_amount::numeric;

\echo ''
\echo 'Summary: Split records should match entry amounts'
\echo ''

-- Summary Statistics
\echo '========================================'
\echo 'SUMMARY STATISTICS'
\echo '========================================'

\echo 'Total Statistics:'

SELECT
    (SELECT COUNT(*) FROM transactions) as total_transactions,
    (SELECT COUNT(*) FROM transaction_splits WHERE deleted_at IS NULL) as total_split_records,
    (SELECT COUNT(DISTINCT original_transaction_id) FROM transaction_splits WHERE deleted_at IS NULL) as transactions_with_splits,
    (SELECT COUNT(*) FROM entries WHERE deleted_at IS NULL AND entryable_type = 'Transaction') as active_entries;

\echo ''
\echo 'Split Statistics by Count:'

SELECT
    split_count,
    COUNT(*) as transaction_count
FROM (
    SELECT
        original_transaction_id,
        COUNT(*) as split_count
    FROM transaction_splits
    WHERE deleted_at IS NULL
    GROUP BY original_transaction_id
) splits
GROUP BY split_count
ORDER BY split_count;

\echo ''
\echo '========================================'
\echo 'Audit Complete'
\echo 'Finished at:' `date`
\echo '========================================'
\echo ''
\echo 'Action Items:'
\echo '1. Review any CRITICAL severity issues immediately'
\echo '2. Investigate HIGH severity issues'
\echo '3. Plan fixes for MEDIUM severity issues'
\echo '4. Run migration 044_add_split_safety_constraints.sql to prevent future issues'
\echo ''
