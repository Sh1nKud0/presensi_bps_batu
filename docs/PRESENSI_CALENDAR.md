# Kalender presensi Indonesia

Sinkronisasi otomatis: scripts/sync-national-holidays.mjs, dijalankan setiap jam melalui crontab akun bps. Runtime Node 22+ dan koneksi PostgreSQL memakai konfigurasi backend Presensi yang sudah ada; tidak menyimpan token login.

Sumber: https://github.com/ahrulsyamil/indonesian-holidays (data tahunan berdasarkan SKB 3 Menteri). Setiap sinkronisasi mengambil versi terbaru untuk tahun berjalan dan tahun berikutnya jika tersedia. Pembaruan mengikuti publikasi pengelola sumber; bukan API resmi pemerintah.

Tanggal nasional dan cuti bersama masuk ke tabel presensi.hari_libur dengan awalan [Kalender Indonesia]. Android dan web memakai tabel yang sama. Hari libur manual tidak ditimpa. Feed kosong/tidak lengkap ditolak; kegagalan jaringan mempertahankan data terakhir. Penghapusan massal ditolak dan dicatat di log.

Metadata pemeriksaan terakhir ada di public/presensi-assets/calendar-status.json. File ini dibuat di server, tidak perlu dimasukkan Git. Backup awal tabel disimpan di direktori backup privat deployment. Log sinkronisasi: /home/bps/apps/presensi-web-service/calendar-sync.log.

Jalankan manual di server dari root web:

node scripts/sync-national-holidays.mjs

Untuk database pengembangan, set PRESENSI_BACKEND_ROOT ke folder backend dengan .env yang sesuai. Jangan menjalankan terhadap produksi saat pengujian. Pengujian database terisolasi: node --test tests/presensi-calendar.test.mjs (memerlukan dependency @electric-sql/pglite dari backend).
