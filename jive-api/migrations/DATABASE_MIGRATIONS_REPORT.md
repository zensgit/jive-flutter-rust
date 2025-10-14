# Database Migrations Report

**Date**: 2025-10-14
**Task**: Task 5 - 编写数据库迁移脚本
**Status**: ✅ COMPLETED

## Executive Summary

Successfully created database migration scripts to support the idempotency framework implemented in jive-core. The migrations provide:

1. **Idempotency Records Table**: Stores API request results for duplicate detection
2. **Cleanup Function**: Optional stored procedure for periodic maintenance
3. **Comprehensive Documentation**: Usage guides, testing scripts, and troubleshooting
4. **Rollback Support**: Down migrations for safe rollback

## Migrations Created

### Migration 045: Create Idempotency Records Table

**File**: `045_create_idempotency_records.sql`

**Purpose**: Creates the core table for storing idempotency records.

**Schema**:

```sql
CREATE TABLE idempotency_records (
    request_id UUID PRIMARY KEY,           -- Idempotency key
    operation VARCHAR(100) NOT NULL,       -- Operation name
    result_payload TEXT NOT NULL,          -- JSON result
    status_code INTEGER,                   -- HTTP status
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,       -- TTL
    CONSTRAINT chk_expires_at CHECK (expires_at > created_at)
);
```

**Indexes Created**:

1. **Primary Key Index** (automatic)
   - On `request_id` column
   - Ensures unique request identifiers
   - Enables O(1) lookup for duplicate detection

2. **idx_idempotency_expires**
   - On `expires_at` column
   - Speeds up cleanup queries: `WHERE expires_at <= NOW()`
   - Critical for periodic maintenance performance

3. **idx_idempotency_operation**
   - On `operation` column
   - Optional index for analytics and monitoring
   - Enables efficient grouping by operation type

**Constraints**:

- **Check Constraint**: `expires_at > created_at`
  - Prevents logical errors (expiry before creation)
  - Ensures data integrity

**Comments**:

Comprehensive table and column comments for documentation:

```sql
COMMENT ON TABLE idempotency_records IS
'Stores idempotency records for duplicate request prevention...';

COMMENT ON COLUMN idempotency_records.request_id IS
'Unique request identifier (idempotency key)...';
```

**Storage Estimates**:

For 1M API requests/month with 24-hour TTL:

- **Active records**: ~40,000 (at any time)
- **Storage per record**: ~200 bytes
- **Table size**: ~8 MB
- **Index overhead**: ~4 MB
- **Total**: ~12 MB

### Migration 046: Create Cleanup Function

**File**: `046_create_idempotency_cleanup_job.sql`

**Purpose**: Provides a stored procedure for periodic cleanup of expired records.

**Function Signature**:

```sql
CREATE OR REPLACE FUNCTION cleanup_expired_idempotency_records()
RETURNS TABLE(deleted_count BIGINT)
```

**Implementation**:

```sql
BEGIN
    DELETE FROM idempotency_records
    WHERE expires_at <= NOW();

    GET DIAGNOSTICS rows_deleted = ROW_COUNT;
    RETURN QUERY SELECT rows_deleted;
END;
```

**Usage**:

```sql
-- Manual cleanup
SELECT * FROM cleanup_expired_idempotency_records();
-- Returns: deleted_count
--          150

-- Scheduled cleanup (with pg_cron)
SELECT cron.schedule(
    'cleanup-idempotency',
    '0 * * * *',  -- Every hour
    $$SELECT cleanup_expired_idempotency_records()$$
);
```

**Alternative**: Application-level cleanup (recommended)

```rust
tokio::spawn(async move {
    let mut interval = tokio::time::interval(Duration::from_secs(3600));

    loop {
        interval.tick().await;
        match repo.cleanup_expired().await {
            Ok(count) => tracing::info!("Cleaned up {} records", count),
            Err(e) => tracing::error!("Cleanup failed: {:?}", e),
        }
    }
});
```

### Rollback Migrations

**045_create_idempotency_records.down.sql**:

```sql
DROP INDEX IF EXISTS idx_idempotency_operation;
DROP INDEX IF EXISTS idx_idempotency_expires;
DROP TABLE IF EXISTS idempotency_records;
```

**046_create_idempotency_cleanup_job.down.sql**:

```sql
-- SELECT cron.unschedule('cleanup-idempotency');
DROP FUNCTION IF EXISTS cleanup_expired_idempotency_records();
```

## Documentation Files

### README_IDEMPOTENCY.md

Comprehensive guide covering:

1. **Overview**: Migration purpose and schema
2. **Usage Examples**: SQL queries for common operations
3. **Running Migrations**: sqlx-cli, psql, Docker methods
4. **Verification**: Testing table and function creation
5. **Performance**: Size estimates and optimization strategies
6. **Security**: Access control and data retention policies
7. **Monitoring**: SQL queries for health checks
8. **Troubleshooting**: Common issues and solutions

**Sections**:

- Migration 045 details
- Migration 046 details
- Running migrations (sqlx, psql, Docker)
- Verification queries
- Performance considerations
- Security best practices
- Monitoring queries
- Troubleshooting guide

### test_idempotency_migrations.sql

Automated test script with 10 test cases:

1. ✅ **Test 1**: Table exists
2. ✅ **Test 2**: Indexes exist (primary key, expires, operation)
3. ✅ **Test 3**: Insert test record
4. ✅ **Test 4**: Query test record
5. ✅ **Test 5**: Duplicate prevention (upsert)
6. ✅ **Test 6**: Insert expired record
7. ✅ **Test 7**: Query only valid records
8. ✅ **Test 8**: Cleanup function works
9. ✅ **Test 9**: Index usage (EXPLAIN ANALYZE)
10. ✅ **Test 10**: Check constraints work

**Running Tests**:

```bash
psql -h localhost -U postgres -d jive_money -f migrations/test_idempotency_migrations.sql
```

**Expected Output**:

```
=== Testing Idempotency Migrations ===

Test 1: Checking if idempotency_records table exists...
✅ PASS: Table exists

Test 2: Checking if indexes exist...
✅ Primary key index
✅ Expires index
✅ Operation index

...

=== All Tests Complete ===
```

## Migration Workflow

### Step 1: Run Migration 045 (Required)

**Using sqlx-cli**:

```bash
cd jive-api
sqlx migrate run --source migrations
```

**Using psql**:

```bash
psql -h localhost -U postgres -d jive_money \
     -f migrations/045_create_idempotency_records.sql
```

**Using Docker**:

```bash
docker exec -i jive-postgres psql -U postgres -d jive_money \
     < migrations/045_create_idempotency_records.sql
```

### Step 2: Verify Migration

```sql
-- Check table
\d idempotency_records

-- Check indexes
SELECT indexname FROM pg_indexes
WHERE tablename = 'idempotency_records';

-- Test insert
INSERT INTO idempotency_records (
    request_id, operation, result_payload, status_code, expires_at
) VALUES (
    gen_random_uuid(), 'test', '{}', 200, NOW() + INTERVAL '1 hour'
);

-- Query
SELECT * FROM idempotency_records LIMIT 1;
```

### Step 3: Run Migration 046 (Optional)

Only if you want database-level cleanup function:

```bash
psql -h localhost -U postgres -d jive_money \
     -f migrations/046_create_idempotency_cleanup_job.sql
```

**Verify**:

```sql
-- Check function exists
\df cleanup_expired_idempotency_records

-- Test function
SELECT * FROM cleanup_expired_idempotency_records();
```

### Step 4: Run Test Script

```bash
psql -h localhost -U postgres -d jive_money \
     -f migrations/test_idempotency_migrations.sql
```

Should see all tests pass (✅).

### Step 5: Configure Cleanup

**Option A: Application-Level (Recommended)**

In `jive-api/src/main.rs`:

```rust
use jive_core::infrastructure::repositories::idempotency_repository::IdempotencyRepository;

// Start background cleanup job
let cleanup_repo = idempotency_repo.clone();
tokio::spawn(async move {
    let mut interval = tokio::time::interval(Duration::from_secs(3600)); // 1 hour

    loop {
        interval.tick().await;

        match cleanup_repo.cleanup_expired().await {
            Ok(count) => {
                if count > 0 {
                    tracing::info!("Cleaned up {} expired idempotency records", count);
                }
            }
            Err(e) => {
                tracing::error!("Idempotency cleanup failed: {:?}", e);
            }
        }
    }
});
```

**Option B: Database-Level (pg_cron)**

If you have pg_cron extension:

```sql
-- Install pg_cron extension (if not already)
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Schedule cleanup every hour
SELECT cron.schedule(
    'cleanup-idempotency',
    '0 * * * *',
    $$SELECT cleanup_expired_idempotency_records()$$
);

-- Verify schedule
SELECT * FROM cron.job WHERE jobname = 'cleanup-idempotency';
```

## Integration with jive-core

### Repository Usage

The migrations support the PostgreSQL idempotency repository:

**File**: `jive-core/src/infrastructure/repositories/idempotency_repository_pg.rs`

**Get Operation**:

```rust
async fn get(&self, request_id: &RequestId) -> Result<Option<IdempotencyRecord>> {
    sqlx::query_as!(
        IdempotencyRecordRow,
        r#"
        SELECT request_id, operation, result_payload, status_code, created_at, expires_at
        FROM idempotency_records
        WHERE request_id = $1 AND expires_at > NOW()
        "#,
        request_id.as_uuid()
    )
    .fetch_optional(&self.pool)
    .await?;
    // ...
}
```

**Save Operation**:

```rust
async fn save(...) -> Result<()> {
    sqlx::query!(
        r#"
        INSERT INTO idempotency_records (request_id, operation, result_payload, status_code, expires_at)
        VALUES ($1, $2, $3, $4, NOW() + INTERVAL '1 hour' * $5)
        ON CONFLICT (request_id) DO UPDATE SET
            operation = EXCLUDED.operation,
            result_payload = EXCLUDED.result_payload,
            status_code = EXCLUDED.status_code,
            expires_at = EXCLUDED.expires_at
        "#,
        // ...
    )
    .execute(&self.pool)
    .await?;
    // ...
}
```

**Cleanup Operation**:

```rust
async fn cleanup_expired(&self) -> Result<usize> {
    let result = sqlx::query!(
        r#"
        DELETE FROM idempotency_records
        WHERE expires_at <= NOW()
        "#
    )
    .execute(&self.pool)
    .await?;

    Ok(result.rows_affected() as usize)
}
```

## Performance Considerations

### Index Strategy

**Primary Key Index** (request_id):
- **Purpose**: Fast duplicate detection
- **Performance**: O(1) lookup via hash index
- **Cost**: Minimal (automatic with PRIMARY KEY)

**Expires Index** (idx_idempotency_expires):
- **Purpose**: Fast cleanup queries
- **Performance**: O(log n) for range scans
- **Query Pattern**: `WHERE expires_at <= NOW()`
- **Cost**: ~50% of table size

**Operation Index** (idx_idempotency_operation):
- **Purpose**: Analytics and monitoring
- **Performance**: O(log n) for grouping
- **Query Pattern**: `GROUP BY operation`
- **Cost**: ~25% of table size
- **Optional**: Can be dropped if not used

### Query Optimization

**Duplicate Detection** (hot path):

```sql
EXPLAIN ANALYZE
SELECT result_payload, status_code
FROM idempotency_records
WHERE request_id = '...'
  AND expires_at > NOW();
```

Expected plan:
```
Index Scan using idempotency_records_pkey  (cost=0.00..8.27 rows=1)
  Index Cond: (request_id = '...')
  Filter: (expires_at > now())
```

**Cleanup Query**:

```sql
EXPLAIN ANALYZE
DELETE FROM idempotency_records
WHERE expires_at <= NOW();
```

Expected plan:
```
Delete on idempotency_records  (cost=0.00..23.50 rows=150)
  ->  Index Scan using idx_idempotency_expires
      Index Cond: (expires_at <= now())
```

### Maintenance

**Vacuum Strategy**:

```sql
-- Analyze after bulk operations
ANALYZE idempotency_records;

-- Autovacuum settings (in postgresql.conf)
autovacuum = on
autovacuum_vacuum_scale_factor = 0.1  -- Vacuum at 10% dead tuples
autovacuum_analyze_scale_factor = 0.05  -- Analyze at 5% changes
```

**Monitoring**:

```sql
-- Table bloat
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_live_tup AS live_rows,
    n_dead_tup AS dead_rows,
    ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_ratio
FROM pg_stat_user_tables
WHERE tablename = 'idempotency_records';

-- Index usage
SELECT
    indexrelname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE relname = 'idempotency_records';
```

## Security Best Practices

### Access Control

**Principle of Least Privilege**:

```sql
-- Grant only necessary permissions
GRANT SELECT, INSERT, DELETE ON idempotency_records TO jive_api_user;

-- DO NOT grant UPDATE (records are immutable)
-- DO NOT grant ALL PRIVILEGES
```

### Data Retention

**Compliance Considerations**:

- **Default TTL**: 24 hours (balance between cache hit rate and storage)
- **GDPR**: Consider shorter TTL for sensitive operations
- **Audit Requirements**: May need longer TTL for financial transactions

**Adjust TTL by Operation**:

```rust
let ttl = match operation {
    "payment" | "transfer" => 72,  // 3 days for financial ops
    "login" | "auth" => 1,          // 1 hour for auth
    _ => 24,                        // 24 hours default
};

repo.save(&request_id, operation, result, status, Some(ttl)).await?;
```

### Monitoring

**Set Up Alerts**:

```sql
-- Alert if table grows too large (> 1GB)
SELECT pg_size_pretty(pg_total_relation_size('idempotency_records'));

-- Alert if too many expired records (cleanup not running)
SELECT COUNT(*) FROM idempotency_records WHERE expires_at <= NOW();

-- Alert if insert rate is too high (potential attack)
SELECT
    COUNT(*) AS inserts_per_minute
FROM idempotency_records
WHERE created_at > NOW() - INTERVAL '1 minute';
```

## Troubleshooting

### Issue: Migration Fails with "relation already exists"

**Cause**: Migration 045 already applied.

**Solution**:

```sql
-- Check if table exists
SELECT * FROM pg_tables WHERE tablename = 'idempotency_records';

-- If exists, skip migration (already applied)
-- Or drop and recreate (WARNING: loses data)
```

### Issue: Cleanup Function Not Found

**Cause**: Migration 046 not run or rolled back.

**Solution**:

```bash
# Run migration 046
psql -h localhost -U postgres -d jive_money \
     -f migrations/046_create_idempotency_cleanup_job.sql

# Verify
psql -h localhost -U postgres -d jive_money \
     -c "SELECT proname FROM pg_proc WHERE proname = 'cleanup_expired_idempotency_records';"
```

### Issue: Slow Queries

**Cause**: Missing indexes or table bloat.

**Diagnosis**:

```sql
-- Check indexes
SELECT * FROM pg_indexes WHERE tablename = 'idempotency_records';

-- Check bloat
SELECT n_live_tup, n_dead_tup FROM pg_stat_user_tables
WHERE tablename = 'idempotency_records';
```

**Solution**:

```sql
-- Recreate indexes if missing
CREATE INDEX IF NOT EXISTS idx_idempotency_expires ON idempotency_records(expires_at);

-- Vacuum if bloated
VACUUM ANALYZE idempotency_records;

-- Reindex if needed (rarely necessary)
REINDEX TABLE idempotency_records;
```

### Issue: Permission Denied

**Cause**: jive_api_user doesn't have permissions.

**Solution**:

```sql
-- Grant permissions
GRANT SELECT, INSERT, DELETE ON idempotency_records TO jive_api_user;
GRANT EXECUTE ON FUNCTION cleanup_expired_idempotency_records() TO jive_api_user;

-- Verify
SELECT grantee, privilege_type
FROM information_schema.table_privileges
WHERE table_name = 'idempotency_records';
```

## Related Files

### In jive-api

- `migrations/045_create_idempotency_records.sql` - Main migration
- `migrations/045_create_idempotency_records.down.sql` - Rollback
- `migrations/046_create_idempotency_cleanup_job.sql` - Cleanup function
- `migrations/046_create_idempotency_cleanup_job.down.sql` - Cleanup rollback
- `migrations/README_IDEMPOTENCY.md` - Comprehensive guide
- `migrations/test_idempotency_migrations.sql` - Test script

### In jive-core

- `src/infrastructure/repositories/idempotency_repository.rs` - Trait
- `src/infrastructure/repositories/idempotency_repository_pg.rs` - PostgreSQL impl
- `src/infrastructure/repositories/idempotency_repository_redis.rs` - Redis impl
- `INFRASTRUCTURE_SUPPLEMENTS_REPORT.md` - Full documentation

## Conclusion

The database migrations successfully provide:

✅ **Persistent Storage**: PostgreSQL table for idempotency records
✅ **Performance**: Optimized indexes for fast lookups and cleanup
✅ **Data Integrity**: Check constraints prevent invalid data
✅ **Maintenance**: Optional cleanup function for expired records
✅ **Documentation**: Comprehensive guides and test scripts
✅ **Rollback Support**: Safe migration reversal

**Impact on f64 Bug Fix**:

These migrations enable the idempotency framework, which is critical for:

1. **Preventing Duplicate Transactions**: No accidental double-charges
2. **API Reliability**: Safe retry logic for clients
3. **Audit Trail**: Request tracking for debugging

Combined with the Money/Decimal types in jive-core, this ensures financial precision and reliability.

**Next Steps**:

1. ✅ Task 5 Complete
2. ⏳ Task 6: Generate comprehensive documentation and usage examples

---

**Generated by**: Claude Code
**Files Created**: 6 files (2 migrations + 2 rollbacks + 1 README + 1 test script)
**Total SQL**: ~400 lines
**Test Coverage**: 10 automated tests
**Review Status**: Ready for code review and database deployment
