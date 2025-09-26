-- 025_fix_password_hash_column.sql
-- Fix password_hash column length issue (moved from 011_ to avoid version conflict)
-- bcrypt/argon2 hashes require generous length; align to VARCHAR(255)

ALTER TABLE users 
ALTER COLUMN password_hash TYPE VARCHAR(255);

