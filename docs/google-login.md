# Login Google Presensi

Web menggunakan tombol resmi Google Identity Services. Backend Node.js
memverifikasi ID token dengan `google-auth-library`, lalu menerbitkan sesi
presensi biasa. Client Secret tidak diperlukan untuk alur ini.

Source web dan backend lokal sudah mendukung Google. API hosting baru mendukung
Google setelah kode backend, konfigurasi Client ID, dan migrasi tambahannya
diterapkan di server. Mengisi Client ID web saja tidak memperbarui hosting.

Untuk pengembangan sekarang, web dapat memakai backend lokal yang terhubung
langsung ke **PostgreSQL Android yang sama** melalui tunnel SSH. Google tidak
harus menunggu deploy API hosting untuk diuji dengan database bersama.

## Konfigurasi Google Console

1. Buka [Google Auth Platform](https://console.cloud.google.com/auth/overview).
2. Pada **Branding**, isi nama aplikasi, support email, dan developer contact.
3. Pada **Audience**, pilih **External** untuk akun Gmail pribadi. Jika aplikasi
   masih **Testing**, tambahkan akun penguji pada **Test users** bila diperlukan.
4. Pada **Clients**, pilih client bertipe **Web application**.
5. Di **Authorized JavaScript origins**, daftarkan:

   ```text
   http://localhost
   http://localhost:8000
   ```

   Origin tidak memakai path `/presensi` atau `/ready`. Buka web melalui
   `localhost`, konsisten dengan origin tersebut. Jika memakai port lain,
   daftarkan origin beserta portnya juga.
6. **Authorized redirect URIs** boleh kosong; implementasi ini memakai popup
   dan callback JavaScript.
7. Salin Client ID ke `.env` SIMASTA:

   ```dotenv
   PRESENSI_GOOGLE_CLIENT_ID=CLIENT_ID_WEB.apps.googleusercontent.com
   ```

Untuk produksi, tambahkan origin `https://presensi-simasta.bpskotabatu.com`
ketika domain dan HTTPS tersedia. Jangan mengirim Client Secret melalui chat.

## Tes Google lokal dengan PostgreSQL Android yang sama

Gunakan tiga terminal yang tetap terbuka:

**Terminal 1: tunnel PostgreSQL**

```powershell
ssh -N -o ExitOnForwardFailure=yes -L 127.0.0.1:15432:127.0.0.1:5432 USER_SSH@HOST_SERVER
```

Masukkan password SSH di terminal. Kredensial PostgreSQL dibaca dari
`presensi_bps_batu/backend/.env`; tidak disalin ke Laravel atau browser.

**Terminal 2: backend Google dengan database bersama**, dari folder SIMASTA:

```powershell
node --env-file=.env scripts/presensi-postgres.mjs
```

**Terminal 3: web**, dari folder SIMASTA:

```powershell
php artisan serve --port=8000
```

Konfigurasi `.env` SIMASTA:

```dotenv
PRESENSI_API_URL=http://127.0.0.1:5010
PRESENSI_LOCAL_TEST=false
PRESENSI_GOOGLE_CLIENT_ID=CLIENT_ID_WEB.apps.googleusercontent.com
PRESENSI_SHARED_FILES_API_URL=https://apipresensi.bpskotabatu.com
```

Buka **http://localhost:8000/presensi** dan gunakan tombol Google. Registrasi,
identitas Google, profil, sesi dan presensi disimpan langsung ke `db_magang`,
schema `presensi`. Akun baru tetap peserta. Email yang sudah terdaftar perlu
konfirmasi kata sandi presensi sebelum dikaitkan. Buat kata sandi lewat profil
web bila akun Google baru juga ingin dipakai pada login email/password Android.

Unggah, daftar dan unduh bukti melewati API hosting dengan token sesi yang sama,
sehingga byte file tetap berada pada penyimpanan Android. Tidak ada folder
bukti terpisah pada laptop untuk mode ini. Perubahan fitur lain langsung memakai
PostgreSQL bersama; tindakan pada web ini adalah perubahan data sebenarnya.

Migrasi 003 dan 004 sudah diterapkan pada database bersama saat integrasi.
Runner memeriksa riwayat/checksum dan menolak database yang belum siap. Untuk
database lain yang memang sengaja akan diperbarui, perintah migrasinya:

```powershell
node --env-file=.env scripts/presensi-postgres.mjs --migrate --check
```

Migrasi 004 memakai marker hash yang tidak bisa dipakai untuk autentikasi
password sampai pemilik membuat kata sandi, agar aman juga dengan API hosting
versi lama. Akun presensi lama tetap memakai password dan ID yang sama.

Mode ini memerlukan laptop dan tunnel aktif. Untuk deployment web produksi,
deploy backend Google ke server bersama sesuai bagian di bawah, lalu gunakan
origin API hosting kembali. Akun uji dari PGlite terpisah tidak diimpor otomatis.

## Pilihan alternatif: database uji lokal terpisah

Runner berikut memakai source backend Android yang berada di direktori sebelah,
Google sungguhan, dan database PostgreSQL PGlite khusus pengujian. Akun/data uji
**tidak masuk ke database hosting atau Android produksi**. Runner tidak membaca
`.env` backend Android dan tidak mengubah `.env` SIMASTA.

Pastikan dependensi backend sudah dipasang dengan `npm ci` dari
`D:\bps-intern-project-ub\presensi_bps_batu\backend`. Dari folder SIMASTA:

```powershell
node --env-file=.env scripts/presensi-google-local.mjs
```

Jika PHP belum ada di PATH, gunakan path PHP Herd:

```powershell
node --env-file=.env scripts/presensi-google-local.mjs "C:\Users\kaitourae\.config\herd\bin\php85\php.exe"
```

Hentikan `php artisan serve` yang memakai port 8000 dengan **Ctrl+C** terlebih
dahulu. Runner menyalakan API lokal port 5011 serta halaman Presensi port 8000.
Tidak perlu menjalankan Artisan atau Vite terpisah untuk halaman Presensi ini.

Jika ingin memakai `php artisan serve` yang sudah berjalan, gunakan mode API
saja:

```powershell
node --env-file=.env scripts/presensi-google-local.mjs --api-only
```

Pada mode ini, isi `.env` SIMASTA dengan `PRESENSI_API_URL=http://127.0.0.1:5011`
dan `PRESENSI_LOCAL_TEST=true`, jalankan `php artisan config:clear`, lalu buka
**http://localhost:8000/presensi**. Saat kembali memakai hosting, pulihkan URL
API hosting dan `PRESENSI_LOCAL_TEST=false`. Mode runner penuh di atas tidak
memerlukan perubahan kedua nilai ini di `.env`.

1. Buka **http://localhost:8000**.
2. Klik **Lanjutkan dengan Google**, lalu pilih akun penguji.
3. Login pertama membuat akun **peserta**. Login berikutnya memakai akun itu.
4. Pada profil, **Buat kata sandi** memungkinkan akun baru dipakai melalui login
   email/password Android jika Android diarahkan ke backend yang sama.
5. Untuk menguji pengaitan akun lama, daftar dulu memakai email/password dengan
   email Google yang sama, keluar, lalu masuk dengan Google. Web meminta kata
   sandi presensi sebelum menghubungkan akun. Peran dan data akun tetap sama.

**Ctrl+C** menghentikan kedua server. Akun uji bertahan pada
`storage/app/private/presensi-google-local/database`; bukti tersimpan di folder
`uploads` di direktori yang sama. Folder ini diabaikan Git. SIMASTA biasa dapat
dijalankan kembali memakai `php artisan serve` setelah runner dihentikan.

## Memakai PostgreSQL yang sama dengan Android

Untuk sinkronisasi dengan Android produksi, web dan Android harus mengakses
backend yang memakai PostgreSQL yang sama. Jangan menggunakan runner database
terpisah di atas sebagai pengganti backend produksi.

Backend bersama memerlukan:

```dotenv
GOOGLE_CLIENT_IDS=CLIENT_ID_WEB.apps.googleusercontent.com
```

Sebelum menjalankan source backend yang baru, tinjau dan terapkan migrasi
`backend/migrations/003_google_identity.sql` dan
`004_google_password_compatibility.sql` melalui mekanisme migrasi backend
(`npm run db:migrate`) pada database yang memang dipilih. Migrasi menambahkan
pemetaan identitas Google, nonce sekali pakai, dan marker hash akun yang belum
membuat kata sandi. Migrasi awal tidak diubah. Database bersama sudah dimigrasi
saat integrasi melalui tunnel; proses API hosting tetap perlu di-deploy/restart
dengan kode Google sebelum endpoint Google tersedia pada origin hosting.

Untuk backend lokal yang terhubung ke PostgreSQL bersama, arahkan `.env` SIMASTA
ke API lokal yang aktif, misalnya:

```dotenv
PRESENSI_API_URL=http://127.0.0.1:5010
PRESENSI_GOOGLE_CLIENT_ID=CLIENT_ID_WEB.apps.googleusercontent.com
```

Jalankan `php artisan config:clear` setelah mengganti konfigurasi. Untuk hosting,
kembalikan `PRESENSI_API_URL=https://apipresensi.bpskotabatu.com` setelah backend
hosting siap. Tidak perlu menyalin kredensial PostgreSQL ke Laravel.

## Jika gagal

- **origin_mismatch / origin tidak diizinkan**: cocokkan skema, hostname dan port
  browser dengan Authorized JavaScript origins. Tunggu propagasi perubahan.
  Saat `APP_ENV=local` dan Client ID sudah diisi, halaman Presensi otomatis
  mengalihkan `127.0.0.1` ke `localhost` pada port yang sama. Di Console, simpan
  origin `http://localhost` dan `http://localhost:8000`, lalu tutup popup lama dan
  ulangi login dari halaman yang baru. Backend tetap dapat memakai
  `PRESENSI_API_URL=http://127.0.0.1:5010`.
- **access_denied**: periksa akun penguji dan konfigurasi Audience.
- **Login Google belum tersedia pada layanan presensi**: web masih menuju API
  hosting yang belum diperbarui. Gunakan runner lokal untuk tes terpisah.
- **Sesi Google berakhir**: klik **Coba muat Google lagi** dan ulangi login.
- **Email sudah memiliki akun presensi**: masukkan kata sandi presensi lama
  melalui dialog pengaitan, bukan kata sandi Google.

Verifikasi token memeriksa signature, issuer, audience, expiry, email terverifikasi
dan nonce yang terikat sesi. Pengaitan akun memakai Google `sub` yang stabil;
email yang sama tidak cukup untuk mengambil alih akun lama atau hak admin.
Token sesi API tetap disimpan terenkripsi di server Laravel.

## Referensi resmi

- [Setup Google Identity Services](https://developers.google.com/identity/gsi/web/guides/get-google-api-clientid)
- [Verifikasi ID token di backend](https://developers.google.com/identity/gsi/web/guides/verify-google-id-token)
- [Referensi JavaScript Google Identity Services](https://developers.google.com/identity/gsi/web/reference/js-reference)
