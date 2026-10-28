CREATE TABLE presensi.files (
  id uuid PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES presensi.profiles(id) ON DELETE CASCADE,
  mime_type text NOT NULL CHECK (mime_type IN ('image/jpeg', 'image/png', 'image/webp')),
  size_bytes integer NOT NULL CHECK (size_bytes BETWEEN 1 AND 5242880),
  sha256 text NOT NULL CHECK (length(sha256) = 64),
  storage_key text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
CREATE INDEX files_user ON presensi.files(user_id);
ALTER TABLE presensi.izin ADD COLUMN bukti_id uuid REFERENCES presensi.files(id);
ALTER TABLE presensi.absen_susulan ADD COLUMN bukti_id uuid REFERENCES presensi.files(id);

CREATE TABLE presensi.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_id uuid NOT NULL REFERENCES presensi.profiles(id) ON DELETE CASCADE,
  pengaju_id uuid NOT NULL REFERENCES presensi.profiles(id) ON DELETE CASCADE,
  jenis text NOT NULL CHECK (jenis IN ('izin', 'susulan', 'pembatalan')),
  request_id uuid NOT NULL,
  status text NOT NULL CHECK (status IN ('menunggu', 'disetujui', 'ditolak')),
  created_at timestamptz NOT NULL,
  read_at timestamptz,
  UNIQUE(recipient_id, jenis, request_id, status)
);
CREATE INDEX notifications_recipient ON presensi.notifications(recipient_id, created_at DESC, id);
CREATE INDEX notifications_unread ON presensi.notifications(recipient_id) WHERE read_at IS NULL;

-- Notifikasi dan keputusan disimpan dalam transaksi yang sama dengan pengajuan.
CREATE FUNCTION presensi.notify_request() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog AS $$
DECLARE request_kind text;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.status_persetujuan IS NOT DISTINCT FROM OLD.status_persetujuan THEN RETURN NEW; END IF;
  request_kind := CASE TG_TABLE_NAME WHEN 'izin' THEN 'izin'
    WHEN 'absen_susulan' THEN 'susulan' ELSE 'pembatalan' END;
  IF NEW.status_persetujuan = 'menunggu' THEN
    INSERT INTO presensi.notifications(recipient_id, pengaju_id, jenis, request_id, status, created_at)
      SELECT p.id, NEW.user_id, request_kind, NEW.id, 'menunggu', NEW.created_at
      FROM presensi.profiles p JOIN presensi.users u ON u.id = p.id
      WHERE p.role = 'admin' AND u.active
      ON CONFLICT DO NOTHING;
  ELSE
    INSERT INTO presensi.notifications(recipient_id, pengaju_id, jenis, request_id, status, created_at)
      VALUES (NEW.user_id, NEW.user_id, request_kind, NEW.id, NEW.status_persetujuan,
        coalesce(NEW.diproses_at, clock_timestamp())) ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER notify_izin AFTER INSERT OR UPDATE OF status_persetujuan ON presensi.izin
  FOR EACH ROW EXECUTE FUNCTION presensi.notify_request();
CREATE TRIGGER notify_susulan AFTER INSERT OR UPDATE OF status_persetujuan ON presensi.absen_susulan
  FOR EACH ROW EXECUTE FUNCTION presensi.notify_request();
CREATE TRIGGER notify_pembatalan AFTER INSERT OR UPDATE OF status_persetujuan ON presensi.pembatalan_pulang
  FOR EACH ROW EXECUTE FUNCTION presensi.notify_request();

-- Pertahankan pengajuan yang sudah ada sebelum migrasi ini dijalankan.
WITH requests AS (
  SELECT id, user_id, 'izin' AS jenis, status_persetujuan AS status, created_at, diproses_at FROM presensi.izin
  UNION ALL SELECT id, user_id, 'susulan', status_persetujuan, created_at, diproses_at FROM presensi.absen_susulan
  UNION ALL SELECT id, user_id, 'pembatalan', status_persetujuan, created_at, diproses_at FROM presensi.pembatalan_pulang
)
INSERT INTO presensi.notifications(recipient_id, pengaju_id, jenis, request_id, status, created_at)
  SELECT p.id, r.user_id, r.jenis, r.id, r.status, r.created_at
    FROM requests r CROSS JOIN presensi.profiles p JOIN presensi.users u ON u.id = p.id
    WHERE r.status = 'menunggu' AND p.role = 'admin' AND u.active
  UNION ALL SELECT r.user_id, r.user_id, r.jenis, r.id, r.status, coalesce(r.diproses_at, r.created_at)
    FROM requests r WHERE r.status <> 'menunggu'
  ON CONFLICT DO NOTHING;

-- Admin yang baru dibuat juga menerima antrean yang masih menunggu.
CREATE FUNCTION presensi.notify_new_admin() RETURNS trigger LANGUAGE plpgsql
SET search_path = pg_catalog AS $$
BEGIN
  IF NEW.role <> 'admin' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE' AND OLD.role = 'admin' THEN RETURN NEW; END IF;
  INSERT INTO presensi.notifications(recipient_id, pengaju_id, jenis, request_id, status, created_at)
    SELECT NEW.id, user_id, 'izin', id, 'menunggu', created_at FROM presensi.izin WHERE status_persetujuan = 'menunggu'
    UNION ALL SELECT NEW.id, user_id, 'susulan', id, 'menunggu', created_at FROM presensi.absen_susulan WHERE status_persetujuan = 'menunggu'
    UNION ALL SELECT NEW.id, user_id, 'pembatalan', id, 'menunggu', created_at FROM presensi.pembatalan_pulang WHERE status_persetujuan = 'menunggu'
    ON CONFLICT DO NOTHING;
  RETURN NEW;
END $$;
CREATE TRIGGER notify_new_admin AFTER INSERT OR UPDATE OF role ON presensi.profiles
  FOR EACH ROW EXECUTE FUNCTION presensi.notify_new_admin();
REVOKE ALL ON presensi.files, presensi.notifications FROM PUBLIC;
