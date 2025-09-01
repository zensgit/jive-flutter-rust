-- 创建账户表
CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID NOT NULL,
    name VARCHAR(255) NOT NULL,
    account_type VARCHAR(50) NOT NULL, -- checking, savings, credit_card, investment, loan
    account_number VARCHAR(100),
    institution_name VARCHAR(255),
    currency VARCHAR(10) NOT NULL DEFAULT 'CNY',
    current_balance DECIMAL(19,4) NOT NULL DEFAULT 0,
    available_balance DECIMAL(19,4),
    credit_limit DECIMAL(19,4),
    status VARCHAR(50) NOT NULL DEFAULT 'active', -- active, inactive, closed, error
    is_manual BOOLEAN NOT NULL DEFAULT true,
    color VARCHAR(7), -- HEX color code
    icon VARCHAR(50), -- icon identifier
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- 创建索引
CREATE INDEX idx_accounts_ledger_id ON accounts(ledger_id);
CREATE INDEX idx_accounts_account_type ON accounts(account_type);
CREATE INDEX idx_accounts_status ON accounts(status);
CREATE INDEX idx_accounts_deleted_at ON accounts(deleted_at);

-- 创建账户余额历史表
CREATE TABLE IF NOT EXISTS account_balances (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    balance DECIMAL(19,4) NOT NULL,
    balance_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_account_balances_account_id ON account_balances(account_id);
CREATE INDEX idx_account_balances_date ON account_balances(balance_date);

-- 添加更新时间触发器
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE
    ON accounts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();