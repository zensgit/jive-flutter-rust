-- Fix password_hash column length issue
-- bcrypt hashes require at least 60 characters

ALTER TABLE users 
ALTER COLUMN password_hash TYPE VARCHAR(255);