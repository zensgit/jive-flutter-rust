-- Create icons table
CREATE TABLE IF NOT EXISTS icons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    category VARCHAR(100),
    tags TEXT[],
    unicode VARCHAR(20),
    svg_path TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_icons_name ON icons(name);
CREATE INDEX idx_icons_category ON icons(category);

-- Create trigger to update updated_at timestamp
CREATE TRIGGER update_icons_updated_at
    BEFORE UPDATE ON icons
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at_column();