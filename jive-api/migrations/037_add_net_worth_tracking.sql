-- 037: Add net worth tracking tables
-- Description: Create tables for net worth tracking and valuations
-- Author: Claude (inspired by Maybe Finance)
-- Date: 2025-09-29

-- Account valuations table: Track account values over time
CREATE TABLE IF NOT EXISTS valuations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,
    amount DECIMAL(15, 2) NOT NULL,
    currency_id UUID REFERENCES currencies(id),
    valuation_date DATE NOT NULL,
    valuation_type VARCHAR(50) NOT NULL CHECK (valuation_type IN ('manual', 'market', 'automated', 'reconciliation')),

    -- Optional fields for investment accounts
    market_price DECIMAL(15, 6),
    quantity DECIMAL(15, 6),
    cost_basis DECIMAL(15, 2),

    -- Metadata
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_valuation_per_account_date UNIQUE (account_id, valuation_date, valuation_type)
);

-- Balance snapshots: Daily net worth tracking
CREATE TABLE IF NOT EXISTS balance_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    snapshot_date DATE NOT NULL,

    -- Asset breakdown
    total_assets DECIMAL(15, 2) NOT NULL DEFAULT 0,
    liquid_assets DECIMAL(15, 2) DEFAULT 0,
    investment_assets DECIMAL(15, 2) DEFAULT 0,
    property_assets DECIMAL(15, 2) DEFAULT 0,
    other_assets DECIMAL(15, 2) DEFAULT 0,

    -- Liability breakdown
    total_liabilities DECIMAL(15, 2) NOT NULL DEFAULT 0,
    short_term_liabilities DECIMAL(15, 2) DEFAULT 0,
    long_term_liabilities DECIMAL(15, 2) DEFAULT 0,
    credit_card_debt DECIMAL(15, 2) DEFAULT 0,
    mortgage_debt DECIMAL(15, 2) DEFAULT 0,
    other_debt DECIMAL(15, 2) DEFAULT 0,

    -- Net worth
    net_worth DECIMAL(15, 2) NOT NULL GENERATED ALWAYS AS (total_assets - total_liabilities) STORED,

    -- Currency
    currency_id UUID REFERENCES currencies(id),

    -- Change tracking
    assets_change_amount DECIMAL(15, 2),
    assets_change_percent DECIMAL(5, 2),
    liabilities_change_amount DECIMAL(15, 2),
    liabilities_change_percent DECIMAL(5, 2),
    net_worth_change_amount DECIMAL(15, 2),
    net_worth_change_percent DECIMAL(5, 2),

    -- Metadata
    is_automated BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_snapshot_per_family_date UNIQUE (family_id, snapshot_date)
);

-- Account snapshots: Detailed account balances for each snapshot
CREATE TABLE IF NOT EXISTS account_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    balance_snapshot_id UUID NOT NULL REFERENCES balance_snapshots(id) ON DELETE CASCADE,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE CASCADE,

    -- Balance information
    balance DECIMAL(15, 2) NOT NULL,
    currency_id UUID REFERENCES currencies(id),

    -- Converted to family currency
    balance_in_base_currency DECIMAL(15, 2),
    exchange_rate DECIMAL(15, 6),

    -- Account classification for aggregation
    account_type VARCHAR(50), -- 'cash', 'investment', 'property', 'loan', 'credit_card', etc.
    classification VARCHAR(20) CHECK (classification IN ('asset', 'liability')),

    created_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_account_per_snapshot UNIQUE (balance_snapshot_id, account_id)
);

-- Net worth goals: Track financial goals
CREATE TABLE IF NOT EXISTS net_worth_goals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,

    -- Goal details
    goal_name VARCHAR(100) NOT NULL,
    target_amount DECIMAL(15, 2) NOT NULL,
    target_date DATE,

    -- Progress tracking
    current_amount DECIMAL(15, 2) DEFAULT 0,
    progress_percent DECIMAL(5, 2) DEFAULT 0,

    -- Status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'achieved', 'paused', 'cancelled')),
    achieved_date DATE,

    -- Metadata
    notes TEXT,
    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_valuations_account_id ON valuations(account_id);
CREATE INDEX idx_valuations_date ON valuations(valuation_date);
CREATE INDEX idx_balance_snapshots_family_id ON balance_snapshots(family_id);
CREATE INDEX idx_balance_snapshots_date ON balance_snapshots(snapshot_date);
CREATE INDEX idx_account_snapshots_balance_snapshot_id ON account_snapshots(balance_snapshot_id);
CREATE INDEX idx_account_snapshots_account_id ON account_snapshots(account_id);
CREATE INDEX idx_net_worth_goals_family_id ON net_worth_goals(family_id);
CREATE INDEX idx_net_worth_goals_status ON net_worth_goals(status);

-- Apply updated_at triggers
CREATE TRIGGER update_valuations_updated_at BEFORE UPDATE ON valuations
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_balance_snapshots_updated_at BEFORE UPDATE ON balance_snapshots
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_net_worth_goals_updated_at BEFORE UPDATE ON net_worth_goals
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to calculate and store daily balance snapshot
CREATE OR REPLACE FUNCTION calculate_daily_balance_snapshot(p_family_id UUID, p_date DATE DEFAULT CURRENT_DATE)
RETURNS UUID AS $$
DECLARE
    v_snapshot_id UUID;
    v_total_assets DECIMAL(15, 2) := 0;
    v_total_liabilities DECIMAL(15, 2) := 0;
    v_liquid_assets DECIMAL(15, 2) := 0;
    v_investment_assets DECIMAL(15, 2) := 0;
    v_currency_id UUID;
BEGIN
    -- Get family's base currency
    SELECT currency_id INTO v_currency_id
    FROM families
    WHERE id = p_family_id;

    -- Calculate asset totals
    SELECT
        COALESCE(SUM(CASE WHEN a.account_type = 'asset' THEN a.balance ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN a.account_type = 'asset' AND a.account_subtype IN ('checking', 'savings', 'cash') THEN a.balance ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN a.account_type = 'asset' AND a.account_subtype IN ('investment', 'brokerage', '401k', 'ira') THEN a.balance ELSE 0 END), 0)
    INTO v_total_assets, v_liquid_assets, v_investment_assets
    FROM accounts a
    WHERE a.family_id = p_family_id
      AND a.is_active = true;

    -- Calculate liability totals
    SELECT
        COALESCE(SUM(CASE WHEN a.account_type = 'liability' THEN ABS(a.balance) ELSE 0 END), 0)
    INTO v_total_liabilities
    FROM accounts a
    WHERE a.family_id = p_family_id
      AND a.is_active = true;

    -- Insert or update snapshot
    INSERT INTO balance_snapshots (
        family_id, snapshot_date, total_assets, liquid_assets, investment_assets,
        total_liabilities, currency_id, is_automated
    ) VALUES (
        p_family_id, p_date, v_total_assets, v_liquid_assets, v_investment_assets,
        v_total_liabilities, v_currency_id, true
    )
    ON CONFLICT (family_id, snapshot_date)
    DO UPDATE SET
        total_assets = EXCLUDED.total_assets,
        liquid_assets = EXCLUDED.liquid_assets,
        investment_assets = EXCLUDED.investment_assets,
        total_liabilities = EXCLUDED.total_liabilities,
        updated_at = NOW()
    RETURNING id INTO v_snapshot_id;

    -- Store individual account snapshots
    INSERT INTO account_snapshots (balance_snapshot_id, account_id, balance, currency_id, account_type, classification)
    SELECT
        v_snapshot_id,
        a.id,
        a.balance,
        a.currency_id,
        a.account_subtype,
        CASE WHEN a.account_type = 'asset' THEN 'asset' ELSE 'liability' END
    FROM accounts a
    WHERE a.family_id = p_family_id
      AND a.is_active = true
    ON CONFLICT (balance_snapshot_id, account_id) DO NOTHING;

    -- Calculate changes from previous snapshot
    UPDATE balance_snapshots bs
    SET
        net_worth_change_amount = bs.net_worth - prev.net_worth,
        net_worth_change_percent = CASE
            WHEN prev.net_worth != 0 THEN ((bs.net_worth - prev.net_worth) / ABS(prev.net_worth)) * 100
            ELSE 0
        END,
        assets_change_amount = bs.total_assets - prev.total_assets,
        assets_change_percent = CASE
            WHEN prev.total_assets != 0 THEN ((bs.total_assets - prev.total_assets) / prev.total_assets) * 100
            ELSE 0
        END,
        liabilities_change_amount = bs.total_liabilities - prev.total_liabilities,
        liabilities_change_percent = CASE
            WHEN prev.total_liabilities != 0 THEN ((bs.total_liabilities - prev.total_liabilities) / prev.total_liabilities) * 100
            ELSE 0
        END
    FROM (
        SELECT * FROM balance_snapshots
        WHERE family_id = p_family_id
          AND snapshot_date < p_date
        ORDER BY snapshot_date DESC
        LIMIT 1
    ) prev
    WHERE bs.id = v_snapshot_id;

    RETURN v_snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- Add comments for documentation
COMMENT ON TABLE valuations IS 'Track account valuations over time for net worth calculations';
COMMENT ON TABLE balance_snapshots IS 'Daily snapshots of family net worth and asset/liability breakdown';
COMMENT ON TABLE account_snapshots IS 'Individual account balances for each balance snapshot';
COMMENT ON TABLE net_worth_goals IS 'Financial goals for net worth targets';
COMMENT ON FUNCTION calculate_daily_balance_snapshot IS 'Calculate and store daily balance snapshot for a family';

-- Grant permissions
GRANT ALL ON valuations TO jive_user;
GRANT ALL ON balance_snapshots TO jive_user;
GRANT ALL ON account_snapshots TO jive_user;
GRANT ALL ON net_worth_goals TO jive_user;