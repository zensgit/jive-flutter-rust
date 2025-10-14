-- Test Script for Idempotency Migrations
-- Purpose: Verify that migrations 045 and 046 work correctly
-- Usage: psql -h localhost -U postgres -d jive_money -f test_idempotency_migrations.sql

\echo '=== Testing Idempotency Migrations ==='
\echo ''

-- ============================================================================
-- Test 1: Verify table exists
-- ============================================================================
\echo 'Test 1: Checking if idempotency_records table exists...'

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1 FROM pg_tables
            WHERE schemaname = 'public'
              AND tablename = 'idempotency_records'
        ) THEN '✅ PASS: Table exists'
        ELSE '❌ FAIL: Table does not exist'
    END AS test_result;

\echo ''

-- ============================================================================
-- Test 2: Verify indexes exist
-- ============================================================================
\echo 'Test 2: Checking if indexes exist...'

SELECT
    indexname,
    CASE
        WHEN indexname = 'idempotency_records_pkey' THEN '✅ Primary key index'
        WHEN indexname = 'idx_idempotency_expires' THEN '✅ Expires index'
        WHEN indexname = 'idx_idempotency_operation' THEN '✅ Operation index'
        ELSE '❓ Unknown index'
    END AS status
FROM pg_indexes
WHERE tablename = 'idempotency_records'
ORDER BY indexname;

\echo ''

-- ============================================================================
-- Test 3: Insert test record
-- ============================================================================
\echo 'Test 3: Inserting test record...'

INSERT INTO idempotency_records (
    request_id,
    operation,
    result_payload,
    status_code,
    expires_at
) VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'test_operation',
    '{"test": "data", "amount": "100.50"}',
    201,
    NOW() + INTERVAL '1 hour'
)
ON CONFLICT (request_id) DO NOTHING;

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1 FROM idempotency_records
            WHERE request_id = '550e8400-e29b-41d4-a716-446655440000'
        ) THEN '✅ PASS: Test record inserted'
        ELSE '❌ FAIL: Test record not inserted'
    END AS test_result;

\echo ''

-- ============================================================================
-- Test 4: Query test record
-- ============================================================================
\echo 'Test 4: Querying test record...'

SELECT
    request_id,
    operation,
    result_payload,
    status_code,
    expires_at > NOW() AS is_valid
FROM idempotency_records
WHERE request_id = '550e8400-e29b-41d4-a716-446655440000';

\echo ''

-- ============================================================================
-- Test 5: Test duplicate prevention (upsert)
-- ============================================================================
\echo 'Test 5: Testing duplicate prevention...'

INSERT INTO idempotency_records (
    request_id,
    operation,
    result_payload,
    status_code,
    expires_at
) VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'test_operation_updated',
    '{"test": "updated_data"}',
    200,
    NOW() + INTERVAL '2 hours'
)
ON CONFLICT (request_id) DO UPDATE SET
    operation = EXCLUDED.operation,
    result_payload = EXCLUDED.result_payload,
    status_code = EXCLUDED.status_code,
    expires_at = EXCLUDED.expires_at;

SELECT
    CASE
        WHEN operation = 'test_operation_updated' THEN '✅ PASS: Upsert works'
        ELSE '❌ FAIL: Upsert did not update'
    END AS test_result
FROM idempotency_records
WHERE request_id = '550e8400-e29b-41d4-a716-446655440000';

\echo ''

-- ============================================================================
-- Test 6: Insert expired record
-- ============================================================================
\echo 'Test 6: Inserting expired record...'

INSERT INTO idempotency_records (
    request_id,
    operation,
    result_payload,
    status_code,
    expires_at
) VALUES (
    '650e8400-e29b-41d4-a716-446655440001',
    'expired_operation',
    '{"test": "expired"}',
    200,
    NOW() - INTERVAL '1 hour'  -- Already expired
);

SELECT
    CASE
        WHEN COUNT(*) = 1 THEN '✅ PASS: Expired record inserted'
        ELSE '❌ FAIL: Expired record not inserted'
    END AS test_result
FROM idempotency_records
WHERE request_id = '650e8400-e29b-41d4-a716-446655440001';

\echo ''

-- ============================================================================
-- Test 7: Query only valid records
-- ============================================================================
\echo 'Test 7: Querying only valid (non-expired) records...'

SELECT COUNT(*) AS valid_record_count
FROM idempotency_records
WHERE expires_at > NOW();

SELECT
    CASE
        WHEN COUNT(*) >= 1 THEN '✅ PASS: Can filter valid records'
        ELSE '❌ FAIL: No valid records found'
    END AS test_result
FROM idempotency_records
WHERE expires_at > NOW();

\echo ''

-- ============================================================================
-- Test 8: Test cleanup function (if migration 046 was run)
-- ============================================================================
\echo 'Test 8: Testing cleanup function...'

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_proc
        WHERE proname = 'cleanup_expired_idempotency_records'
    ) THEN
        RAISE NOTICE '✅ Cleanup function exists, testing...';

        -- Run cleanup
        PERFORM cleanup_expired_idempotency_records();

        -- Check if expired record was deleted
        IF NOT EXISTS (
            SELECT 1 FROM idempotency_records
            WHERE request_id = '650e8400-e29b-41d4-a716-446655440001'
        ) THEN
            RAISE NOTICE '✅ PASS: Cleanup function works (expired record deleted)';
        ELSE
            RAISE NOTICE '❌ FAIL: Cleanup function did not delete expired record';
        END IF;
    ELSE
        RAISE NOTICE '⚠️  SKIP: Cleanup function not found (migration 046 not run)';
    END IF;
END $$;

\echo ''

-- ============================================================================
-- Test 9: Performance test (index usage)
-- ============================================================================
\echo 'Test 9: Testing index usage...'

EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM idempotency_records
WHERE expires_at > NOW()
LIMIT 10;

\echo ''

-- ============================================================================
-- Test 10: Check constraints
-- ============================================================================
\echo 'Test 10: Testing check constraints...'

DO $$
BEGIN
    -- Try to insert record with expires_at before created_at (should fail)
    INSERT INTO idempotency_records (
        request_id,
        operation,
        result_payload,
        status_code,
        created_at,
        expires_at
    ) VALUES (
        '750e8400-e29b-41d4-a716-446655440002',
        'invalid_operation',
        '{}',
        200,
        NOW(),
        NOW() - INTERVAL '1 hour'  -- expires_at < created_at
    );

    RAISE NOTICE '❌ FAIL: Check constraint did not prevent invalid data';
EXCEPTION
    WHEN check_violation THEN
        RAISE NOTICE '✅ PASS: Check constraint works (invalid data rejected)';
END $$;

\echo ''

-- ============================================================================
-- Cleanup test data
-- ============================================================================
\echo 'Cleaning up test data...'

DELETE FROM idempotency_records
WHERE request_id IN (
    '550e8400-e29b-41d4-a716-446655440000',
    '650e8400-e29b-41d4-a716-446655440001',
    '750e8400-e29b-41d4-a716-446655440002'
);

SELECT
    CASE
        WHEN COUNT(*) = 0 THEN '✅ Test data cleaned up'
        ELSE '⚠️  Some test data remains'
    END AS cleanup_result
FROM idempotency_records
WHERE request_id IN (
    '550e8400-e29b-41d4-a716-446655440000',
    '650e8400-e29b-41d4-a716-446655440001',
    '750e8400-e29b-41d4-a716-446655440002'
);

\echo ''
\echo '=== All Tests Complete ==='
\echo ''
\echo 'Summary:'
\echo '- Table structure: idempotency_records'
\echo '- Indexes: Primary key + expires + operation'
\echo '- Constraints: Check constraint on expires_at'
\echo '- Cleanup function: Optional (migration 046)'
\echo ''
