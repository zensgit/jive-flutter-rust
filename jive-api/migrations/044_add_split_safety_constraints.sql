-- Migration: Add safety constraints for transaction splitting
-- Created: 2025-10-14
-- Purpose: Prevent money creation vulnerability in split transactions

-- =====================================================
-- Part 1: Prevent Negative Amounts
-- =====================================================

-- Add check constraint to entries table
-- This ensures no entry can have a negative or zero amount
ALTER TABLE entries
ADD CONSTRAINT check_positive_amount
CHECK (amount::numeric > 0);

-- Create index to optimize amount queries
CREATE INDEX idx_entries_amount
ON entries(amount)
WHERE deleted_at IS NULL;

-- =====================================================
-- Part 2: Prevent Duplicate Splits
-- =====================================================

-- Add unique constraint to prevent same transaction being split multiple times
-- Uses partial index to ignore soft-deleted splits
CREATE UNIQUE INDEX idx_unique_original_transaction_split
ON transaction_splits(original_transaction_id)
WHERE deleted_at IS NULL;

-- =====================================================
-- Part 3: Optimize Concurrent Access
-- =====================================================

-- Create composite index for efficient locking queries
CREATE INDEX idx_entries_entryable_lookup
ON entries(entryable_id, entryable_type, deleted_at)
WHERE entryable_type = 'Transaction';

-- Create index for split lookup with locking
CREATE INDEX idx_transaction_splits_original_active
ON transaction_splits(original_transaction_id)
WHERE deleted_at IS NULL;

-- =====================================================
-- Part 4: Audit Logging Infrastructure
-- =====================================================

-- Create audit log table for split operations
CREATE TABLE IF NOT EXISTS transaction_split_audit (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID,
    original_transaction_id UUID NOT NULL,
    original_amount DECIMAL(19, 4) NOT NULL,
    split_total DECIMAL(19, 4) NOT NULL,
    split_count INTEGER NOT NULL,
    split_details JSONB NOT NULL,
    operation_type VARCHAR(50) NOT NULL CHECK (operation_type IN ('attempt', 'success', 'failure')),
    error_message TEXT,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for audit queries
CREATE INDEX idx_split_audit_user_time
ON transaction_split_audit(user_id, created_at DESC);

CREATE INDEX idx_split_audit_transaction
ON transaction_split_audit(original_transaction_id);

CREATE INDEX idx_split_audit_operation_time
ON transaction_split_audit(operation_type, created_at DESC);

-- =====================================================
-- Part 5: Audit Trigger Function
-- =====================================================

-- Function to automatically log split operations
CREATE OR REPLACE FUNCTION log_split_operation()
RETURNS TRIGGER AS $$
BEGIN
    -- Log successful split creation
    INSERT INTO transaction_split_audit (
        original_transaction_id,
        original_amount,
        split_total,
        split_count,
        split_details,
        operation_type
    )
    SELECT
        NEW.original_transaction_id,
        e.amount::numeric,
        (SELECT SUM(amount::numeric) FROM transaction_splits WHERE original_transaction_id = NEW.original_transaction_id),
        (SELECT COUNT(*) FROM transaction_splits WHERE original_transaction_id = NEW.original_transaction_id),
        jsonb_build_object(
            'split_id', NEW.id,
            'split_transaction_id', NEW.split_transaction_id,
            'amount', NEW.amount,
            'description', NEW.description
        ),
        'success'
    FROM entries e
    WHERE e.entryable_id = NEW.original_transaction_id
      AND e.entryable_type = 'Transaction';

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on transaction_splits table
DROP TRIGGER IF EXISTS audit_transaction_splits ON transaction_splits;
CREATE TRIGGER audit_transaction_splits
AFTER INSERT ON transaction_splits
FOR EACH ROW
EXECUTE FUNCTION log_split_operation();

-- =====================================================
-- Part 6: Validation Function (Optional Safety Layer)
-- =====================================================

-- Function to validate split request before execution
CREATE OR REPLACE FUNCTION validate_split_request(
    p_original_id UUID,
    p_splits JSONB
)
RETURNS TABLE(
    is_valid BOOLEAN,
    error_message TEXT,
    original_amount NUMERIC,
    requested_total NUMERIC
) AS $$
DECLARE
    v_original_amount NUMERIC;
    v_requested_total NUMERIC;
    v_existing_splits INTEGER;
BEGIN
    -- Get original transaction amount
    SELECT amount::numeric INTO v_original_amount
    FROM entries
    WHERE entryable_id = p_original_id
      AND entryable_type = 'Transaction'
      AND deleted_at IS NULL;

    IF v_original_amount IS NULL THEN
        RETURN QUERY SELECT FALSE, 'Transaction not found'::TEXT, 0::NUMERIC, 0::NUMERIC;
        RETURN;
    END IF;

    -- Check if already split
    SELECT COUNT(*) INTO v_existing_splits
    FROM transaction_splits
    WHERE original_transaction_id = p_original_id
      AND deleted_at IS NULL;

    IF v_existing_splits > 0 THEN
        RETURN QUERY SELECT FALSE, 'Transaction already split'::TEXT, v_original_amount, 0::NUMERIC;
        RETURN;
    END IF;

    -- Calculate requested total
    SELECT SUM((split->>'amount')::numeric) INTO v_requested_total
    FROM jsonb_array_elements(p_splits) AS split;

    -- Validate total doesn't exceed original
    IF v_requested_total > v_original_amount THEN
        RETURN QUERY SELECT
            FALSE,
            format('Split total %s exceeds original %s', v_requested_total, v_original_amount)::TEXT,
            v_original_amount,
            v_requested_total;
        RETURN;
    END IF;

    -- All validations passed
    RETURN QUERY SELECT TRUE, NULL::TEXT, v_original_amount, v_requested_total;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Part 7: Monitoring Views
-- =====================================================

-- View to detect suspicious split patterns
CREATE OR REPLACE VIEW suspicious_splits AS
SELECT
    tsa.original_transaction_id,
    tsa.original_amount,
    tsa.split_total,
    tsa.split_total - tsa.original_amount as excess_amount,
    tsa.split_count,
    tsa.created_at,
    tsa.user_id
FROM transaction_split_audit tsa
WHERE tsa.operation_type = 'success'
  AND tsa.split_total > tsa.original_amount;

-- View to track split attempt failures
CREATE OR REPLACE VIEW failed_split_attempts AS
SELECT
    user_id,
    COUNT(*) as failure_count,
    MAX(created_at) as last_failure,
    array_agg(DISTINCT error_message) as error_types
FROM transaction_split_audit
WHERE operation_type = 'failure'
  AND created_at > NOW() - INTERVAL '24 hours'
GROUP BY user_id
HAVING COUNT(*) > 5  -- Flag users with more than 5 failures in 24h
ORDER BY failure_count DESC;

-- =====================================================
-- Part 8: Data Integrity Check Function
-- =====================================================

-- Function to check for existing data integrity issues
CREATE OR REPLACE FUNCTION check_split_data_integrity()
RETURNS TABLE(
    check_name TEXT,
    issue_count BIGINT,
    details JSONB
) AS $$
BEGIN
    -- Check 1: Splits with sum exceeding original
    RETURN QUERY
    WITH split_sums AS (
        SELECT
            ts.original_transaction_id,
            e_orig.amount::numeric as original_amount,
            SUM(e_split.amount::numeric) as split_total
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
        'Splits exceeding original'::TEXT,
        COUNT(*),
        jsonb_agg(jsonb_build_object(
            'transaction_id', original_transaction_id,
            'original', original_amount,
            'split_total', split_total,
            'excess', split_total - original_amount
        ))
    FROM split_sums;

    -- Check 2: Negative amounts
    RETURN QUERY
    SELECT
        'Negative amounts'::TEXT,
        COUNT(*),
        jsonb_agg(jsonb_build_object(
            'entry_id', id,
            'transaction_id', entryable_id,
            'amount', amount
        ))
    FROM entries
    WHERE amount::numeric <= 0
      AND deleted_at IS NULL;

    -- Check 3: Duplicate splits
    RETURN QUERY
    WITH duplicate_splits AS (
        SELECT original_transaction_id, COUNT(*) as split_count
        FROM transaction_splits
        WHERE deleted_at IS NULL
        GROUP BY original_transaction_id
        HAVING COUNT(*) > 1
    )
    SELECT
        'Duplicate split records'::TEXT,
        COUNT(*),
        jsonb_agg(jsonb_build_object(
            'transaction_id', original_transaction_id,
            'split_count', split_count
        ))
    FROM duplicate_splits;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- Part 9: Comments for Documentation
-- =====================================================

COMMENT ON CONSTRAINT check_positive_amount ON entries IS
'Prevents money creation by ensuring all amounts are positive';

COMMENT ON INDEX idx_unique_original_transaction_split IS
'Prevents duplicate splits of the same transaction';

COMMENT ON TABLE transaction_split_audit IS
'Audit log for all transaction split operations - tracks attempts, successes, and failures';

COMMENT ON FUNCTION validate_split_request IS
'Pre-validation function to check split requests before database execution';

COMMENT ON VIEW suspicious_splits IS
'Monitoring view to detect splits where total exceeds original amount';

-- =====================================================
-- Part 10: Grant Permissions
-- =====================================================

-- Grant execute permission on validation function to application role
-- GRANT EXECUTE ON FUNCTION validate_split_request TO jive_api_role;
-- GRANT EXECUTE ON FUNCTION check_split_data_integrity TO jive_api_role;

-- Grant select on audit table to monitoring role
-- GRANT SELECT ON transaction_split_audit TO jive_monitoring_role;
-- GRANT SELECT ON suspicious_splits TO jive_monitoring_role;
-- GRANT SELECT ON failed_split_attempts TO jive_monitoring_role;

-- =====================================================
-- Migration Complete
-- =====================================================

-- Run integrity check after migration
SELECT * FROM check_split_data_integrity();
