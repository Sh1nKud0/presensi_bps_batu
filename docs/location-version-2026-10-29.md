# Perbaikan pemuatan versi lokasi

Server sudah menerima akurasi 150 meter, tetapi app.js dan location.js sebelumnya mengimpor domain.js tanpa versi. Browser atau cache perantara dapat tetap menyajikan modul konfigurasi 50 meter. Kedua modul sekarang memakai domain.js dengan versi yang sama, dan app.js memakai location.js dengan versi yang sama. Halaman Blade sudah memberi versi filemtime pada app.js.

Verifikasi: 14 tes lokasi/domain lulus. Uji browser Edge memuat domain.js tanpa versi dengan nilai 50 dan membuktikan modul lokasi berversi memakai 150: akurasi 136 dan 150 diterima, 150.01 ditolak. Tidak ada presensi nyata dibuat selama pengujian.

Paket hanya memperbarui tiga aset JavaScript web. Tidak ada perubahan API, database, .env, CSS, atau restart layanan. Script memeriksa versi file server sebelum menulis dan mencadangkan ketiganya. Jika isi server berbeda dari versi yang diperiksa, script berhenti tanpa menulis.

PowerShell laptop dari folder Simasta:

```powershell
scp storage/app/private/deploy/presensi-location-version-2026-10-29.tar.gz USER_SSH@HOST_SERVER:~/
ssh USER_SSH@HOST_SERVER
```

SSH:

```bash
mkdir -p ~/presensi-location-version-2026-10-29
tar -xzf ~/presensi-location-version-2026-10-29.tar.gz -C ~/presensi-location-version-2026-10-29
sudo bash ~/presensi-location-version-2026-10-29/deploy.sh
```

Sesudah berhasil, muat ulang halaman presensi dan lakukan Cek lokasi lagi. File tanpa query masih dapat tampil lama dari cache; versi yang dipakai aplikasi adalah domain.js?v=20261029-gps150-r2. Verifikasi melalui Network pada halaman aplikasi, bukan hanya membuka alamat domain.js tanpa versi.
