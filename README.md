# Presensi BPS Kota Batu

Aplikasi Flutter untuk presensi peserta magang, pengajuan izin/sakit/susulan,
persetujuan admin, pembatalan jam pulang, notifikasi dalam aplikasi, dan rekap Excel.

## Koneksi PostgreSQL

Aplikasi hanya memakai backend Node.js dan PostgreSQL BPS, schema `presensi`.
SDK, konfigurasi, autentikasi, dan jalur akses Supabase telah dihapus dari Flutter.
Akun/data/bukti yang dipakai adalah yang sudah ada pada backend PostgreSQL saat ini;
data Supabase lama tidak diimpor dan database lama tidak dihapus.

`flutter run` langsung menggunakan `http://127.0.0.1:5010` untuk pengembangan.
Untuk HP Android melalui USB, alamat ini menuju laptop lewat `adb reverse`.
Untuk emulator tanpa reverse atau endpoint server lainnya, URL dapat diganti dengan
`--dart-define=API_BASE_URL=...`; pilihan tersebut hanya mengubah alamat backend
PostgreSQL, tidak mengaktifkan layanan database lain. URL adalah origin server,
tanpa `/api` atau `/ready`. Perubahan URL memerlukan restart/build ulang.
Jangan memasukkan password PostgreSQL atau SSH ke Flutter.

## Uji Android melalui USB (backend masih di laptop)

1. Biarkan tunnel SSH ke PostgreSQL BPS tetap terbuka. Panduan backend ada di
   [backend/README.md](backend/README.md).
2. Di terminal backend:

   ```powershell
   cd backend
   npm ci
   npm run dev
   ```

   Pastikan `http://127.0.0.1:5010/ready` menampilkan database connected. Tidak ada
   migrasi SQL tambahan untuk tahap integrasi Flutter ini.
3. Hubungkan HP Android lewat USB, aktifkan USB debugging, dan izinkan komputer.
   Jalankan dari direktori utama project:

   ```powershell
   flutter devices
   adb reverse tcp:5010 tcp:5010
   flutter run
   ```

   Pilih perangkat Android jika Flutter menampilkan beberapa perangkat. Bila adb
   belum ada di PATH, pada instalasi SDK Windows standar gunakan:

   ```powershell
   & "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" reverse tcp:5010 tcp:5010
   ```

   Reverse perlu diulang setelah USB terputus. `127.0.0.1` pada HP menuju laptop
   melalui reverse; tidak perlu mengubah HOST backend atau membuka port LAN.
4. Login dengan akun admin backend yang sudah berhasil pada `npm run auth:check`.
   Buat akun peserta **uji** melalui halaman Daftar pada aplikasi bila diperlukan.
   Tindakan dari aplikasi menulis ke database BPS: gunakan data uji yang jelas.
5. Periksa profil, riwayat, dashboard admin dan ekspor. Untuk alur persetujuan,
   ajukan izin/susulan dengan foto kamera/galeri dari akun peserta uji, proses dari
   admin, lalu periksa hasil/notifikasi pada peserta. Presensi GPS tetap hanya di
   lokasi kantor, dengan lokasi segar dan akurasi maksimal 50 meter.

Alternatif emulator Android: gunakan
`flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5010`.
Alamat `192.168.100.10:5010` belum menjadi endpoint aplikasi sampai backend benar-benar
dipasang pada server. Backend lokal dan tunnel harus aktif selama pengujian.

## Rilis dan sesi

HTTP lokal hanya diizinkan pada build pengembangan Android. Build release
memerlukan URL HTTPS dengan sertifikat valid. Token API disimpan melalui
[flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage),
dipisahkan per origin server. Sesi kedaluwarsa kembali ke login; ganti password
memerlukan password lama dan mencabut semua sesi. Password tidak disimpan di Flutter.
Status notifikasi dibaca disimpan di PostgreSQL.

Integrasi ini berfokus pada Android. Konfigurasi Keychain iOS ditambahkan, tetapi
build/perangkat iOS belum diuji; pengujian iOS menggunakan HTTPS. Flutter Web belum
didukung backend ini (CORS dan penyajian bukti perlu penyesuaian).

## Skema database

Skema aktif berada di `backend/migrations/` dan dikelola oleh `npm run db:migrate`.
`schema_presensi_bps_batu.sql` serta `database/20261007_pembatalan_pulang.sql`
adalah arsip Supabase lama; keduanya tidak digunakan aplikasi sekarang.
Database PostgreSQL yang sudah diuji tidak perlu diinisialisasi ulang.

## Pemeriksaan lokal

```powershell
flutter test
flutter analyze
```

Pengujian Flutter API menggunakan HTTP tiruan dan penyimpanan sesi tiruan.
Pengujian backend menjalankan PostgreSQL PGlite lokal, tidak memakai `.env` atau
database BPS. Lihat backend README untuk `npm test` dan pemeriksaan endpoint baca.
