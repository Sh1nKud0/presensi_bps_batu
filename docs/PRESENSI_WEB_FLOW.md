# Alur peserta web

Navigasi peserta mengikuti referensi Android: Beranda, Presensi, Riwayat, Profil. Desktop memakai sidebar; browser HP memakai navigasi bawah. Halaman Pengajuan, riwayat keputusan, dan bukti tetap dapat dibuka melalui Profil. Profil admin tetap terpisah.

## Presensi

Tombol Beranda hanya membuka halaman Presensi. Saat halaman dibuka, browser meminta lokasi dan menampilkan peta Leaflet 1.9.4 dengan OpenStreetMap, radius kantor, titik perangkat, serta akurasi sebenarnya. Tombol Kirim aktif setelah lokasi segar memenuhi radius dan akurasi pada domain.js serta backend mengizinkan tindakan. Pembukaan peta, pembacaan GPS, dan tombol Perbarui tidak mengirim catatan presensi. POST dilakukan saat pengguna menekan Kirim, dengan pembacaan GPS baru; backend tetap memvalidasi.

Lokasi dibatalkan saat pindah halaman. Penolakan izin membersihkan pembacaan sebelumnya. Peta dibersihkan saat keluar halaman; pembaruan status tidak membuat ulang peta. Lokasi diperbarui selama halaman aktif agar tidak kedaluwarsa. Tidak ada koordinat yang diganti atau akurasi yang direkayasa.

## Profil dan kalender

Profil menampilkan statistik API /me/statistics: Hadir adalah jumlah hari yang memiliki jam masuk, Izin/Sakit adalah jumlah pengajuan disetujui (bukan jumlah hari). Edit profil dan kata sandi memakai endpoint serta validasi yang sudah ada. Mode gelap disimpan lokal pada browser, tanpa mengubah pengaturan Android.

Riwayat bulanan menggunakan data presensi, izin disetujui, dan hari libur PostgreSQL yang sama. Status kosong tidak otomatis menjadi alpha. Detail tanggal tersedia melalui dialog.

## Validasi

Tes domain dan GPS: node --test tests/presensi-attendance-state.test.mjs tests/presensi-attendance-calendar.test.mjs tests/presensi-location.test.mjs

Uji browser dengan fixture terisolasi: node tests/browser/presensi-flow.cjs. Memerlukan playwright/playwright-core; jika ada di lokasi lain, set PRESENSI_PLAYWRIGHT_MODULE ke modul tersebut. Fixture tidak terhubung ke database atau API produksi. Peta dasar memakai gambar fixture, sedangkan marker dan radius menggunakan Leaflet asli.
