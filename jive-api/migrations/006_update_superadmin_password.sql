-- 更新superadmin密码为Argon2格式
-- 密码: admin123
UPDATE users 
SET password_hash = '$argon2id$v=19$m=19456,t=2,p=1$OkQ7dHUcv3u+5P4qsqqtOg$aowl63jBc1bawd1RNsORvSbbS+IqnHbjgpuFAoq8ehA'
WHERE email = 'superadmin@jive.com';