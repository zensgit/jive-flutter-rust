-- Create transactions table
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ledger_id UUID,
    account_id UUID REFERENCES accounts(id) ON DELETE CASCADE,
    transaction_date TIMESTAMP WITH TIME ZONE NOT NULL,
    amount DECIMAL(19,4) NOT NULL,
    transaction_type VARCHAR(50) NOT NULL CHECK (transaction_type IN ('expense', 'income', 'transfer', 'adjustment')),
    category_id UUID,
    category_name VARCHAR(255),
    subcategory_name VARCHAR(255),
    payee VARCHAR(255),
    notes TEXT,
    is_recurring BOOLEAN DEFAULT false,
    is_split BOOLEAN DEFAULT false,
    parent_transaction_id UUID REFERENCES transactions(id) ON DELETE CASCADE,
    tags TEXT[],
    attachments JSONB,
    location JSONB,
    status VARCHAR(50) DEFAULT 'cleared' CHECK (status IN ('pending', 'cleared', 'reconciled', 'void')),
    import_id VARCHAR(255),
    import_source VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes
CREATE INDEX idx_transactions_ledger_id ON transactions(ledger_id);
CREATE INDEX idx_transactions_account_id ON transactions(account_id);
CREATE INDEX idx_transactions_transaction_date ON transactions(transaction_date);
CREATE INDEX idx_transactions_transaction_type ON transactions(transaction_type);
CREATE INDEX idx_transactions_category_id ON transactions(category_id);
CREATE INDEX idx_transactions_parent_transaction_id ON transactions(parent_transaction_id);
CREATE INDEX idx_transactions_status ON transactions(status);
CREATE INDEX idx_transactions_deleted_at ON transactions(deleted_at);

-- Create trigger to update updated_at timestamp
CREATE TRIGGER update_transactions_updated_at
    BEFORE UPDATE ON transactions
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();
