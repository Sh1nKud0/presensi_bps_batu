# Presensi Magang

Logo sementara aplikasi menggunakan pin lokasi biru dan centang hijau mint.
Nama aplikasi adalah **Presensi Magang BPS Kota Batu**, digunakan pada ikon
launcher, splash screen, login, beranda, dan informasi aplikasi.

Konsep pin/centang mengacu pada simbol presensi dan lokasi, dengan referensi
[Map Pin Check Inside dari Lucide](https://lucide.dev/icons/map-pin-check-inside).
Geometri logo ini digambar tersendiri dalam `lib/widgets/app_logo.dart`;
tidak menggunakan file ikon pihak ketiga.

- `logo_presensi.svg`: sumber vektor untuk penggunaan di luar aplikasi.
- `logo_presensi.png`: logo dengan latar transparan, 512 × 512.
- `app_icon.png`: ikon aplikasi dengan latar solid, 1024 × 1024.
- `logo_bps.png`: aset instansi yang tetap dipakai pada beranda.

Untuk mengekspor ulang seluruh ukuran ikon Android/iOS dan splash native:

```sh
flutter test tool/generate_brand_assets.dart
```

Renderer Flutter menjadi sumber aset PNG agar logo di UI dan ikon native
konsisten. Saat mengubah bentuk logo, sesuaikan juga sumber SVG.
Launcher Android menyediakan adaptive icon dengan ruang aman untuk mask.
Intro Flutter berlangsung 2,2 detik bersamaan dengan pemulihan sesi;
pengaturan pengurangan animasi melewati durasi intro.
