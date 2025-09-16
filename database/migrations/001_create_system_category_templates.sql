-- Create system_category_templates table
CREATE TABLE IF NOT EXISTS system_category_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parent_id UUID REFERENCES system_category_templates(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    name_en VARCHAR(255),
    icon VARCHAR(255),
    color VARCHAR(20),
    type VARCHAR(50) NOT NULL CHECK (type IN ('expense', 'income', 'transfer')),
    level INTEGER NOT NULL DEFAULT 0,
    sort_order INTEGER DEFAULT 0,
    is_visible BOOLEAN DEFAULT true,
    is_system BOOLEAN DEFAULT true,
    is_popular BOOLEAN DEFAULT false,
    keywords TEXT[],
    usage_count BIGINT DEFAULT 0,
    app_version VARCHAR(20),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_system_category_templates_parent_id ON system_category_templates(parent_id);
CREATE INDEX idx_system_category_templates_type ON system_category_templates(type);
CREATE INDEX idx_system_category_templates_level ON system_category_templates(level);
CREATE INDEX idx_system_category_templates_usage_count ON system_category_templates(usage_count DESC);
CREATE INDEX idx_system_category_templates_is_visible ON system_category_templates(is_visible);
CREATE INDEX idx_system_category_templates_is_popular ON system_category_templates(is_popular);

-- Create trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

CREATE TRIGGER update_system_category_templates_updated_at
    BEFORE UPDATE ON system_category_templates
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();