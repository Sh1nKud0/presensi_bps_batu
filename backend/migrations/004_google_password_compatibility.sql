-- Keep Google-only accounts locked out of password authentication on older APIs.
-- Older login handlers fall back to a dummy timing hash for NULL hashes.
-- This marker is non-null and cannot match any password in verifyPassword.
UPDATE presensi.users SET password_hash = '!google-only' WHERE password_hash IS NULL;
ALTER TABLE presensi.users ALTER COLUMN password_hash SET NOT NULL;
