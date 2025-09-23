-- 026_add_audit_indexes.sql
-- Optimize audit logs listing and cleanup by family/time

CREATE INDEX IF NOT EXISTS idx_family_audit_logs_family_created_at
ON family_audit_logs (family_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_family_audit_logs_action
ON family_audit_logs (action);

