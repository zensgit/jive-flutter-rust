-- Create superadmin user
INSERT INTO users (
    id,
    email,
    name,
    full_name,
    password_hash,
    is_active,
    email_verified,
    created_at,
    updated_at
) VALUES (
    gen_random_uuid(),
    'superadmin@jive.money',
    'Super Admin',
    'Super Admin',
    -- Password: Admin@123456 (using argon2 hash)
    '$argon2id$v=19$m=19456,t=2,p=1$VE0e3g7U1HjmqOWAPRp51A$aRFqZJJdE8Jlwvo0r+CXqIaIcHiLqxXHhKmTq5xVlC0',
    true,
    true,
    NOW(),
    NOW()
) ON CONFLICT (email) DO NOTHING;