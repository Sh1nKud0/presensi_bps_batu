# Pembatalan absen pulang

Jalankan isi `20261007_pembatalan_pulang.sql` sekali di **Supabase → SQL Editor**
pada database aplikasi yang sudah memiliki skema presensi sebelumnya.
Skrip berada dalam transaksi; jangan menjalankan ulang skema awal proyek.

Aturan:
- Hanya pemilik presensi yang bisa mengajukan pembatalan dengan alasan.
- Jam pulang harus tercatat sebelum 16.00 WIB, untuk tanggal hari ini.
- Izin/susulan aktif tidak dapat dibatalkan melalui alur ini.
- Hanya satu pengajuan menunggu per presensi. Penolakan tidak mengubah presensi.
- Admin harus menyetujui pada hari yang sama; pengajuan kedaluwarsa dapat ditolak.
- Persetujuan mengunci baris, memeriksa jam pulang asli, mengosongkan jam/lokasi/foto
  pulang, dan menyimpan keputusan dalam satu transaksi. Jam masuk tetap tersimpan.
- User tidak dapat mengubah jam pulang yang sudah tercatat lewat update API langsung.

Pemeriksaan setelah migrasi, dengan akun peserta dan admin yang berbeda:
1. Presensi peserta dengan jam pulang sebelum 16.00 WIB: ajukan pembatalan.
2. Pastikan pengajuan kedua ditolak dan peserta lain tidak dapat membaca pengajuannya.
3. Tolak pengajuan di admin: jam pulang tetap tersimpan dan hasil muncul di notifikasi peserta.
4. Ajukan kembali, setujui: jam masuk tetap, jam pulang kosong, peserta bisa absen pulang kembali.
5. Pastikan proses ulang keputusan ditolak dan jam pulang pukul 16.00 WIB ke atas tidak memenuhi syarat.

Pengujian Dart memakai server tiruan untuk batas waktu dan pemanggilan RPC;
pengujian tersebut tidak mengeksekusi fungsi PostgreSQL pada Supabase.
