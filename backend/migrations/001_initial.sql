-- Dijalankan oleh npm run db:migrate dalam transaksi.
-- Semua objek milik aplikasi berada di schema presensi, tanpa auth Supabase.
CREATE TABLE presensi.users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  email text NOT NULL UNIQUE CHECK (email = lower(btrim(email)) AND length(email) <= 254),
  password_hash text NOT NULL,
  active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE presensi.profiles (
  id uuid PRIMARY KEY REFERENCES presensi.users(id) ON DELETE CASCADE,
  nama_lengkap text NOT NULL CHECK (length(btrim(nama_lengkap)) BETWEEN 1 AND 150),
  nim text,
  asal_instansi text,
  no_hp text,
  role text NOT NULL DEFAULT 'peserta' CHECK (role IN ('peserta', 'admin')),
  foto_profil_url text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE presensi.sessions (
  token_hash text PRIMARY KEY CHECK (length(token_hash) = 64),
  user_id uuid NOT NULL REFERENCES presensi.users(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL CHECK (expires_at > created_at)
);
CREATE INDEX sessions_user ON presensi.sessions(user_id);
CREATE INDEX sessions_expiry ON presensi.sessions(expires_at);

CREATE TABLE presensi.absensi (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES presensi.profiles(id) ON DELETE CASCADE,
  tanggal date NOT NULL DEFAULT (now() AT TIME ZONE 'Asia/Jakarta')::date,
  jam_masuk timestamptz,
  jam_pulang timestamptz,
  latitude_masuk double precision CHECK (latitude_masuk BETWEEN -90 AND 90),
  longitude_masuk double precision CHECK (longitude_masuk BETWEEN -180 AND 180),
  latitude_pulang double precision CHECK (latitude_pulang BETWEEN -90 AND 90),
  longitude_pulang double precision CHECK (longitude_pulang BETWEEN -180 AND 180),
  foto_masuk_url text,
  foto_pulang_url text,
  status text NOT NULL DEFAULT 'hadir'
    CHECK (status IN ('hadir', 'terlambat', 'izin', 'sakit', 'alpha', 'dispensasi')),
  jarak_dari_kantor_meter double precision CHECK (jarak_dari_kantor_meter >= 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE(user_id, tanggal),
  CHECK (jam_pulang IS NULL OR (jam_masuk IS NOT NULL AND jam_pulang >= jam_masuk))
);
CREATE INDEX absensi_tanggal ON presensi.absensi(tanggal);

CREATE TABLE presensi.izin (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES presensi.profiles(id) ON DELETE CASCADE,
  tanggal_mulai date NOT NULL,
  tanggal_selesai date NOT NULL CHECK (tanggal_selesai >= tanggal_mulai),
  jenis text NOT NULL CHECK (jenis IN ('izin', 'sakit')),
  keterangan text,
  bukti_url text,
  status_persetujuan text NOT NULL DEFAULT 'menunggu'
    CHECK (status_persetujuan IN ('menunggu', 'disetujui', 'ditolak')),
  disetujui_oleh uuid REFERENCES presensi.profiles(id),
  diproses_at timestamptz,
  alasan_penolakan text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((status_persetujuan = 'menunggu' AND disetujui_oleh IS NULL AND diproses_at IS NULL)
    OR (status_persetujuan <> 'menunggu' AND disetujui_oleh IS NOT NULL AND diproses_at IS NOT NULL))
);
CREATE INDEX izin_user_tanggal ON presensi.izin(user_id, tanggal_mulai, tanggal_selesai);
CREATE INDEX izin_status ON presensi.izin(status_persetujuan, created_at DESC);

CREATE TABLE presensi.absen_susulan (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES presensi.profiles(id) ON DELETE CASCADE,
  tanggal date NOT NULL,
  jam_masuk_diajukan time,
  jam_pulang_diajukan time,
  jenis_alasan text NOT NULL CHECK (jenis_alasan IN ('dispensasi', 'lupa_absen', 'gps_error', 'lainnya')),
  keterangan text NOT NULL,
  bukti_url text,
  status_persetujuan text NOT NULL DEFAULT 'menunggu'
    CHECK (status_persetujuan IN ('menunggu', 'disetujui', 'ditolak')),
  disetujui_oleh uuid REFERENCES presensi.profiles(id),
  diproses_at timestamptz,
  alasan_penolakan text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK (jam_masuk_diajukan IS NOT NULL OR jam_pulang_diajukan IS NOT NULL),
  CHECK (jam_pulang_diajukan IS NULL OR jam_masuk_diajukan IS NULL
    OR jam_pulang_diajukan >= jam_masuk_diajukan),
  CHECK ((status_persetujuan = 'menunggu' AND disetujui_oleh IS NULL AND diproses_at IS NULL)
    OR (status_persetujuan <> 'menunggu' AND disetujui_oleh IS NOT NULL AND diproses_at IS NOT NULL))
);
CREATE INDEX susulan_user_tanggal ON presensi.absen_susulan(user_id, tanggal);
CREATE UNIQUE INDEX susulan_aktif ON presensi.absen_susulan(user_id, tanggal)
  WHERE status_persetujuan IN ('menunggu', 'disetujui');

CREATE TABLE presensi.hari_libur (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tanggal date NOT NULL UNIQUE,
  keterangan text NOT NULL,
  dibuat_oleh uuid REFERENCES presensi.profiles(id),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE presensi.pembatalan_pulang (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  absensi_id uuid NOT NULL REFERENCES presensi.absensi(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES presensi.profiles(id) ON DELETE CASCADE,
  tanggal date NOT NULL,
  jam_pulang_awal timestamptz NOT NULL,
  alasan text NOT NULL CHECK (length(btrim(alasan)) BETWEEN 5 AND 1000),
  status_persetujuan text NOT NULL DEFAULT 'menunggu'
    CHECK (status_persetujuan IN ('menunggu', 'disetujui', 'ditolak')),
  disetujui_oleh uuid REFERENCES presensi.profiles(id),
  diproses_at timestamptz,
  alasan_penolakan text,
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK ((status_persetujuan = 'menunggu' AND disetujui_oleh IS NULL AND diproses_at IS NULL)
    OR (status_persetujuan <> 'menunggu' AND disetujui_oleh IS NOT NULL AND diproses_at IS NOT NULL))
);
CREATE UNIQUE INDEX pembatalan_pending ON presensi.pembatalan_pulang(absensi_id)
  WHERE status_persetujuan = 'menunggu';
CREATE INDEX pembatalan_user ON presensi.pembatalan_pulang(user_id, created_at DESC);

-- Hanya akun backend/owner, bukan PostgreSQL PUBLIC, yang mengakses objek ini.
REVOKE ALL ON ALL TABLES IN SCHEMA presensi FROM PUBLIC;
