-- Existing password accounts are unchanged. NULL represents a Google-only account
-- until its owner sets a password after a fresh Google login.
ALTER TABLE presensi.users ALTER COLUMN password_hash DROP NOT NULL;

CREATE TABLE presensi.google_identities (
  subject text PRIMARY KEY CHECK (length(subject) BETWEEN 1 AND 255),
  user_id uuid NOT NULL UNIQUE REFERENCES presensi.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);

CREATE TABLE presensi.google_challenges (
  nonce_hash text PRIMARY KEY CHECK (length(nonce_hash) = 64),
  expires_at timestamptz NOT NULL
);
CREATE INDEX google_challenges_expiry ON presensi.google_challenges(expires_at);
