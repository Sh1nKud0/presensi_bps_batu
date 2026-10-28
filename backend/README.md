# Backend presensi BPS

Backend Node.js untuk PostgreSQL BPS. Sudah tersedia: migrasi skema, registrasi
peserta, login, sesi, profil, ganti password, logout, presensi masuk/pulang,
izin/susulan, riwayat, keputusan admin, pembatalan pulang, notifikasi,
bukti privat, pengelolaan hari libur dan rekap Excel. Flutter hanya memakai
backend ini dan PostgreSQL schema presensi. Akun/data/file Supabase lama tidak
diimpor; aplikasi menggunakan data PostgreSQL yang sudah tersedia.

## Persiapan laptop Windows

Prasyarat: Node.js >=22.21 (termasuk versi 24), npm, dan jaringan kantor/VPN.

1. Buka tunnel di PowerShell laptop, biarkan tetap terbuka:

   ```powershell
   ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:15432:127.0.0.1:5432 bps@192.168.100.10
   ```

   Gunakan password SSH akun bps. Jika tunnel pgAdmin masih aktif pada port 15432,
   gunakan yang sama; tidak perlu membuka tunnel kedua.

2. Di terminal VS Code, dari root proyek:

   ```powershell
   cd backend
   npm ci
   ```

   Jika belum ada `.env`, salin sekali:

   ```powershell
   Copy-Item .env.example .env
   ```

   Jangan menimpa `.env` yang sudah benar. Isi PGPASSWORD dengan password
   PostgreSQL akun magang, bukan password SSH. File ini diabaikan Git.

3. Periksa koneksi:

   ```powershell
   npm run db:check
   ```

## Membuat tabel di db_magang

Jalankan dari folder backend setelah koneksi berhasil:

```powershell
npm run db:migrate
```

Perintah ini **menulis ke database yang dikonfigurasi di .env**. Tabel baru dibuat
hanya dalam schema `presensi`; tidak menghapus database, schema public atau data
Supabase. Tidak ada koneksi ke database project lain. File SQL dapat ditinjau di
`migrations/001_initial.sql` dan `migrations/002_notifications_files.sql` sebelum dijalankan.

Migrasi memakai transaksi, lock, dan checksum; pengulangan tidak membuat tabel
ganda. File migrasi yang sudah dijalankan jangan diubah: buat migrasi berikutnya.
Jika schema presensi sudah ada tanpa riwayat migrasi, perintah berhenti untuk
menghindari penggunaan schema milik project lain. Tidak ada migrasi otomatis
ketika server backend dimulai.

Di pgAdmin: klik kanan **Schemas ? Refresh**, lalu buka
**presensi ? Tables**. Tersedia users, profiles, sessions, absensi, izin,
absen_susulan, hari_libur, pembatalan_pulang, files, notifications dan schema_migrations.

Jangan menjalankan skema Supabase lama atau file 001 secara manual di Query Tool;
gunakan perintah migrasi agar riwayat dan checksum tercatat.

## Membuat admin pertama

```powershell
npm run admin:create
```

Masukkan email baru, nama, password aplikasi (minimal 8 karakter), dan konfirmasi.
Password tidak tampil ketika diketik dan tidak dimasukkan ke command history.
Akun ini berbeda dari akun PostgreSQL magang maupun akun SSH bps. Gunakan password
aplikasi tersendiri. Perintah hanya boleh membuat admin pertama; jika admin sudah
ada, tidak membuat admin tambahan atau menaikkan role akun peserta.

## Menjalankan dan mengecek login

Terminal backend:

```powershell
npm run dev
```

Biarkan aktif. Di terminal VS Code baru:

```powershell
cd D:\bps-intern-project-ub\presensi_bps_batu\backend
npm run auth:check
```

Masukkan email/password admin yang dibuat tadi. Script mengecek login, profil,
akses admin, logout, dan penolakan token setelah logout. Token tidak dicetak.
`auth:check` membuat lalu mencabut sesi uji; tidak membuat akun atau presensi.
Akun Supabase lama belum bisa dipakai pada API baru sebelum migrasi akun.

Browser dapat membuka http://127.0.0.1:5010/health dan
http://127.0.0.1:5010/ready. Root `/` memang belum dibuat.
`/ready` hanya menguji koneksi PostgreSQL, bukan status migrasi.
Ctrl+C menghentikan backend. Tutup tunnel dengan Ctrl+C setelah backend dan
pgAdmin tidak dipakai lagi.

## Memeriksa API presensi tanpa membuat data uji di server

Restart backend setelah memperbarui kode. Di terminal lain:

```powershell
npm run attendance:check
```

Gunakan akun admin/peserta yang sudah ada pada backend baru. Script login,
membaca status presensi, riwayat dan daftar pengajuan, kemudian logout.
Tidak membuat presensi, pengajuan atau keputusan. Versi terbaru memakai migrasi 002 untuk bukti/notifikasi; jalankan
`npm run db:migrate` sebelum menggunakan backend yang diperbarui.

## Memperbarui backend dari tahap presensi sebelumnya

Biarkan tunnel SSH tetap terbuka. Hentikan backend dengan Ctrl+C, kemudian dari
folder backend:

```powershell
npm ci
npm run db:migrate
npm run dev
```

Migrasi 002 menambah tabel files/notifications, kolom bukti_id, dan trigger
notifikasi. Tidak menghapus akun/admin, presensi, atau data pengajuan yang ada.
Migrasi juga membuat notifikasi untuk pengajuan lama; pengulangan tidak menggandakan
notifikasi. Jangan mengubah atau menjalankan ulang SQL 001 secara manual.

Di terminal kedua:

```powershell
npm run workflow:check
```

Masukkan akun admin backend. Pemeriksaan mencakup login, endpoint baca presensi,
pengajuan, pembatalan, notifikasi, metadata bukti, hari libur, JSON rekap dan hasil
Excel bulan saat ini, kemudian logout. File Excel dibaca di memori dan tidak
disimpan. Tidak membuat presensi/pengajuan, mengunggah foto, memutuskan pengajuan,
atau menandai notifikasi dibaca. Ini bukan pengujian mutasi atau akses disk nyata
pada server BPS; mutasi diuji dengan PostgreSQL lokal dalam memori.

## Kontrak API awal

Semua permintaan dengan body memakai `Content-Type: application/json`, maksimal
16 KiB. Endpoint privat memakai `Authorization: Bearer <access_token>`.

| Metode | Endpoint | Body / hasil |
| --- | --- | --- |
| GET | /health | Status proses |
| GET | /ready | Status koneksi database |
| POST | /api/auth/register | email, password, nama_lengkap; selalu peserta |
| POST | /api/auth/login | email, password ? access_token, token_type, expires_at, user |
| GET | /api/me | Profil akun pemilik token |
| PATCH | /api/me | Satu/lebih: nama_lengkap, nim, asal_instansi, no_hp |
| POST | /api/auth/password | current_password, new_password; semua sesi dicabut |
| POST | /api/auth/logout | Tanpa body; cabut token saat ini |
| GET | /api/admin/users | Admin saja; maksimal 100 profil terbaru |
| GET | /api/attendance/today | Status hari ini, waktu server, izin tombol masuk/pulang |
| GET | /api/attendance/history | Query from, to, limit, offset; hanya milik sendiri |
| POST | /api/attendance/check-in | latitude, longitude, accuracy, captured_at, is_mocked (opsional) |
| POST | /api/attendance/check-out | Lokasi dengan format yang sama; jam berasal dari server |
| POST | /api/requests/izin | tanggal_mulai, tanggal_selesai, jenis, keterangan, bukti_id atau bukti_url (opsional) |
| POST | /api/requests/susulan | tanggal, jam_masuk_diajukan, jam_pulang_diajukan (opsional), jenis_alasan, keterangan, bukti_id atau bukti_url (opsional) |
| GET | /api/requests/izin atau /api/requests/susulan | Pengajuan milik sendiri; query status, limit, offset |
| GET | /api/admin/requests/izin atau /api/admin/requests/susulan | Admin saja; status default menunggu, limit, offset |
| POST | /api/admin/requests/{izin atau susulan}/{id}/decision | setujui (boolean), alasan_penolakan (wajib jika ditolak) |
| POST | /api/requests/pembatalan | absensi_id, alasan (5?1000 karakter) |
| GET | /api/requests/pembatalan | Pengajuan pembatalan milik sendiri; status, limit, offset |
| GET | /api/admin/requests/pembatalan | Antrean admin; status default menunggu |
| POST | /api/admin/requests/pembatalan/{id}/decision | setujui, alasan_penolakan jika ditolak |
| GET | /api/notifications | date (opsional, YYYY-MM-DD WIB), unread (true/false), limit, offset |
| PATCH | /api/notifications/read | ids (1?100 ID) atau date; hanya penerima |
| GET | /api/files | Metadata bukti milik sendiri, kuota; limit, offset |
| POST | /api/files | Body byte gambar mentah; Content-Type image/jpeg, image/png atau image/webp |
| GET | /api/files/{id} | Unduh bukti privat, pemilik/admin dengan Bearer token |
| GET | /api/holidays | Hari libur; from, to, limit, offset |
| POST | /api/admin/holidays | tanggal, keterangan |
| DELETE | /api/admin/holidays/{id} | Hapus hari libur, admin saja |
| GET | /api/admin/rekap | month, year; detail dan ringkasan JSON |
| GET | /api/admin/rekap.xlsx | month, year; unduh workbook Excel |

Presensi masuk/pulang mengembalikan 200; pengajuan baru 201. Semua tanggal memakai
YYYY-MM-DD; jam susulan HH:mm atau HH:mm:ss dan ditafsirkan sebagai WIB. Status
menunggu/disetujui memblokir presensi pada tanggal terkait. Penolakan membuka
kesempatan mengajukan ulang jika belum ada presensi.

Registrasi mengembalikan 201, email duplikat 409. Login gagal/sesi tidak sah 401,
akses admin oleh peserta 403, body tidak sah 400, pembatasan percobaan 429, dan
koneksi/skema belum siap 503. Hash password dan hash token tidak dikirim API.

Password di-hash memakai scrypt dan salt acak. Token acak berlaku 7 hari menurut
waktu database; hanya SHA-256 token yang disimpan. Tidak ada refresh token:
login ulang setelah kedaluwarsa. Password tidak di-trim. Kolom role, email dan id
tidak dapat diubah melalui edit profil. Query memakai parameter dan transaksi.

Registrasi tahap ini belum mengirim email verifikasi atau menyediakan lupa
password. Pembatasan percobaan memakai memori satu proses (10/menit per alamat
koneksi, berlaku juga untuk seluruh endpoint mutasi). Jangan expose API ini
ke internet sebelum menyiapkan HTTPS, pengaturan proxy/limiter yang sesuai,
backup, dan kebijakan pendaftaran. Limiter saat ini tidak mempercayai header
X-Forwarded-For; di belakang Nginx seluruh koneksi bisa memakai jatah IP yang sama.
Hak database berada pada akun backend, bukan token pengguna. Jangan menaruh
kredensial PostgreSQL pada Flutter atau membuka endpoint SQL umum.

## Pengujian

```powershell
npm test
```

Tes SQL dan alur HTTP menggunakan PostgreSQL dalam memori (PGlite): migrasi,
rollback akun/profil, constraint data, login salah/benar, sesi kedaluwarsa,
logout, perubahan password, penolakan eskalasi role, dan akses admin.
Tes presensi mencakup batas keterlambatan, lokasi, hari libur, konflik dua arah,
keputusan ganda, dan rollback saat insert presensi berhasil tetapi update
pengajuan gagal. Semua mutasi domain mengunci profile peserta terlebih dahulu
lalu memeriksa ulang data. Pola ini menyerialkan operasi user yang sama walau
belum ada baris absensi. PGlite bukan pengujian koneksi server BPS/PostgreSQL 16
atau konkurensi antar koneksi. Gunakan db:check, auth:check, dan attendance:check
untuk uji server setelah migrasi. workflow:check mencakup endpoint baca fitur lanjutan.
Tidak ada tes yang membaca .env atau mengubah database BPS secara otomatis.

## Aturan presensi dan pengajuan

- Titik kantor mengikuti Flutter: -7.8668, 112.5073; radius 100 meter.
- Backend menghitung jarak ulang, tidak menerima jarak/status/jam dari klien.
- Akurasi GPS maksimal 50 m; captured_at harus ISO-8601 dengan zona waktu,
  maksimal 120 detik lalu atau 30 detik di depan jam server. Flag is_mocked=true
  ditolak. Validasi ini tidak dapat membuktikan keaslian GPS pada perangkat yang
  dimodifikasi; Flutter nantinya harus mengambil ulang lokasi sebelum kirim.
- Jam masuk/pulang dan tanggal presensi berasal dari server. Tepat 07:30 WIB
  hadir; setelah itu terlambat. Pulang sebelum 16:00 masih boleh sesuai alur lama.
- Akhir pekan/hari_libur memblokir presensi. Presensi masuk dan pulang masing-masing
  sekali. Tidak ada endpoint untuk menimpa jam presensi tersimpan.
- Presensi yang sudah ada memblokir izin/susulan. Izin/susulan aktif memblokir
  presensi dan pengajuan yang tumpang tindih, termasuk izin rentang tanggal.
- Izin memakai tanggal dari 7 hari lalu sampai 90 hari mendatang. Susulan maksimal
  14 hari lalu sampai hari ini; tidak boleh hari libur atau jam masa depan.
- Susulan wajib memiliki jam masuk. Karena pengajuan tidak dapat mengganti presensi
  yang ada, jam pulang saja tanpa jam masuk tidak dapat menghasilkan presensi sah.
- Persetujuan susulan membuat presensi dan keputusan dalam satu transaksi. Jam
  ditafsirkan WIB, terlepas dari zona waktu perangkat admin atau database.
- Keputusan hanya untuk pengajuan menunggu. Alasan penolakan wajib, waktu keputusan
  dan admin dicatat. Tidak ada endpoint untuk mengubah keputusan lama.
- Pagination default 50, maksimal 100. Riwayat default 31 tanggal terakhir;
  filter from/to maksimal 366 tanggal. Daftar admin default pengajuan menunggu.
- bukti_id hanya boleh menunjuk file milik pengaju. bukti_url HTTPS masih
  didukung untuk kompatibilitas bukti lama; backend tidak mengunduh URL eksternal.

## Pembatalan pulang dan notifikasi

Pembatalan hanya untuk presensi normal hari ini dengan jam pulang yang tercatat
sebelum 16:00 WIB. Pengajuan tidak langsung mengubah jam. Satu pengajuan menunggu
per presensi. Persetujuan harus pada tanggal yang sama, memeriksa snapshot asli
hingga mikrodetik, lalu mengosongkan jam/lokasi/foto pulang dan menyimpan keputusan
dalam satu transaksi. Jam masuk dipertahankan. Setelah disetujui peserta bisa
presensi pulang kembali. Pengajuan kedaluwarsa dapat ditolak, tetapi tidak disetujui.

Notifikasi pengajuan dikirim ke akun admin aktif, hasil keputusan ke pengaju.
Ini notifikasi dalam aplikasi, belum push notification perangkat. Waktu hasil
mengikuti diproses_at; filter tanggal memakai WIB. Status dibaca disimpan di
PostgreSQL sehingga konsisten lintas perangkat. Admin baru menerima pengajuan
lama yang masih menunggu. Notifikasi admin lama tetap menjadi riwayat setelah
pengajuan diproses, bukan dihapus.

## Bukti privat dan backup

Unggah memakai body byte mentah, bukan multipart/base64. Ukuran maksimal 5 MiB,
kuota metadata 100 MiB per akun. JPEG/PNG/WebP diperiksa signature dan kesesuaian
MIME; backend tidak mendekode/mengolah gambar atau memindai antivirus. PDF, SVG,
HEIC, dan file lain belum didukung. Gunakan bukti_id pada pengajuan.

File disimpan dengan nama UUID server di backend/data/private (diabaikan Git).
UPLOAD_DIR di .env dapat menunjuk direktori privat permanen lain. Jangan expose
direktori ini lewat static hosting/Nginx. Unduh lewat endpoint terautentikasi,
berupa attachment dengan nosniff. Metadata ukuran/hash diperiksa ketika diunduh.
Admin dapat membaca bukti peserta untuk persetujuan; peserta hanya bukti sendiri.

Backup harus mencakup **database dan direktori bukti**, serta memastikan permission
akun proses backend dapat menulisnya. Saat deployment, file yang diunggah ke backend
laptop tidak otomatis ada pada server; pindahkan direktori beserta metadata.
Tidak ada endpoint hapus bukti saat ini. File tanpa metadata (misalnya hasil COMMIT
terputus, atau akun dihapus langsung lewat SQL) perlu pemeriksaan/pembersihan pada
pemeliharaan. Jangan menghapus direktori sebelum mencocokkan dengan tabel files.

## Rekap admin

JSON dan XLSX hanya untuk admin, maksimum 1000 peserta (role peserta). Semua data
bulan dibaca pada snapshot repeatable-read. Excel berisi Ringkasan, Detail harian,
dan Keterangan; header dibekukan, filter aktif, teks dibungkus dan tinggi baris
menyesuaikan panjang teks. String pengguna tidak ditulis sebagai formula.

Perhitungan mengikuti RekapPresensi Flutter: presensi nyata mengungguli izin,
sakit diprioritaskan jika data izin lama bertumpuk; hanya izin disetujui dihitung.
Total hadir sudah mencakup terlambat. Total tercatat = hadir + izin + sakit +
dispensasi. Akhir pekan/libur/tanggal mendatang tidak masuk total walaupun ada
catatan. Hari kerja lewat tanpa data diberi Tanpa catatan, bukan otomatis Alpha.
Masa magang per peserta belum dimodelkan, mengikuti aplikasi saat ini.

## Menjalankan aplikasi

`flutter run` sekarang langsung memakai backend lokal `http://127.0.0.1:5010`.
Panduan USB Android ada di [README utama](../README.md). Flutter tidak memiliki
SDK ataupun fallback Supabase. `--dart-define=API_BASE_URL=...` hanya diperlukan
untuk mengganti alamat API, misalnya emulator atau endpoint HTTPS server.
Backend dan koneksi PostgreSQL harus aktif. SSH bawaan DBeaver hanya melayani
DBeaver; backend dengan PGPORT=15432 memerlukan tunnel PowerShell sendiri.
Tahap penghapusan Supabase dari Flutter tidak menambahkan migrasi SQL.

Endpoint tambahan untuk tampilan mobile:

- `GET /api/me/statistics`: jumlah hadir (ada jam masuk) dan pengajuan izin yang
  disetujui, hanya milik akun terautentikasi, mencakup seluruh riwayat.
- `GET /api/admin/participants?limit=100&offset=0`: peserta berurutan nama/ID,
  hanya kolom profil yang diperlukan dashboard, tanpa hash atau password.
- `GET /api/admin/attendance?from=YYYY-MM-DD&to=YYYY-MM-DD&limit=100&offset=0`:
  presensi dengan nama peserta, rentang maksimal 366 hari. Tanpa tanggal memakai
  hari server WIB. Kedua endpoint admin menolak peserta.

Flutter memakai endpoint keputusan, bukan menulis tabel presensi dari perangkat;
unggah bukti byte mentah lalu mengirim `bukti_id`, dengan akses unduh terautentikasi.
Persetujuan susulan dan penentuan jam/status tetap dalam transaksi backend.

Aturan lintas tabel saat ini diterapkan oleh backend dalam transaksi dengan
kunci profile. Akses SQL langsung oleh owner database tidak melewati validasi
backend; jangan memberikan kredensial PostgreSQL kepada pengguna aplikasi.
Saat backend dijalankan di server, PGPORT menjadi 5432; HOST tetap 127.0.0.1
untuk Nginx. Port 5010, endpoint HTTPS dan pengelola layanan mengikuti konfigurasi
admin. HTTP lokal pada langkah di atas hanya untuk pengembangan melalui tunnel.

Referensi: [node-postgres](https://node-postgres.com/features/connecting),
[transaksi](https://node-postgres.com/features/transactions), dan
[Node.js crypto](https://nodejs.org/api/crypto.html).


## Login Google untuk web dan akun Android yang sama

Panduan Android, fingerprint SHA-1, status hosting, dan deployment Git yang
memisahkan pemeriksaan baca-saja dari persetujuan migrasi/deploy tersedia di
[`docs/google-android.md`](../docs/google-android.md). `npm run google:check`
hanya memeriksa konfigurasi dan checksum migrasi; tidak mengubah database.

Tambahkan `GOOGLE_CLIENT_IDS=<OAUTH_CLIENT_ID_WEB>` ke environment backend.
Beberapa Client ID dipisahkan koma. Kosong berarti login Google dinonaktifkan.
Frontend Laravel memakai `PRESENSI_GOOGLE_CLIENT_ID` dengan Client ID web yang sama.
Client Secret tidak dipakai oleh alur Google Identity Services ini.

Setelah deploy kode backend dari Git, pasang dependency dan jalankan migrasi
baru **003_google_identity.sql** dan **004_google_password_compatibility.sql**
melalui runner migrasi yang sudah tersedia:

```sh
npm ci --omit=dev --ignore-scripts
npm run db:migrate
```

Restart service backend dengan mekanisme hosting yang digunakan. Jangan mengubah
SQL 001/002 yang sudah berjalan atau menjalankan ulang skema arsip Supabase.
Migrasi 003 menambah identitas Google dan challenge sekali pakai; akun/password
lama tidak dihapus. Migrasi 004 memakai marker hash non-null yang tidak dapat
dipakai untuk login password pada backend lama sekalipun. Akun Google baru
memakainya sampai pemilik membuat kata sandi melalui web. Data tetap berada
di schema `presensi`.
Tinjau dan backup database sebelum menjalankan migrasi pada hosting produksi.

Kontrak baru:

| Metode | Endpoint | Fungsi |
| --- | --- | --- |
| GET | /api/auth/google/config | Status enabled, tanpa rahasia |
| POST | /api/auth/google/challenge | JSON `{}`; nonce + expires_at, berlaku 5 menit |
| POST | /api/auth/google | credential (Google ID token), nonce; existing_password jika menghubungkan akun lama |

Token diverifikasi library Google resmi: signature, audience, issuer, expiry,
email_verified, dan nonce. Challenge disimpan sebagai hash dan hanya dikonsumsi
saat login berhasil. Subject Google dipetakan ke user_id presensi yang stabil.
Email yang cocok dengan akun lama menghasilkan 409 `google_link_required`;
password presensi lama wajib diverifikasi sebelum identitas ditautkan, termasuk
untuk admin. Login Google tidak dapat memilih atau menaikkan role dari payload.

Respons user menambah `has_password`. Akun baru dari Google selalu peserta dan
bisa membuat password di web maksimal 10 menit setelah login Google. Endpoint
password yang sama menerima new_password tanpa current_password hanya untuk
akun Google yang belum mempunyai password dan sesi yang masih baru. Pembuatan/
perubahan password mencabut semua sesi. Setelah itu akun tersebut bisa masuk di
Android menggunakan email dan password, dengan user_id dan data yang sama.

Tes Google memakai JWT RSA bertanda tangan lokal dan key verifikasi lokal pada
library resmi Google, serta PostgreSQL PGlite. Tidak ada login Google nyata,
pembacaan `.env`, atau perubahan database BPS saat `npm test`.
