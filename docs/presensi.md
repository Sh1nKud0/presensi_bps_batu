# Modul Presensi

Buka `/presensi` untuk preview lokal. Tautan Presensi tidak ditampilkan pada
navbar SIMASTA. Halaman memiliki identitas dan tampilan login/daftar tersendiri.
Masuk dengan akun presensi yang sudah dipakai di Android, bukan akun login
SIMASTA. Pendaftaran di modul ini membuat akun peserta pada layanan presensi.
Hak admin mengikuti akun backend presensi dan tidak diambil dari role SIMASTA.

## Deployment terpisah

Alamat: `https://presensi-simasta.bpskotabatu.com`.
Saat host tersebut diarahkan ke aplikasi ini, `/`, `/login`, dan `/register`
menampilkan halaman Presensi. SIMASTA di host lokal/utama tetap memiliki
halaman awal serta login aslinya.

Untuk deployment yang sepenuhnya melayani Presensi, deploy salinan aplikasi
Laravel ini sebagai layanan terpisah. Gunakan konfigurasi khusus deployment:

```dotenv
APP_NAME="Presensi BPS Kota Batu"
APP_URL=https://presensi-simasta.bpskotabatu.com
APP_DEBUG=false
PRESENSI_STANDALONE=true
PRESENSI_DOMAIN=presensi-simasta.bpskotabatu.com
PRESENSI_API_URL=https://apipresensi.bpskotabatu.com
SESSION_DRIVER=file
SESSION_DOMAIN=null
SESSION_SECURE_COOKIE=true
CACHE_STORE=file
QUEUE_CONNECTION=sync
```

`PRESENSI_STANDALONE=true` membuat `/` menjadi login Presensi dan mengeluarkan
route SIMASTA dari deployment tersebut. Jangan aktifkan mode ini pada server
utama SIMASTA jika masih ingin menggunakan fitur SIMASTA di sana.
Sesi bersifat khusus host, token tetap disimpan pada server, dan data presensi
tetap lewat API bersama. Database PostgreSQL tidak perlu disalin.

Arahkan DNS subdomain ke hosting, atur document root ke direktori `public`,
pasang HTTPS untuk nama domain penuh, serta pastikan `storage` dan
`bootstrap/cache` dapat ditulis. Jalankan `php artisan config:clear` setelah
mengubah mode. Pengaturan DNS/server dan deployment belum dilakukan oleh
perubahan kode ini.

Untuk mencoba mode terpisah di lokal, cukup ubah `PRESENSI_STANDALONE=true`
di `.env`, jalankan `php artisan config:clear`, lalu buka
`http://localhost:8000`. Untuk HTTP lokal, gunakan `SESSION_SECURE_COOKIE=false`;
nilai `true` pada contoh deployment di atas khusus HTTPS hosting.

## Login Google

Login/daftar Google sudah tersedia pada source web dan backend lokal. Tombol
resmi Google muncul setelah Client ID diisi dan backend mendukung endpoint
Google. Untuk pengujian dengan database Android yang sama, jalankan
`node --env-file=.env scripts/presensi-postgres.mjs` dengan tunnel PostgreSQL
aktif dan arahkan `PRESENSI_API_URL=http://127.0.0.1:5010`. Akun Google langsung
disimpan pada PostgreSQL bersama; bukti tetap melewati API hosting. Lihat
[panduan Google, PostgreSQL bersama, dan cara menjalankan](google-login.md).
Endpoint Google di origin hosting sendiri baru tersedia setelah deploy backend.

## Sumber data

Browser → `/presensi/api/...` di Laravel → API Node.js yang juga dipakai Android
→ PostgreSQL BPS, schema `presensi`.

Default API adalah `https://apipresensi.bpskotabatu.com`. Override melalui `.env`:

```dotenv
PRESENSI_API_URL=https://apipresensi.bpskotabatu.com
```

Nilai hanya origin, tanpa `/api` atau `/ready`. Setelah mengganti konfigurasi,
jalankan `php artisan config:clear`. Untuk pengembangan dengan backend lokal,
gunakan `http://127.0.0.1:5010` dan aktifkan backend/tunnel sesuai README Android.

Tidak perlu menyalin tabel atau kredensial PostgreSQL ke SIMASTA. Database
SIMASTA tetap digunakan untuk fitur SIMASTA serta sesi web; seluruh data presensi
disimpan lewat API Android. Integrasi Google menambahkan source dan migrasi
`003_google_identity.sql` serta `004_google_password_compatibility.sql` pada
backend Android. Keduanya sudah diterapkan pada PostgreSQL bersama melalui
tunnel SSH saat integrasi Google. Data presensi dan akun lama tetap digunakan.

## Fitur

- Peserta: daftar/masuk/keluar, presensi GPS masuk/pulang, statistik, riwayat,
  izin/sakit, susulan, pembatalan pulang, bukti privat, notifikasi, hari libur,
  edit profil, serta ganti kata sandi.
- Admin: ringkasan harian seluruh peserta beserta status izin/susulan, daftar
  peserta, persetujuan/penolakan tiga jenis pengajuan, riwayat keputusan melalui
  filter status, bukti pengajuan, hari libur, notifikasi, rekap bulanan berikut
  detail harian dan unduhan Excel, profil serta ganti kata sandi.
- Ringkasan dan notifikasi diperbarui setiap 30 detik saat halaman aktif dan
  pengguna tidak sedang mengisi formulir. Halaman lain membaca ulang sumber
  data saat dibuka; tombol **Perbarui** tersedia untuk mengambil perubahan Android.
- List memiliki pagination. Ringkasan admin memuat seluruh halaman peserta dan
  presensi. Rekap memakai hasil perhitungan backend, bukan perhitungan baru web.

Presensi memakai lokasi baru, maksimal radius 100 meter dari kantor dan akurasi
50 meter. Backend memvalidasi ulang lokasi, waktu, konflik dan persetujuan.
Geolokasi browser memerlukan HTTPS atau localhost. Perangkat desktop dapat
memiliki akurasi yang kurang dari kebutuhan; gunakan perangkat dengan GPS.
Web menunggu pembacaan lokasi baru hingga 30 detik dengan akurasi tinggi,
menampilkan hasil terbaik yang dilaporkan perangkat, dan menghentikan pencarian
ketika akurasi mencapai 50 meter. Hasil yang masih kasar ditampilkan untuk
diagnosis dan tidak dikirim sebagai presensi. Pencarian dapat dibatalkan.
Pin hijau pada peta adalah titik kantor; koordinat perangkat, jarak, akurasi,
waktu pengambilan dan tautan peta perangkat ditampilkan terpisah setelah dicek.
Pada laptop, aktifkan layanan lokasi Windows, izin lokasi situs dan Wi-Fi.
Perbaikan pengambilan sampel tidak menjamin laptop tanpa GPS mencapai 50 meter.
Presensi melalui Android tetap tersinkron di web karena database-nya sama.
Browser tidak dapat membuktikan keaslian GPS atau mendeteksi lokasi tiruan
seperti API native Android. Flag `is_mocked=false` bukan bukti anti-pemalsuan.

## Sesi dan berkas

Bearer token API hanya disimpan terenkripsi di sesi server Laravel, tidak di
localStorage, URL, atau HTML. Endpoint dibatasi ke daftar tetap dan dilindungi
CSRF. Perubahan origin API mengharuskan login ulang agar token tidak dikirim
ke host yang berbeda. Login/keluar presensi mempertahankan sesi login SIMASTA.
Keluar mencabut token web; ganti kata sandi mencabut seluruh sesi termasuk Android.

Unggah dan unduh bukti serta Excel melewati Laravel dengan token pemilik sesi.
Bukti tidak disalin ke `public/storage`. Format dan ukuran file diperiksa oleh
backend asli. Maksimal 5 MiB per gambar dan kuota 100 MiB mengikuti backend.
Tidak ada retry otomatis untuk mutasi: bila koneksi terputus setelah pengiriman,
periksa riwayat sebelum mengirim ulang. Ketika API tidak tersedia, halaman
menampilkan error dan tidak mengganti data dengan database lokal atau data contoh.

## Verifikasi

```powershell
php artisan test
node --test tests/presensi-domain.test.mjs
node --test tests/presensi-shared-files.test.mjs
node --test tests/presensi-location.test.mjs
```

Tes Laravel memakai HTTP tiruan, sesi array, dan SQLite dalam memori sesuai
`phpunit.xml`, sehingga tidak membuat akun/presensi/keputusan pada hosting BPS.
Tes mencakup sesi terpisah, token terenkripsi, pelestarian kata sandi, daftar
endpoint, filter/pagination, penolakan admin, sesi kedaluwarsa, bukti/Excel,
batas upload, pembatasan proxy, koneksi gagal, dan tanpa retry mutasi.

Uji lintas aplikasi opsional, bila proyek Android berada di direktori sebelah
dan dependensi backend Android sudah terpasang:

```powershell
node tests/presensi-sync.mjs
```

Argumen pertama dapat berisi path `php.exe` bila belum ada di PATH. Uji ini
menjalankan source backend Android dengan PostgreSQL PGlite dalam memori serta
server PHP sementara pada port 8012. `.env` backend Android tidak dibaca, dan
konfigurasi hosting tidak diubah. Akun, gambar, pengajuan, persetujuan dan sesi
hanya dibuat pada database uji. Verifikasi mencakup perubahan profil dua arah,
keputusan admin, status baca notifikasi, bukti privat dan Excel melalui Laravel.
Alur Google juga diuji dengan token bertanda tangan RSA lokal melalui verifier
resmi: daftar peserta, pengaitan akun lama, token tetap di server, dan pembuatan
kata sandi untuk login melalui API Android. Token uji ini hanya digunakan tes,
bukan runner Google lokal untuk penggunaan browser.
