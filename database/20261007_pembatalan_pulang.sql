-- ARSIP SUPABASE: tidak digunakan aplikasi saat ini.
-- Skema PostgreSQL aktif dikelola melalui backend/migrations dan npm run db:migrate.

-- Jalankan sekali di Supabase SQL Editor sebelum memakai versi aplikasi ini.
-- Persetujuan dan pengosongan jam pulang dilakukan dalam satu transaksi.
begin;

create table public.pembatalan_pulang (
  id uuid primary key default gen_random_uuid(),
  absensi_id uuid not null references public.absensi(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  tanggal date not null,
  jam_pulang_awal timestamptz not null,
  alasan text not null check (length(trim(alasan)) between 5 and 1000),
  status_persetujuan text not null default 'menunggu'
    check (status_persetujuan in ('menunggu', 'disetujui', 'ditolak')),
  disetujui_oleh uuid references public.profiles(id),
  created_at timestamptz not null default now(),
  diproses_at timestamptz
);
create unique index pembatalan_pulang_pending_unique
  on public.pembatalan_pulang(absensi_id) where status_persetujuan = 'menunggu';
create index pembatalan_pulang_user_created on public.pembatalan_pulang(user_id, created_at desc);
alter table public.pembatalan_pulang enable row level security;
create policy "Lihat pembatalan sendiri atau admin" on public.pembatalan_pulang
  for select to authenticated using (user_id = auth.uid() or public.is_admin());
revoke all on public.pembatalan_pulang from anon, authenticated;
grant select on public.pembatalan_pulang to authenticated;

create function public.ajukan_pembatalan_pulang(p_absensi_id uuid, p_alasan text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  a public.absensi%rowtype;
  request_id uuid;
begin
  if auth.uid() is null then raise exception 'Silakan masuk kembali.'; end if;
  if p_alasan is null or length(trim(p_alasan)) not between 5 and 1000 then
    raise exception 'Alasan wajib diisi, antara 5 dan 1000 karakter.';
  end if;
  select * into a from public.absensi where id = p_absensi_id for update;
  if not found or a.user_id <> auth.uid() then
    raise exception 'Presensi tidak ditemukan.';
  end if;
  if a.tanggal <> (now() at time zone 'Asia/Jakarta')::date or
     a.jam_masuk is null or a.jam_pulang is null or
     a.status not in ('hadir', 'terlambat') or
     (a.jam_pulang at time zone 'Asia/Jakarta')::date <> a.tanggal or
     (a.jam_pulang at time zone 'Asia/Jakarta')::time >= time '16:00' then
    raise exception 'Hanya absen pulang hari ini sebelum 16.00 WIB yang dapat dibatalkan.';
  end if;
  if exists (select 1 from public.pembatalan_pulang
             where absensi_id = a.id and status_persetujuan = 'menunggu') then
    raise exception 'Pengajuan pembatalan masih menunggu persetujuan admin.';
  end if;
  if exists (select 1 from public.izin where user_id = a.user_id
             and tanggal_mulai <= a.tanggal and tanggal_selesai >= a.tanggal
             and status_persetujuan in ('menunggu', 'disetujui')) or
     exists (select 1 from public.absen_susulan where user_id = a.user_id
             and tanggal = a.tanggal and status_persetujuan in ('menunggu', 'disetujui')) then
    raise exception 'Tanggal ini memiliki izin/susulan aktif, bukan presensi pulang normal.';
  end if;
  insert into public.pembatalan_pulang(absensi_id, user_id, tanggal, jam_pulang_awal, alasan)
    values (a.id, a.user_id, a.tanggal, a.jam_pulang, trim(p_alasan)) returning id into request_id;
  return request_id;
end;
$$;

create function public.proses_pembatalan_pulang(p_request_id uuid, p_setujui boolean)
returns void language plpgsql security definer set search_path = public as $$
declare
  r public.pembatalan_pulang%rowtype;
  a public.absensi%rowtype;
begin
  if auth.uid() is null or public.is_admin() is not true then
    raise exception 'Hanya admin yang dapat memproses pembatalan.';
  end if;
  if p_setujui is null then raise exception 'Keputusan wajib diisi.'; end if;
  select * into r from public.pembatalan_pulang where id = p_request_id;
  if not found then raise exception 'Pengajuan tidak ditemukan.'; end if;
  -- Semua operasi mengambil kunci absensi lebih dahulu agar urutan konsisten.
  select * into a from public.absensi where id = r.absensi_id for update;
  if not found then raise exception 'Presensi tidak ditemukan.'; end if;
  select * into r from public.pembatalan_pulang where id = p_request_id for update;
  if not found then raise exception 'Pengajuan tidak ditemukan.'; end if;
  if r.status_persetujuan <> 'menunggu' then
    raise exception 'Pengajuan sudah diproses.';
  end if;
  if p_setujui then
    if a.jam_pulang is distinct from r.jam_pulang_awal or
       a.user_id is distinct from r.user_id or a.tanggal is distinct from r.tanggal or
       a.tanggal <> (now() at time zone 'Asia/Jakarta')::date or
       a.jam_masuk is null or a.status not in ('hadir', 'terlambat') or
       (a.jam_pulang at time zone 'Asia/Jakarta')::time >= time '16:00' then
      raise exception 'Presensi telah berubah atau tanggalnya sudah lewat. Tolak pengajuan ini.';
    end if;
    update public.absensi set jam_pulang = null, latitude_pulang = null,
      longitude_pulang = null, foto_pulang_url = null where id = a.id;
  end if;
  update public.pembatalan_pulang set
    status_persetujuan = case when p_setujui then 'disetujui' else 'ditolak' end,
    disetujui_oleh = auth.uid(), diproses_at = now() where id = r.id;
end;
$$;
revoke all on function public.ajukan_pembatalan_pulang(uuid, text) from public, anon;
revoke all on function public.proses_pembatalan_pulang(uuid, boolean) from public, anon;
grant execute on function public.ajukan_pembatalan_pulang(uuid, text) to authenticated;
grant execute on function public.proses_pembatalan_pulang(uuid, boolean) to authenticated;

-- RLS lama mengizinkan user memperbarui presensinya. Jam pulang yang sudah
-- tersimpan tetap tidak boleh diubah/dikosongkan sendiri melalui API langsung.
create function public.lindungi_jam_pulang_tercatat()
returns trigger language plpgsql set search_path = public as $$
begin
  if old.jam_pulang is not null and new.jam_pulang is distinct from old.jam_pulang
     and public.is_admin() is not true then
    raise exception 'Jam pulang yang sudah tercatat hanya dapat dibatalkan oleh admin.';
  end if;
  return new;
end;
$$;
create trigger lindungi_jam_pulang_tercatat
  before update of jam_pulang on public.absensi
  for each row execute function public.lindungi_jam_pulang_tercatat();
commit;
