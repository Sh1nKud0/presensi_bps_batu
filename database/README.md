# Arsip skema Supabase

Folder ini menyimpan migrasi lama sebagai referensi historis. Aplikasi sekarang
hanya menggunakan backend PostgreSQL BPS dan tidak menjalankan skrip di folder ini.
`schema_presensi_bps_batu.sql` di root project juga merupakan skema Supabase lama.

Skema aktif tersedia di [backend/migrations](../backend/migrations), dengan panduan
[backend/README.md](../backend/README.md). Gunakan `npm run db:migrate` untuk migrasi
backend. Database BPS yang sudah dipakai tidak perlu dibuat ulang.

Aturan pembatalan jam pulang sekarang diterapkan oleh backend dalam transaksi:
pengajuan pada tanggal yang sama, jam pulang tercatat sebelum 16.00 WIB,
persetujuan admin mengosongkan data pulang dan mempertahankan jam masuk.
Pengujian ada di `backend/test/extensions.integration.test.js` dan
`test/checkout_cancellation_test.dart`.
