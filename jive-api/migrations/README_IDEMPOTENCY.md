# Idempotency Migrations Guide

This guide explains the database migrations for idempotency support in jive-api.

## Overview

Two migrations are provided to support idempotency functionality:

1. **045_create_idempotency_records.sql** - Creates the idempotency_records table
2. **046_create_idempotency_cleanup_job.sql** - Creates cleanup stored procedure (optional)

## Migration 045: Idempotency Records Table

### Purpose

Creates the `idempotency_records` table to store API request results for duplicate detection.

### Schema

```sql
CREATE TABLE idempotency_records (
    request_id UUID PRIMARY KEY,           -- Unique request identifier
    operation VARCHAR(100) NOT NULL,       -- Operation name for debugging
    result_payload TEXT NOT NULL,          -- JSON serialized result
    status_code INTEGER,                   -- HTTP status code
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,       -- TTL expiry timestamp
    CONSTRAINT chk_expires_at CHECK (expires_at > created_at)
);
```

### Indexes

- **idx_idempotency_expires**: Speeds up cleanup queries (finding expired records)
- **idx_idempotency_operation**: Optional index for analytics/monitoring

### Usage

```sql
-- Insert idempotency record (24-hour TTL)
INSERT INTO idempotency_records (
    request_id,
    operation,
    result_payload,
    status_code,
    expires_at
) VALUES (
    '550e8400-e29b-41d4-a716-446655440000',
    'create_transaction',
    '{"transaction_id": "...", "amount": "100.50"}',
    201,
    NOW() + INTERVAL '24 hours'
);

-- Check if request already processed
SELECT result_payload, status_code
FROM idempotency_records
WHERE request_id = '550e8400-e29b-41d4-a716-446655440000'
  AND expires_at > NOW();
```

## Migration 046: Cleanup Job (Optional)

### Purpose

Creates a stored procedure `cleanup_expired_idempotency_records()` for periodic cleanup of expired records.

### Usage

**Manual Cleanup**:

```sql
-- Run cleanup and see how many records were deleted
SELECT * FROM cleanup_expired_idempotency_records();
-- Returns: deleted_count
--          100
```

**Scheduled Cleanup (with pg_cron)**:

If you have the `pg_cron` extension installed:

```sql
-- Schedule cleanup every hour
SELECT cron.schedule(
    'cleanup-idempotency',
    '0 * * * *',  -- Every hour at minute 0
    $$SELECT cleanup_expired_idempotency_records()$$
);

-- View scheduled jobs
SELECT * FROM cron.job WHERE jobname = 'cleanup-idempotency';

-- Unschedule
SELECT cron.unschedule('cleanup-idempotency');
```

**Application-Level Cleanup**:

Alternatively, run cleanup from your application:

```rust
// In jive-api background job
use jive_core::infrastructure::repositories::idempotency_repository::IdempotencyRepository;

tokio::spawn(async move {
    let mut interval = tokio::time::interval(Duration::from_secs(3600)); // 1 hour

    loop {
        interval.tick().await;

        match idempotency_repo.cleanup_expired().await {
            Ok(count) => tracing::info!("Cleaned up {} expired records", count),
            Err(e) => tracing::error!("Cleanup failed: {:?}", e),
        }
    }
});
```

## Running Migrations

### Using sqlx-cli

```bash
# Run forward migrations
sqlx migrate run --source migrations

# Rollback last migration
sqlx migrate revert --source migrations
```

### Using psql

```bash
# Run migration 045
psql -h localhost -U postgres -d jive_money -f migrations/045_create_idempotency_records.sql

# Run migration 046 (optional)
psql -h localhost -U postgres -d jive_money -f migrations/046_create_idempotency_cleanup_job.sql

# Rollback migration 046
psql -h localhost -U postgres -d jive_money -f migrations/046_create_idempotency_cleanup_job.down.sql

# Rollback migration 045
psql -h localhost -U postgres -d jive_money -f migrations/045_create_idempotency_records.down.sql
```

### Using Docker

```bash
# If database is running in Docker
docker exec -i jive-postgres psql -U postgres -d jive_money < migrations/045_create_idempotency_records.sql
```

## Verification

### Check Table Created

```sql
-- Check if table exists
SELECT tablename
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename = 'idempotency_records';

-- View table structure
\d idempotency_records

-- Check indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'idempotency_records';
```

### Check Function Created

```sql
-- Check if cleanup function exists
SELECT proname, prosrc
FROM pg_proc
WHERE proname = 'cleanup_expired_idempotency_records';

-- Test the function
SELECT * FROM cleanup_expired_idempotency_records();
```

### Test Insert and Query

```sql
-- Insert test record
INSERT INTO idempotency_records (
    request_id,
    operation,
    result_payload,
    status_code,
    expires_at
) VALUES (
    gen_random_uuid(),
    'test_operation',
    '{"test": "data"}',
    200,
    NOW() + INTERVAL '1 hour'
);

-- Query test record
SELECT * FROM idempotency_records LIMIT 1;

-- Cleanup test
DELETE FROM idempotency_records WHERE operation = 'test_operation';
```

## Performance Considerations

### Table Size Estimation

With 1 million API requests per month and 24-hour TTL:

- **Active records**: ~40,000 records (at any given time)
- **Storage per record**: ~200 bytes average
- **Total storage**: ~8 MB
- **Index overhead**: ~4 MB
- **Total**: ~12 MB

### Cleanup Strategy

**Option 1: Application-level cleanup (Recommended)**
- Run cleanup every 1 hour via background job
- Pros: Simple, no database extension needed
- Cons: Requires application to be running

**Option 2: Database-level cleanup (pg_cron)**
- Schedule cleanup via pg_cron extension
- Pros: Runs even if application is down
- Cons: Requires pg_cron extension installation

**Option 3: Partition-based cleanup**
- For very high throughput (>10M requests/month)
- Use table partitioning by date
- Drop old partitions instead of DELETE
- See: https://www.postgresql.org/docs/current/ddl-partitioning.html

### Index Maintenance

```sql
-- Analyze table statistics (run after bulk inserts/deletes)
ANALYZE idempotency_records;

-- Check index usage
SELECT
    schemaname,
    tablename,
    indexname,
    idx_scan,
    idx_tup_read,
    idx_tup_fetch
FROM pg_stat_user_indexes
WHERE tablename = 'idempotency_records';

-- Reindex if needed (rarely necessary)
REINDEX TABLE idempotency_records;
```

## Security Considerations

### Access Control

Grant minimal necessary permissions:

```sql
-- Grant only necessary permissions to API user
GRANT SELECT, INSERT, DELETE ON idempotency_records TO jive_api_user;

-- Do NOT grant UPDATE (records should be immutable)
-- Do NOT grant ALL PRIVILEGES (principle of least privilege)
```

### Data Retention Policy

Consider data privacy regulations (GDPR, etc.):

```sql
-- Ensure TTL is appropriate for your compliance requirements
-- Default: 24 hours (adjust as needed)

-- For sensitive operations, use shorter TTL
UPDATE idempotency_records
SET expires_at = created_at + INTERVAL '1 hour'
WHERE operation IN ('payment', 'transfer');
```

### Monitoring

Set up monitoring for:

```sql
-- Table size growth
SELECT
    pg_size_pretty(pg_total_relation_size('idempotency_records')) as total_size,
    pg_size_pretty(pg_relation_size('idempotency_records')) as table_size,
    pg_size_pretty(pg_indexes_size('idempotency_records')) as index_size;

-- Record count
SELECT COUNT(*) FROM idempotency_records;

-- Expired record count (should be cleaned up)
SELECT COUNT(*) FROM idempotency_records WHERE expires_at <= NOW();

-- Operations breakdown
SELECT operation, COUNT(*)
FROM idempotency_records
GROUP BY operation
ORDER BY COUNT(*) DESC;
```

## Troubleshooting

### Migration Fails: "relation already exists"

```sql
-- Check if table already exists
SELECT * FROM pg_tables WHERE tablename = 'idempotency_records';

-- If exists, either:
-- 1. Skip migration (already applied)
-- 2. Drop table and rerun (WARNING: loses data)
```

### Cleanup Function Not Found

```sql
-- Check if function exists
\df cleanup_expired_idempotency_records

-- Recreate if needed
\i migrations/046_create_idempotency_cleanup_job.sql
```

### Performance Issues

```sql
-- Check for missing indexes
SELECT * FROM pg_indexes WHERE tablename = 'idempotency_records';

-- Check for bloat
SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size,
    n_live_tup,
    n_dead_tup
FROM pg_stat_user_tables
WHERE tablename = 'idempotency_records';

-- Vacuum if needed
VACUUM ANALYZE idempotency_records;
```

## Related Documentation

- [Infrastructure Supplements Report](../../jive-core/INFRASTRUCTURE_SUPPLEMENTS_REPORT.md)
- [API Adapter Layer Report](../../jive-core/API_ADAPTER_LAYER_REPORT.md)
- [PostgreSQL Idempotency Repository](../../jive-core/src/infrastructure/repositories/idempotency_repository_pg.rs)

## Support

For issues or questions:
- Check existing migrations: `../jive-api/migrations/`
- Review repository implementation: `jive-core/src/infrastructure/repositories/`
- Consult documentation reports in `jive-core/`
