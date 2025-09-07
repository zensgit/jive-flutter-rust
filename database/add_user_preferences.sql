-- Add user preference columns to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS country VARCHAR(10) DEFAULT 'CN',
ADD COLUMN IF NOT EXISTS preferred_currency VARCHAR(10) DEFAULT 'CNY',
ADD COLUMN IF NOT EXISTS preferred_language VARCHAR(10) DEFAULT 'zh-CN',
ADD COLUMN IF NOT EXISTS preferred_timezone VARCHAR(50) DEFAULT 'Asia/Shanghai',
ADD COLUMN IF NOT EXISTS preferred_date_format VARCHAR(20) DEFAULT 'YYYY-MM-DD';

-- Add indexes for common queries
CREATE INDEX IF NOT EXISTS idx_users_country ON users(country);
CREATE INDEX IF NOT EXISTS idx_users_language ON users(preferred_language);

COMMENT ON COLUMN users.country IS 'User country code (ISO 3166-1 alpha-2)';
COMMENT ON COLUMN users.preferred_currency IS 'User preferred currency code (ISO 4217)';
COMMENT ON COLUMN users.preferred_language IS 'User preferred language (IETF BCP 47)';
COMMENT ON COLUMN users.preferred_timezone IS 'User preferred timezone (IANA timezone)';
COMMENT ON COLUMN users.preferred_date_format IS 'User preferred date format';