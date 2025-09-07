-- Add avatar fields to users table
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS avatar_url VARCHAR(500),
ADD COLUMN IF NOT EXISTS avatar_style VARCHAR(20) DEFAULT 'initials',
ADD COLUMN IF NOT EXISTS avatar_color VARCHAR(20) DEFAULT '#4ECDC4',
ADD COLUMN IF NOT EXISTS avatar_background VARCHAR(20) DEFAULT '#E3FFF8';

-- Add index for avatar_style for potential filtering
CREATE INDEX IF NOT EXISTS idx_users_avatar_style ON users(avatar_style);

COMMENT ON COLUMN users.avatar_url IS 'User avatar URL (auto-generated or custom uploaded)';
COMMENT ON COLUMN users.avatar_style IS 'Avatar style type (initials, animal, abstract, gradient, pattern)';
COMMENT ON COLUMN users.avatar_color IS 'Avatar primary color';
COMMENT ON COLUMN users.avatar_background IS 'Avatar background color';

-- Update existing users with default avatars based on their names
UPDATE users 
SET avatar_url = CASE 
    WHEN name IS NOT NULL AND name != '' THEN
        'https://ui-avatars.com/api/?name=' || REPLACE(name, ' ', '+') || '&background=E3FFF8&color=4ECDC4&size=256'
    ELSE
        'https://ui-avatars.com/api/?name=U&background=E3FFF8&color=4ECDC4&size=256'
    END
WHERE avatar_url IS NULL;