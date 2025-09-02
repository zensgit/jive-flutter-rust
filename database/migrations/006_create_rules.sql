-- 创建规则表
CREATE TABLE IF NOT EXISTS rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    rule_type VARCHAR(50) NOT NULL, -- categorization, tagging, payee_assignment
    conditions JSONB NOT NULL,
    actions JSONB NOT NULL,
    priority INT DEFAULT 100,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 创建规则匹配记录表
CREATE TABLE IF NOT EXISTS rule_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL REFERENCES rules(id) ON DELETE CASCADE,
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(rule_id, transaction_id)
);

-- 创建索引
CREATE INDEX idx_rules_ledger_id ON rules(ledger_id);
CREATE INDEX idx_rules_rule_type ON rules(rule_type);
CREATE INDEX idx_rules_is_active ON rules(is_active);
CREATE INDEX idx_rules_priority ON rules(priority);
CREATE INDEX idx_rules_deleted_at ON rules(deleted_at);

CREATE INDEX idx_rule_matches_rule_id ON rule_matches(rule_id);
CREATE INDEX idx_rule_matches_transaction_id ON rule_matches(transaction_id);
CREATE INDEX idx_rule_matches_applied_at ON rule_matches(applied_at);