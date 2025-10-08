-- 038: Add travel mode MVP tables
-- Description: Create core tables for travel planning and tracking
-- Author: Claude
-- Date: 2025-01-29

-- 1. Travel events table (core planning entity)
CREATE TABLE IF NOT EXISTS travel_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    family_id UUID NOT NULL REFERENCES families(id) ON DELETE CASCADE,

    -- Basic information
    trip_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) DEFAULT 'planning' CHECK (status IN ('planning', 'active', 'completed', 'cancelled')),

    -- Date range
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,

    -- Budget settings
    total_budget DECIMAL(15,2),
    budget_currency_id UUID REFERENCES currencies(id),
    home_currency_id UUID NOT NULL REFERENCES currencies(id),

    -- Tag group (nullable for phase 1, will be required in phase 2)
    tag_group_id UUID REFERENCES tag_groups(id),

    -- Settings and metadata
    settings JSONB DEFAULT '{
        "auto_tags": false,
        "offline_mode": false,
        "exchange_rate_mode": "real_time",
        "reminder_settings": {
            "daily_summary": false,
            "budget_alerts": true,
            "alert_threshold": 0.8
        }
    }',

    -- Statistics cache (updated via triggers or service)
    total_spent DECIMAL(15,2) DEFAULT 0,
    transaction_count INTEGER DEFAULT 0,
    last_transaction_at TIMESTAMPTZ,

    -- Audit fields
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    -- Constraints
    CONSTRAINT check_dates CHECK (end_date >= start_date)
);

-- 2. Travel transactions association table
CREATE TABLE IF NOT EXISTS travel_transactions (
    travel_event_id UUID NOT NULL REFERENCES travel_events(id) ON DELETE CASCADE,
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,

    -- Optional metadata
    attached_at TIMESTAMPTZ DEFAULT NOW(),
    attached_by UUID REFERENCES users(id),
    notes TEXT,

    PRIMARY KEY (travel_event_id, transaction_id)
);

-- 3. Travel budgets table (category-level budgets)
CREATE TABLE IF NOT EXISTS travel_budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    travel_event_id UUID NOT NULL REFERENCES travel_events(id) ON DELETE CASCADE,
    category_id UUID NOT NULL REFERENCES categories(id),

    -- Budget amount (inherits currency from travel_event)
    budget_amount DECIMAL(15,2) NOT NULL,
    budget_currency_id UUID REFERENCES currencies(id),

    -- Spent tracking (updated via trigger or service)
    spent_amount DECIMAL(15,2) DEFAULT 0,
    spent_amount_home_currency DECIMAL(15,2) DEFAULT 0,

    -- Alert settings
    alert_threshold DECIMAL(5,2) DEFAULT 0.8, -- Alert at 80% by default
    alert_sent BOOLEAN DEFAULT false,
    alert_sent_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),

    CONSTRAINT unique_travel_category_budget UNIQUE (travel_event_id, category_id),
    CONSTRAINT check_threshold CHECK (alert_threshold >= 0 AND alert_threshold <= 1)
);

-- Create indexes for better performance
CREATE INDEX idx_travel_events_family ON travel_events(family_id);
CREATE INDEX idx_travel_events_status ON travel_events(status);
CREATE INDEX idx_travel_events_dates ON travel_events(start_date, end_date);
CREATE INDEX idx_travel_events_active ON travel_events(family_id, status) WHERE status = 'active';

-- Indexes for travel_transactions
CREATE INDEX idx_travel_transactions_event ON travel_transactions(travel_event_id);
CREATE INDEX idx_travel_transactions_transaction ON travel_transactions(transaction_id);

-- Indexes for travel_budgets
CREATE INDEX idx_travel_budgets_event ON travel_budgets(travel_event_id);
CREATE INDEX idx_travel_budgets_category ON travel_budgets(category_id);

-- Create update trigger for updated_at
CREATE TRIGGER update_travel_events_updated_at
    BEFORE UPDATE ON travel_events
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_travel_budgets_updated_at
    BEFORE UPDATE ON travel_budgets
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to get active travel for a family (only one active at a time)
CREATE OR REPLACE FUNCTION get_active_travel_event(p_family_id UUID)
RETURNS TABLE (
    id UUID,
    trip_name VARCHAR(100),
    start_date DATE,
    end_date DATE,
    total_budget DECIMAL(15,2),
    total_spent DECIMAL(15,2)
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        te.id,
        te.trip_name,
        te.start_date,
        te.end_date,
        te.total_budget,
        te.total_spent
    FROM travel_events te
    WHERE te.family_id = p_family_id
      AND te.status = 'active'
    ORDER BY te.created_at DESC
    LIMIT 1;
END;
$$ LANGUAGE plpgsql;

-- Function to update travel event statistics
CREATE OR REPLACE FUNCTION update_travel_event_stats(p_travel_event_id UUID)
RETURNS VOID AS $$
DECLARE
    v_total_spent DECIMAL(15,2);
    v_transaction_count INTEGER;
    v_last_transaction_at TIMESTAMPTZ;
BEGIN
    -- Calculate statistics from associated transactions
    SELECT
        COALESCE(SUM(t.amount), 0),
        COUNT(*),
        MAX(t.created_at)
    INTO
        v_total_spent,
        v_transaction_count,
        v_last_transaction_at
    FROM travel_transactions tt
    JOIN transactions t ON tt.transaction_id = t.id
    WHERE tt.travel_event_id = p_travel_event_id
      AND t.deleted_at IS NULL;

    -- Update the travel event
    UPDATE travel_events
    SET
        total_spent = v_total_spent,
        transaction_count = v_transaction_count,
        last_transaction_at = v_last_transaction_at,
        updated_at = NOW()
    WHERE id = p_travel_event_id;

    -- Update budget spent amounts
    UPDATE travel_budgets tb
    SET
        spent_amount = (
            SELECT COALESCE(SUM(t.amount), 0)
            FROM travel_transactions tt
            JOIN transactions t ON tt.transaction_id = t.id
            WHERE tt.travel_event_id = tb.travel_event_id
              AND t.category_id = tb.category_id
              AND t.deleted_at IS NULL
        ),
        updated_at = NOW()
    WHERE tb.travel_event_id = p_travel_event_id;
END;
$$ LANGUAGE plpgsql;

-- Trigger to update stats when transactions are attached/detached
CREATE OR REPLACE FUNCTION trigger_update_travel_stats()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' OR TG_OP = 'DELETE' THEN
        PERFORM update_travel_event_stats(
            CASE
                WHEN TG_OP = 'INSERT' THEN NEW.travel_event_id
                ELSE OLD.travel_event_id
            END
        );
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_travel_stats_on_attach
    AFTER INSERT OR DELETE ON travel_transactions
    FOR EACH ROW EXECUTE FUNCTION trigger_update_travel_stats();

-- Add comments for documentation
COMMENT ON TABLE travel_events IS 'Core table for travel planning and tracking';
COMMENT ON TABLE travel_transactions IS 'Associates transactions with travel events';
COMMENT ON TABLE travel_budgets IS 'Category-level budgets for travel events';
COMMENT ON COLUMN travel_events.status IS 'Travel status: planning, active, completed, or cancelled';
COMMENT ON COLUMN travel_events.settings IS 'JSON settings for travel mode behavior';
COMMENT ON COLUMN travel_budgets.alert_threshold IS 'Percentage threshold for budget alerts (0.8 = 80%)';

-- Grant permissions (adjust based on your user setup)
GRANT ALL ON travel_events TO jive_user;
GRANT ALL ON travel_transactions TO jive_user;
GRANT ALL ON travel_budgets TO jive_user;
GRANT EXECUTE ON FUNCTION get_active_travel_event TO jive_user;
GRANT EXECUTE ON FUNCTION update_travel_event_stats TO jive_user;