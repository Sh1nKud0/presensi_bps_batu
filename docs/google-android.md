# Login Google Android dan web Presensi

## Status pemeriksaan — 28 Oktober 2026

- Android: `com.example.presensi_bps_batu`, nama aplikasi tetap magang presensi bps Batu.
- Web yang diperiksa: `../simasta`, terutama `app/Http/Controllers/PresensiController.php`,
  `public/presensi-assets/app.js`, `resources/views/presensi/index.blade.php`,
  `scripts/presensi-postgres.mjs`, dan `docs/google-login.md`.
- Web memakai backend Node pada project ini. Laravel meneruskan challenge dan
  credential, kemudian menyimpan sesi presensi dari backend; bukan membuat akun
  Laravel lain untuk pengguna Presensi.
- Backend lokal sudah memiliki `src/google.js`, `google-auth-library`, endpoint
  Google, dan migrasi 003/004 dari integrasi web sebelumnya. Implementasi tersebut
  dipakai kembali; SQL yang sudah diterapkan tidak diubah.
- Pemeriksaan database **hanya baca** menemukan 001, 002, 003, dan 004 tercatat.
  Tidak ada migrasi, pembuatan akun, atau perubahan akun produksi yang dijalankan.
- GET `https://apipresensi.bpskotabatu.com/api/auth/google/config` mengembalikan
  **404**. Endpoint Google belum tersedia pada hosting yang diperiksa.
- `backend/.env` lokal yang diperiksa belum menyediakan Client ID tersebut pada
  `GOOGLE_CLIENT_IDS`. Runner web dapat menyuntikkannya dari konfigurasi SIMASTA.
- Tidak ada akses ke Google Cloud Console. Keberadaan client Android, consent,
  akun penguji, maupun login Google nyata pada HP belum dapat diverifikasi.

## Identitas dan keamanan

Alur Android menggunakan **Google Credential Manager** native melalui channel
`presensi/google_identity`. `GetSignInWithGoogleOption` menerima **nonce baru pada
setiap percobaan**, sesuai challenge backend. Ini menghindari penggunaan ulang
nonce pada SDK yang hanya menyediakan nonce saat inisialisasi sekali.

1. Tombol login/registrasi memeriksa GET `/api/auth/google/config`.
2. POST `/api/auth/google/challenge` dengan `{}` menghasilkan nonce sekali pakai.
3. Credential Manager meminta ID token dengan nonce tersebut dan Web Client ID.
4. Android mengirim **credential + nonce** ke POST `/api/auth/google`.
5. Backend memverifikasi signature menggunakan sertifikat Google melalui library
   resmi, `aud`, `iss`, expiry, waktu penerbitan, `email_verified`, dan nonce.
6. Subject Google yang sudah terhubung memakai `user_id` yang sama dengan web.
   Backend tidak memperbarui identitas berdasarkan email yang berubah.
7. Untuk email yang sudah mempunyai akun password, backend menolak linking
   otomatis dengan `google_link_required`. Android meminta password presensi;
   baru setelah benar backend menambahkan identitas Google ke akun yang sama.
   Membatalkan atau salah password tidak menghubungkan akun. Admin tidak bisa
   diambil alih hanya dengan kecocokan email.
8. Akun Google baru selalu peserta. Tidak ada role atau ID pengguna yang diterima
   dari profil Google yang dikirim aplikasi. ID token tidak disimpan; hanya token
   sesi presensi disimpan pada secure storage yang dibatasi berdasarkan origin API.
9. Login password tetap memakai endpoint yang sama. Akun Google baru boleh membuat
   password dari halaman Keamanan setelah login Google baru (batas 10 menit,
   diperiksa backend). Membuat/mengubah password mencabut semua sesi seperti biasa.

Tidak ada client secret, service-account key, Firebase Auth, atau database baru.
Ikon tombol memakai gambar G resmi Google dari
`https://developers.google.com/static/identity/images/g-logo.png`, tanpa modifikasi.
Sinkronisasi terjadi karena kedua aplikasi menggunakan `presensi.users`,
`presensi.profiles`, `presensi.google_identities` dan tabel presensi yang sama.
Alamat API lokal dan hosting mempunyai penyimpanan sesi berbeda; login ulang
diperlukan ketika berpindah origin, sedangkan ID akun/data tetap sama.

## Konfigurasi Google Cloud Console

1. Buka Google Cloud Console dan pilih project **presensi-bps-513002**.
2. Google Auth Platform → **Clients**. Periksa client **Web application** yang
   sudah digunakan web:

   ```text
   453707057025-ih5pkesie7ac2sg07ttupig284ecaatr.apps.googleusercontent.com
   ```

   ID ini adalah `serverClientId` Android sekaligus audience backend. Jangan
   menggantinya dengan ID client bertipe Android. Client ID bukan rahasia.
3. Tambahkan OAuth client bertipe **Android** (atau gunakan yang sudah mempunyai
   pasangan package/fingerprint persis sama):

   ```text
   Package name: com.example.presensi_bps_batu
   SHA-1: C8:6E:42:D9:16:85:2B:FC:CC:D9:2B:EB:F3:D7:D1:0E:D6:3F:EA:A5
   ```

   Contoh nama client: `Presensi Android laptop`. Ini hasil Gradle
   `:app:signingReport` pada mesin ini, bukan fingerprint yang ditebak.
4. **Debug dan release saat ini memakai sertifikat yang sama**, karena konfigurasi
   release masih `signingConfigs.getByName("debug")`. Tidak ditemukan konfigurasi
   release key khusus pada app. Jadi untuk APK dari mesin ini pasangan client di
   atas mencakup keduanya. Perubahan keystore/mesin memerlukan pengecekan ulang.
   Jika memilih akun Google langsung kembali tanpa login, periksa pasangan
   package/SHA-1 dan serverClientId; Credential Manager kadang melaporkan
   kesalahan konfigurasi sebagai pembatalan.
5. Sebelum memakai signing rilis khusus, buat client Android tambahan untuk
   package yang sama dan SHA-1 sertifikat rilis yang sebenarnya. Bila melalui
   Google Play App Signing, daftarkan SHA-1 **app signing certificate** dari Play
   Console, bukan hanya upload key. Jangan mengirim keystore/password/kunci privat.
6. Periksa **Branding** dan **Audience**. Untuk Gmail umum gunakan audience yang
   mendukung pengguna tersebut. Jika aplikasi masih Testing, tambahkan akun
   penguji pada Test users sesuai pengaturan consent project. Login ini hanya
   memerlukan identitas dasar (`openid`, email, profil), bukan izin Gmail/Drive.
7. Client Android tidak membutuhkan Authorized JavaScript origins atau redirect
   URI web. Origin web SIMASTA tetap dikonfigurasi pada client Web sesuai
   `../simasta/docs/google-login.md`. Tidak perlu `google-services.json` untuk
   implementasi Credential Manager dengan serverClientId eksplisit ini.

Cek ulang fingerprint dari PowerShell:

```powershell
cd D:\bps-intern-project-ub\presensi_bps_batu\android
.\gradlew.bat :app:signingReport
```

## Menjalankan Android

### Hosting — setelah deployment backend disetujui dan selesai

Dari root Flutter:

```powershell
flutter run --dart-define=API_BASE_URL=https://apipresensi.bpskotabatu.com
```

Web Client ID di atas sudah menjadi default `GOOGLE_SERVER_CLIENT_ID`. Bila
perlu override, tambahkan `--dart-define=GOOGLE_SERVER_CLIENT_ID=CLIENT_ID_WEB`.
Hentikan aplikasi lalu jalankan ulang setelah perubahan native; hot reload
tidak memasang method channel baru. Selama hosting masih 404 atau dinonaktifkan,
tombol memberi pesan yang jelas dan login password tetap tersedia.

### Backend lokal untuk pengujian bersama web

Konfigurasi PostgreSQL/tunnel yang sudah berjalan dipertahankan. Dari folder
`backend`, aktifkan **hanya konfigurasi proses lokal**, tanpa mencetak `.env`:

```powershell
$env:GOOGLE_CLIENT_IDS='453707057025-ih5pkesie7ac2sg07ttupig284ecaatr.apps.googleusercontent.com'
npm run google:check
npm run dev
```

`google:check` hanya membaca checksum migrasi dan keberadaan tabel, tidak
menjalankan SQL migrasi atau mengubah akun. Jika gagal, berhenti dan periksa
penyebabnya; jangan langsung menjalankan `db:migrate` pada database bersama.

Terminal kedua, dari root Flutter, dengan HP terhubung USB:

```powershell
& "$env:LOCALAPPDATA\Android\sdk\platform-tools\adb.exe" reverse tcp:5010 tcp:5010
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:5010
```

HTTP lokal hanya untuk debug melalui USB. APK release tetap membutuhkan HTTPS.
Untuk web, arahkan `PRESENSI_API_URL` ke proses backend yang sama, sesuai petunjuk
SIMASTA. Jangan menjalankan dua proses pada port 5010 yang sama.

**Perhatian data:** backend lokal tersebut terhubung ke database bersama.
Menekan Google lalu menyelesaikan login bisa membuat akun/identitas/sesi nyata.
Konfirmasi dahulu akun uji yang akan digunakan. Tes otomatis di bawah tidak
mengakses database itu.

## Menyiapkan deploy lewat Git — belum dijalankan

Perubahan backend Google dari pekerjaan web sebelumnya ada di working tree;
Android saja tidak cukup. Tinjau diff dan commit/push branch yang disepakati
terlebih dahulu. Paket commit harus mencakup:

- `backend/src`, `backend/migrations/003_google_identity.sql` dan `004_google_password_compatibility.sql`;
- `backend/package.json`, `backend/package-lock.json`, script `check-google.js`, tes backend;
- `backend/.env.example`, README dan dokumentasi ini;
- perubahan Android/Dart, asset Google, pubspec, dan tes Flutter.

Jangan stage `.env`, `data`, `node_modules`, file signing, atau token. Tidak ada
commit/push/deploy otomatis yang dilakukan oleh implementasi ini.

Setelah pengguna menyetujui deployment, admin dapat menggunakan checkout Git
terpisah di server. Contoh branch saat pemeriksaan adalah
`perbaikan/status-dan-notifikasi-admin`; pastikan perubahan sudah dipush.

```sh
# Server BPS, sebagai bps. Hanya untuk checkout sumber yang belum ada:
git clone --branch perbaikan/status-dan-notifikasi-admin https://github.com/Sh1nKud0/presensi_bps_batu.git ~/apps/presensi-source
# Repository privat meminta autentikasi Git melalui mekanisme admin yang sudah ada.
# Jika checkout sudah ada, gunakan git fetch dan git pull --ff-only pada branch
# yang telah ditinjau. Jangan reset/hapus perubahan lokal.

# Pastikan WorkingDirectory service memang folder backend yang akan diperbarui:
systemctl show -p WorkingDirectory --value presensi-backend

# Salin kode tanpa menghapus atau menimpa .env maupun bukti privat:
rsync -av --exclude='.env' --exclude='node_modules/' --exclude='data/' --exclude='*.log' ~/apps/presensi-source/backend/ ~/apps/presensi-backend/
cd ~/apps/presensi-backend
npm ci --omit=dev --ignore-scripts
nano .env
```

Tambahkan Client ID Web pada **environment server**, pertahankan konfigurasi
PostgreSQL server (`PGHOST=127.0.0.1`, `PGPORT=5432`) dan lokasi bukti yang ada:

```dotenv
GOOGLE_CLIENT_IDS=453707057025-ih5pkesie7ac2sg07ttupig284ecaatr.apps.googleusercontent.com
```

Jika sudah ada client lain yang diperlukan web, pertahankan dalam daftar
dipisahkan koma. Jangan menyalin `.env` laptop ke server.

```sh
npm run google:check
# Lanjut hanya bila database/schema/checksum siap dan konfigurasi diisi.
sudo systemctl restart presensi-backend
curl -fsS http://127.0.0.1:5010/ready
curl -fsS https://apipresensi.bpskotabatu.com/api/auth/google/config
```

Target: ready/database connected dan `{"enabled":true}`. SQL 003/004 tidak perlu
dijalankan ulang pada database bersama yang sudah diverifikasi. Jika server
ternyata memakai database lain/belum dimigrasi, **hentikan deployment**: jelaskan
dampak penambahan tabel identitas/challenge dan perubahan kompatibilitas password,
siapkan backup sesuai prosedur admin, lalu minta persetujuan migrasi terpisah.
Panduan ini sengaja tidak menjalankan migrasi otomatis.

## Skenario mencoba login setelah konfigurasi siap

1. Pastikan login email/password akun lama masih berhasil.
2. Login Google dengan akun yang sudah terhubung di web: profil/riwayat harus sama.
3. Email sama dengan akun password: dialog meminta password presensi. Batal atau
   password salah tidak boleh menghubungkan akun. Setelah password benar, ID,
   role dan presensi tetap sama.
4. Akun Google baru: dibuat sebagai peserta, kemudian dapat login dari web dan
   Android pada database yang sama. Jangan memakai akun produksi sebagai uji
   tanpa persetujuan pemilik.
5. Batal dari pemilih Google: kembali ke login tanpa sesi baru. Logout harus
   mencabut token presensi seperti login password.

Tes otomatis:

```powershell
flutter test
cd backend
node --test --test-concurrency=1
```

Backend menggunakan JWT RSA uji dengan verifier Google resmi dan PGlite
sementara. Flutter menggunakan ID token/sesi tiruan. Login Google nyata di HP,
konfigurasi Console, dan deployment hosting tetap memerlukan verifikasi pengguna.

Hasil pemeriksaan implementasi ini: 97 tes Flutter dan 61 tes backend lulus,
APK debug berhasil dikompilasi dengan dependency Credential Manager, dan
`google:check` lulus dengan Client ID publik pada environment proses sementara.
Tidak ada HP terhubung saat `adb devices` diperiksa; pemilih akun Google nyata
dan konfigurasi Console belum diuji. APK debug diarahkan ke hosting yang saat
pemeriksaan masih belum menyediakan endpoint Google.

Referensi resmi:
- https://developer.android.com/identity/sign-in/credential-manager-siwg-implementation
- https://developers.google.com/identity/sign-in/web/backend-auth
- https://developer.android.com/jetpack/androidx/releases/credentials
