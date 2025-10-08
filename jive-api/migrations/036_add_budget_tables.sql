-- 036: Add budget management tables
-- Description: Create tables for budget management functionality
-- Author: Claude
-- Date: 2025-09-29

-- Budget table: Store budget definitions
CREATE TABLE IF NOT EXISTS budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Budget period
    period_type VARCHAR(20) NOT NULL CHECK (period_type IN ('monthly', 'quarterly', 'yearly', 'custom')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    -- Budget amount
    total_amount DECIMAL(15, 2) NOT NULL CHECK (total_amount >= 0),
    currency_id UUID REFERENCES currencies(id),

    -- Budget status
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('draft', 'active', 'paused', 'completed', 'archived')),

    -- Alert settings
    alert_enabled BOOLEAN DEFAULT true,
    alert_threshold_percent INTEGER DEFAULT 80 CHECK (alert_threshold_percent BETWEEN 0 AND 100),

    -- Metadata
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_budget_name_per_family_period UNIQUE (family_id, name, start_date, end_date)
);

-- Budget categories: Budget allocation per category
CREATE TABLE IF NOT EXISTS budget_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),

    -- Budget amount for this category
    allocated_amount DECIMAL(15, 2) NOT NULL CHECK (allocated_amount >= 0),

    -- Optional: Alert threshold for this specific category
    alert_threshold_percent INTEGER CHECK (alert_threshold_percent BETWEEN 0 AND 100),

    -- Tracking
    notes TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_category_per_budget UNIQUE (budget_id, category_id)
);

-- Budget tracking: Track actual spending against budget
CREATE TABLE IF NOT EXISTS budget_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id),

    -- Tracking period (for custom reporting)
    tracking_date DATE NOT NULL,

    -- Actual spending
    spent_amount DECIMAL(15, 2) DEFAULT 0 CHECK (spent_amount >= 0),
    transaction_count INTEGER DEFAULT 0,

    -- Calculated fields (can be updated via triggers)
    remaining_amount DECIMAL(15, 2),
    usage_percent DECIMAL(5, 2),

    -- Last update
    last_transaction_id UUID REFERENCES transactions(id),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_tracking_per_day UNIQUE (budget_id, category_id, tracking_date)
);

-- Budget alerts: Log of budget alerts sent
CREATE TABLE IF NOT EXISTS budget_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    budget_id UUID NOT NULL REFERENCES budgets(id) ON DELETE CASCADE,
    budget_category_id UUID REFERENCES budget_categories(id) ON DELETE CASCADE,

    -- Alert details
    alert_type VARCHAR(50) NOT NULL CHECK (alert_type IN ('threshold_reached', 'budget_exceeded', 'period_ending', 'custom')),
    alert_level VARCHAR(20) NOT NULL CHECK (alert_level IN ('info', 'warning', 'critical')),

    -- Alert content
    title VARCHAR(200) NOT NULL,
    message TEXT NOT NULL,

    -- Alert status
    is_read BOOLEAN DEFAULT false,
    read_by UUID REFERENCES users(id),
    read_at TIMESTAMPTZ,

    -- Notification details
    notification_sent BOOLEAN DEFAULT false,
    notification_channels JSONB, -- e.g., {"email": true, "push": true, "in_app": true}

    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Budget templates: Predefined budget templates
CREATE TABLE IF NOT EXISTS budget_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID REFERENCES families(id) ON DELETE CASCADE, -- NULL for system templates
    name VARCHAR(100) NOT NULL,
    description TEXT,

    -- Template configuration
    period_type VARCHAR(20) NOT NULL CHECK (period_type IN ('monthly', 'quarterly', 'yearly')),
    template_data JSONB NOT NULL, -- Store category allocations and settings

    -- Template metadata
    is_public BOOLEAN DEFAULT false,
    usage_count INTEGER DEFAULT 0,

    created_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX idx_budgets_family_id ON budgets(family_id);
CREATE INDEX idx_budgets_status ON budgets(status);
CREATE INDEX idx_budgets_period ON budgets(start_date, end_date);
CREATE INDEX idx_budget_categories_budget_id ON budget_categories(budget_id);
CREATE INDEX idx_budget_tracking_budget_id ON budget_tracking(budget_id);
CREATE INDEX idx_budget_tracking_date ON budget_tracking(tracking_date);
CREATE INDEX idx_budget_alerts_budget_id ON budget_alerts(budget_id);
CREATE INDEX idx_budget_alerts_unread ON budget_alerts(is_read) WHERE is_read = false;

-- Create updated_at trigger function if not exists
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER update_budgets_updated_at BEFORE UPDATE ON budgets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_budget_categories_updated_at BEFORE UPDATE ON budget_categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_budget_tracking_updated_at BEFORE UPDATE ON budget_tracking
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_budget_templates_updated_at BEFORE UPDATE ON budget_templates
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update budget tracking when a transaction is added/modified
CREATE OR REPLACE FUNCTION update_budget_tracking_on_transaction()
RETURNS TRIGGER AS $$
DECLARE
    v_budget_id UUID;
    v_category_id UUID;
    v_amount DECIMAL(15, 2);
    v_allocated_amount DECIMAL(15, 2);
BEGIN
    -- Get category and amount from transaction
    v_category_id := COALESCE(NEW.category_id, OLD.category_id);
    v_amount := COALESCE(NEW.amount, OLD.amount, 0);

    -- Find active budget for this transaction's family and date
    SELECT b.id INTO v_budget_id
    FROM budgets b
    INNER JOIN accounts a ON a.family_id = b.family_id
    WHERE a.id = COALESCE(NEW.account_id, OLD.account_id)
        AND b.status = 'active'
        AND COALESCE(NEW.transaction_date, OLD.transaction_date) BETWEEN b.start_date AND b.end_date
    LIMIT 1;

    IF v_budget_id IS NOT NULL THEN
        -- Get allocated amount for this category
        SELECT allocated_amount INTO v_allocated_amount
        FROM budget_categories
        WHERE budget_id = v_budget_id AND category_id = v_category_id;

        -- Update or insert tracking record
        INSERT INTO budget_tracking (
            budget_id, category_id, tracking_date,
            spent_amount, transaction_count, last_transaction_id
        )
        VALUES (
            v_budget_id, v_category_id, COALESCE(NEW.transaction_date, OLD.transaction_date),
            v_amount, 1, NEW.id
        )
        ON CONFLICT (budget_id, category_id, tracking_date)
        DO UPDATE SET
            spent_amount = budget_tracking.spent_amount +
                CASE
                    WHEN TG_OP = 'INSERT' THEN v_amount
                    WHEN TG_OP = 'UPDATE' THEN v_amount - OLD.amount
                    WHEN TG_OP = 'DELETE' THEN -v_amount
                END,
            transaction_count = budget_tracking.transaction_count +
                CASE
                    WHEN TG_OP = 'INSERT' THEN 1
                    WHEN TG_OP = 'DELETE' THEN -1
                    ELSE 0
                END,
            last_transaction_id = CASE WHEN TG_OP != 'DELETE' THEN NEW.id ELSE budget_tracking.last_transaction_id END,
            remaining_amount = v_allocated_amount - budget_tracking.spent_amount,
            usage_percent = (budget_tracking.spent_amount / NULLIF(v_allocated_amount, 0)) * 100;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for transaction changes
CREATE TRIGGER update_budget_on_transaction_change
    AFTER INSERT OR UPDATE OR DELETE ON transactions
    FOR EACH ROW
    WHEN (NEW.type = 'expense' OR OLD.type = 'expense')
    EXECUTE FUNCTION update_budget_tracking_on_transaction();

-- Add comments for documentation
COMMENT ON TABLE budgets IS 'Store budget definitions for families';
COMMENT ON TABLE budget_categories IS 'Budget allocation per category';
COMMENT ON TABLE budget_tracking IS 'Track actual spending against budget';
COMMENT ON TABLE budget_alerts IS 'Log of budget alerts sent to users';
COMMENT ON TABLE budget_templates IS 'Predefined budget templates for quick setup';

-- Grant permissions
GRANT ALL ON budgets TO jive_user;
GRANT ALL ON budget_categories TO jive_user;
GRANT ALL ON budget_tracking TO jive_user;
GRANT ALL ON budget_alerts TO jive_user;
GRANT ALL ON budget_templates TO jive_user;