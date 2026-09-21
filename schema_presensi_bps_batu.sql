-- ============================================
-- SKEMA DATABASE: PRESENSI BPS KOTA BATU
-- ============================================

-- 1. TABEL PROFILES (data tambahan user, terhubung ke auth.users bawaan Supabase)
create table profiles (
  id uuid references auth.users on delete cascade primary key,
  nama_lengkap text not null,
  nim text, -- Nomor Induk Mahasiswa (opsional, kalau peserta magang mahasiswa)
  asal_instansi text, -- kampus/sekolah asal
  no_hp text,
  role text not null default 'peserta' check (role in ('peserta', 'admin')),
  foto_profil_url text,
  created_at timestamp with time zone default now()
);

-- 2. TABEL ABSENSI
create table absensi (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  tanggal date not null default current_date,
  jam_masuk timestamp with time zone,
  jam_pulang timestamp with time zone,
  latitude_masuk double precision,
  longitude_masuk double precision,
  latitude_pulang double precision,
  longitude_pulang double precision,
  foto_masuk_url text,
  foto_pulang_url text,
  status text not null default 'hadir' check (status in ('hadir', 'terlambat', 'izin', 'sakit', 'alpha')),
  jarak_dari_kantor_meter double precision, -- untuk validasi radius geotagging
  created_at timestamp with time zone default now(),
  unique(user_id, tanggal) -- satu user hanya bisa 1 record per tanggal
);

-- 3. TABEL IZIN (pengajuan izin/sakit)
create table izin (
  id uuid default gen_random_uuid() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  tanggal_mulai date not null,
  tanggal_selesai date not null,
  jenis text not null check (jenis in ('izin', 'sakit')),
  keterangan text,
  bukti_url text, -- upload surat dokter/keterangan
  status_persetujuan text not null default 'menunggu' check (status_persetujuan in ('menunggu', 'disetujui', 'ditolak')),
  disetujui_oleh uuid references profiles(id),
  created_at timestamp with time zone default now()
);

-- ============================================
-- ROW LEVEL SECURITY (RLS) - WAJIB DIAKTIFKAN
-- ============================================

alter table profiles enable row level security;
alter table absensi enable row level security;
alter table izin enable row level security;

-- Policy: User bisa lihat & update profil sendiri
create policy "User dapat melihat profil sendiri"
  on profiles for select
  using (auth.uid() = id);

create policy "User dapat update profil sendiri"
  on profiles for update
  using (auth.uid() = id);

create policy "User dapat insert profil sendiri saat register"
  on profiles for insert
  with check (auth.uid() = id);

-- Policy: Admin bisa lihat semua profil
create policy "Admin dapat melihat semua profil"
  on profiles for select
  using (
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

-- Policy: User bisa lihat & insert absensi sendiri
create policy "User dapat melihat absensi sendiri"
  on absensi for select
  using (auth.uid() = user_id);

create policy "User dapat insert absensi sendiri"
  on absensi for insert
  with check (auth.uid() = user_id);

create policy "User dapat update absensi sendiri di hari yang sama"
  on absensi for update
  using (auth.uid() = user_id);

-- Policy: Admin bisa lihat semua absensi
create policy "Admin dapat melihat semua absensi"
  on absensi for select
  using (
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

-- Policy: User bisa lihat & ajukan izin sendiri
create policy "User dapat melihat izin sendiri"
  on izin for select
  using (auth.uid() = user_id);

create policy "User dapat mengajukan izin sendiri"
  on izin for insert
  with check (auth.uid() = user_id);

-- Policy: Admin bisa lihat & update semua izin (approve/reject)
create policy "Admin dapat melihat semua izin"
  on izin for select
  using (
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

create policy "Admin dapat update status izin"
  on izin for update
  using (
    exists (
      select 1 from profiles where id = auth.uid() and role = 'admin'
    )
  );

-- ============================================
-- FUNCTION: Auto-create profile saat user register
-- ============================================
create function public.handle_new_user()
returns trigger as $$
begin
  insert into public.profiles (id, nama_lengkap, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'nama_lengkap', 'Peserta Magang'), 'peserta');
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
