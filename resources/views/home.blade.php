<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>SIMASTA - Sistem Informasi Magang Statistik Kota Batu</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
html{scroll-behavior:smooth}
:root{
  --neon:#34D399;--neon-dark:#10B981;--neon-soft:#A7F3D0;
  --orange:#FB923C;--orange-dark:#F97316;--orange-soft:#FED7AA;
  --blue:#60A5FA;--blue-dark:#3B82F6;--blue-soft:#BFDBFE;
  --navy:#1E293B;--navy-soft:#334155;--footer-bg:#1E3A5F;
}
body{
  font-family:Arial,sans-serif;color:#1f2937;
  background:
    radial-gradient(circle at 12% 15%,rgba(52,211,153,.18),transparent 35%),
    radial-gradient(circle at 88% 20%,rgba(96,165,250,.20),transparent 38%),
    radial-gradient(circle at 55% 75%,rgba(251,146,60,.14),transparent 35%),
    linear-gradient(135deg,#e7fff7 0%,#f5fbff 45%,#fffaf5 70%,#eaf3ff 100%);
  background-attachment:fixed;background-size:cover;
}
a:focus-visible,button:focus-visible{outline:3px solid var(--blue-dark);outline-offset:3px}

/* NAVBAR */
.navbar{position:fixed;top:0;left:0;width:100%;z-index:1000;padding:18px 7%;display:flex;align-items:center;justify-content:space-between;transition:background .3s,padding .3s,box-shadow .3s}
.navbar.scrolled{background:rgba(255,255,255,.96);backdrop-filter:blur(8px);box-shadow:0 4px 15px rgba(0,0,0,.08);padding-top:12px;padding-bottom:12px}
.logo{display:flex;align-items:center;gap:10px;text-decoration:none}
.logo img{width:55px;height:45px;object-fit:contain}
.logo-text{font-size:22px;font-weight:bold;color:var(--navy);line-height:1.1}
.logo-sub{font-size:10px;letter-spacing:1px;color:#64748b}
.nav-menu{display:flex;align-items:center;gap:30px;list-style:none}
.nav-menu a{color:var(--navy-soft);text-decoration:none;font-size:14px;font-weight:600;transition:.2s}
.nav-menu a:hover{color:var(--neon-dark)}
.nav-menu a.active{color:var(--blue-dark);font-weight:700}
.menu-toggle{display:none;width:40px;height:40px;border:none;border-radius:10px;background:white;align-items:center;justify-content:center;cursor:pointer;box-shadow:0 4px 12px rgba(0,0,0,.08)}
.menu-toggle span,.menu-toggle span::before,.menu-toggle span::after{content:"";display:block;width:18px;height:2px;background:var(--navy);position:relative;transition:.2s}
.menu-toggle span::before{top:-6px}.menu-toggle span::after{top:4px}

/* HERO */
.hero{min-height:100vh;display:flex;align-items:center;justify-content:flex-start;text-align:left;padding:130px 7% 80px;position:relative;overflow:hidden;
  background:
    radial-gradient(circle at 12% 15%,rgba(52,211,153,.30),transparent 45%),
    radial-gradient(circle at 88% 20%,rgba(96,165,250,.32),transparent 50%),
    radial-gradient(circle at 55% 100%,rgba(251,146,60,.28),transparent 45%),#F8FAFC}
.hero::before{content:"";position:absolute;width:560px;height:560px;border-radius:50%;background:rgba(96,165,250,.10);right:-160px;top:-120px}
.hero-content{position:relative;z-index:2;max-width:680px}
.hero-badge{display:inline-flex;align-items:center;gap:8px;background:white;border:1px solid var(--neon-soft);color:var(--neon-dark);padding:8px 16px;border-radius:30px;font-size:11px;font-weight:700;letter-spacing:.8px;margin-bottom:22px;box-shadow:0 4px 12px rgba(16,185,129,.12)}
.hero-badge::before{content:"";flex:none;width:6px;height:6px;border-radius:50%;background:var(--neon)}
.hero h1{color:var(--navy);font-size:46px;line-height:1.15;margin-bottom:20px}
.hero h1 span{background:linear-gradient(120deg,var(--neon-dark),var(--blue-dark),var(--orange-dark));-webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.hero p{color:#475569;font-size:17px;line-height:1.7;margin:0 0 32px;max-width:600px}
.hero-buttons{display:flex;gap:15px;flex-wrap:wrap;justify-content:flex-start}
.btn-primary{display:inline-block;background:linear-gradient(120deg,var(--orange),var(--orange-dark));color:white;padding:14px 26px;border-radius:30px;text-decoration:none;font-weight:bold;box-shadow:0 10px 25px rgba(255,122,51,.25);transition:.2s}
.btn-primary:hover{transform:translateY(-2px);box-shadow:0 14px 30px rgba(255,122,51,.32)}

/* SECTION */
.section{padding:80px 7%;scroll-margin-top:90px}
.section-title{text-align:center;margin-bottom:50px}
.section-title p.eyebrow{color:var(--blue);font-size:12px;font-weight:700;letter-spacing:1.5px;margin-bottom:10px}
.section-title h2{font-size:30px;color:var(--navy-soft);margin-bottom:12px}
.section-title p{color:#64748b;max-width:650px;margin:auto;line-height:1.6}

/* KEUNGGULAN */
.feature-grid{display:grid;grid-template-columns:repeat(3,1fr);gap:25px}
.feature-card{padding:35px 25px;background:#f8fafc;border:1px solid #e5e7eb;border-top:3px solid var(--card-accent,var(--blue));border-radius:12px;text-align:center;transition:.3s}
.feature-card:hover{transform:translateY(-5px);box-shadow:0 10px 25px rgba(0,0,0,.08)}
.feature-card.neon{--card-accent:var(--neon)}.feature-card.blue{--card-accent:var(--blue)}.feature-card.orange{--card-accent:var(--orange)}
.feature-icon{width:55px;height:55px;margin:auto auto 20px;display:flex;align-items:center;justify-content:center;border-radius:12px;background:color-mix(in srgb,var(--card-accent,var(--blue)) 15%,white);color:var(--card-accent,var(--blue));font-size:22px;font-weight:bold}
.feature-card h3{margin-bottom:12px;color:var(--navy-soft)}
.feature-card p{color:#64748b;line-height:1.6;font-size:14px}

/* ALUR (STEPPER) */
.alur-grid{display:grid;grid-template-columns:repeat(7,1fr);gap:10px;text-align:center;position:relative;max-width:1100px;margin:auto}
.alur-grid::before{content:"";position:absolute;top:30px;left:calc(100% / 14);right:calc(100% / 14);height:2px;background:linear-gradient(90deg,var(--neon-dark),var(--blue),var(--orange));opacity:.35}
.alur-item{position:relative;cursor:pointer;padding:0 4px;outline:none}
.alur-icon{width:60px;height:60px;margin:0 auto 16px;border-radius:50%;background:white;border:2px solid #e2e8f0;color:var(--step-color);display:flex;align-items:center;justify-content:center;position:relative;z-index:2;box-shadow:0 6px 16px rgba(30,41,59,.08);transition:.25s}
.alur-icon svg{width:24px;height:24px}
.alur-item:nth-child(1),.alur-item:nth-child(2){--step-color:var(--neon-dark)}
.alur-item:nth-child(3),.alur-item:nth-child(4),.alur-item:nth-child(5){--step-color:var(--blue-dark)}
.alur-item:nth-child(6),.alur-item:nth-child(7){--step-color:var(--orange-dark)}
.alur-item:hover .alur-icon,.alur-item:focus-visible .alur-icon{border-color:var(--step-color);transform:translateY(-3px)}
.alur-item.is-active .alur-icon{background:var(--step-color);border-color:var(--step-color);color:white;box-shadow:0 0 0 6px color-mix(in srgb,var(--step-color) 20%,transparent),0 10px 22px color-mix(in srgb,var(--step-color) 40%,transparent)}
.alur-item h4{color:var(--navy);margin-bottom:6px;font-size:15px}
.alur-item p{font-size:12px;color:#64748b;line-height:1.5}

/* TENTANG */
.about{display:grid;grid-template-columns:1fr 1fr;gap:60px;align-items:center}
.about h2{font-size:32px;color:var(--navy-soft);margin-bottom:20px}
.about p{color:#64748b;line-height:1.8;margin-bottom:15px}
.about-box{background:linear-gradient(160deg,#eafff5,#eff6ff);padding:40px;border-radius:15px;border:1px solid #dbeafe}
.about-box h3{color:var(--blue);margin-bottom:15px}

/* CTA */
.cta{margin:0 7% 80px;padding:60px 40px;border-radius:18px;text-align:center;position:relative;overflow:hidden;
  background:radial-gradient(circle at 20% 20%,rgba(52,211,153,.35),transparent 50%),radial-gradient(circle at 80% 80%,rgba(251,146,60,.30),transparent 50%),linear-gradient(120deg,var(--blue-soft),#EFF6FF)}
.cta h2{color:var(--navy);font-size:30px;margin-bottom:15px;position:relative}
.cta p{color:var(--navy-soft);margin-bottom:25px;position:relative}
.cta .btn-primary{position:relative}

/* FOOTER */
footer{background:var(--footer-bg);color:white;padding:60px 7% 25px;scroll-margin-top:0}
.footer-grid{display:grid;grid-template-columns:1.4fr 1.4fr 1fr;gap:50px;margin-bottom:40px}
.footer-brand{display:flex;align-items:center;gap:12px;margin-bottom:16px}
.footer-logo{display:flex;align-items:center}
.footer-logo img{width:46px;height:38px;object-fit:contain;display:block}
.footer-brand b{display:block;font-size:20px;line-height:1.1}
.footer-brand small{font-size:10px;letter-spacing:1px;color:#93c5fd}
footer h3{margin-bottom:18px;font-size:16px}
footer p{color:#cbd5e1;line-height:1.7;font-size:14px}
.contact-list{list-style:none}
.contact-list li{display:flex;gap:12px;margin-bottom:14px;color:#cbd5e1;font-size:14px;line-height:1.55}
.contact-list svg{width:18px;height:18px;flex:none;margin-top:2px;color:var(--neon)}
footer a{color:#cbd5e1;text-decoration:none;transition:.2s}
footer a:hover{color:var(--neon)}
.social-row{display:flex;flex-wrap:wrap;gap:10px}
.social-row a{width:42px;height:42px;border-radius:12px;background:rgba(255,255,255,.1);display:flex;align-items:center;justify-content:center;color:#fff;transition:.2s}
.social-row a:hover{background:var(--neon-dark);color:#fff;transform:translateY(-3px)}
.social-row svg{width:20px;height:20px}
.social-note{margin-top:14px;font-size:13px}
.footer-bottom{border-top:1px solid rgba(255,255,255,.12);padding-top:20px;display:flex;justify-content:space-between;flex-wrap:wrap;gap:10px;color:#94a3b8;font-size:13px}
.footer-bottom a{color:#94a3b8}

/* RESPONSIVE */
@media(max-width:900px){
  .menu-toggle{display:flex}
  .nav-menu{display:none;position:absolute;top:78px;right:5%;width:220px;padding:15px;background:white;border-radius:14px;box-shadow:0 12px 35px rgba(0,0,0,.12);flex-direction:column;align-items:stretch;gap:8px}
  .nav-menu.active{display:flex}
  .nav-menu li{width:100%}
  .nav-menu a{display:block;width:100%;padding:12px 14px;border-radius:8px}
  .nav-menu a:hover{background:#f1f5f9}
  .hero{min-height:auto;padding:120px 7% 70px}
  .hero h1{font-size:36px}
  .feature-grid{grid-template-columns:1fr}
  /* alur jadi vertikal */
  .alur-grid{grid-template-columns:1fr;gap:26px;text-align:left;max-width:420px}
  .alur-grid::before{top:30px;bottom:30px;left:30px;right:auto;width:2px;height:auto}
  .alur-item{display:grid;grid-template-columns:60px 1fr;column-gap:18px;align-items:center}
  .alur-icon{margin:0;grid-row:1 / span 2}
  .alur-item h4{margin:0 0 4px;align-self:end}
  .alur-item p{align-self:start}
  .about{grid-template-columns:1fr}
  .footer-grid{grid-template-columns:1fr}
}
@media(max-width:600px){
  .hero h1{font-size:30px}
  .hero-buttons .btn-primary{width:100%;text-align:center}
  .section{padding:60px 5%}
  .cta{margin-left:5%;margin-right:5%;padding:45px 24px}
  .footer-bottom{flex-direction:column;text-align:center}
}
@media(prefers-reduced-motion:reduce){*{transition:none!important;scroll-behavior:auto!important}}
</style>
</head>
<body>

<!-- NAVBAR -->
<nav class="navbar" id="navbar">
  <a href="/" class="logo">
    <img src="{{ asset('images/logo-bps.png') }}" alt="Logo BPS">
    <span>
      <span class="logo-text" style="display:block;">SIMASTA</span>
      <span class="logo-sub">BADAN PUSAT STATISTIK KOTA BATU</span>
    </span>
  </a>
  <ul class="nav-menu" id="navMenu">
    <li><a href="#beranda">Beranda</a></li>
    <li><a href="#tentang">Tentang</a></li>
    <li><a href="#alur">Alur Magang</a></li>
    <li><a href="#kontak">Hubungi kami</a></li>
  </ul>
  <button class="menu-toggle" id="menuToggle" aria-label="Buka menu" aria-expanded="false"><span></span></button>
</nav>

<!-- 1. HERO / BERANDA -->
<section class="hero" id="beranda">
  <div class="hero-content">
    <span class="hero-badge">SISTEM INFORMASI MAGANG RESMI BADAN PUSAT STATISTIK KOTA BATU</span>
    <h1>Magang Statistik yang Terarah, <span>Diakui BPS Kota Batu</span></h1>
    <p>SIMASTA membantu mahasiswa dari berbagai kampus dan universitas mengikuti program magang di BPS Kota Batu secara digital — mulai dari pendaftaran, penempatan bidang, logbook harian, hingga penilaian dan sertifikat resmi, semuanya terpantau dalam satu sistem.</p>
    <div class="hero-buttons">
      <a href="/login" class="btn-primary">Masuk ke Aplikasi →</a>
    </div>
  </div>

</section>

<!-- 2. TENTANG -->
<section class="section" id="tentang">
  <div class="about">
    <div>
      <h2>Tentang SIMASTA</h2>
      <p>SIMASTA (Sistem Magang Statistik Kota Batu) adalah platform resmi Badan Pusat Statistik Kota Batu untuk mengelola seluruh proses magang secara digital, mulai dari pendaftaran hingga penerbitan sertifikat.</p>
      <p>Sistem ini menghubungkan mahasiswa dari berbagai kampus, admin, dan pembimbing lapangan dalam satu platform, sehingga proses yang dulunya manual lewat surat dan WhatsApp kini lebih cepat, terstruktur, dan terdokumentasi rapi.</p>
    </div>
    <div class="about-box">
      <h3>Tujuan SIMASTA</h3>
      <p>Meningkatkan efektivitas pengelolaan kegiatan magang melalui sistem yang terintegrasi, mudah digunakan, dan terorganisir.</p>
    </div>
  </div>
</section>

<!-- KEUNGGULAN -->
<section class="section" id="informasi">
  <div class="section-title">
    <p class="eyebrow">KEUNGGULAN</p>
    <h2>Kemudahan dalam Pengelolaan Magang</h2>
    <p>SIMASTA membantu mengintegrasikan berbagai proses administrasi dan kegiatan magang dalam satu sistem.</p>
  </div>
  <div class="feature-grid">
    <div class="feature-card neon">
      <div class="feature-icon">01</div>
      <h3>Pengajuan Terintegrasi</h3>
      <p>Mahasiswa dapat melakukan pengajuan kegiatan magang melalui sistem secara terstruktur dan mudah.</p>
    </div>
    <div class="feature-card blue">
      <div class="feature-icon">02</div>
      <h3>Monitoring Magang</h3>
      <p>Proses pelaksanaan magang dapat dipantau melalui penempatan, logbook, hingga penilaian.</p>
    </div>
    <div class="feature-card orange">
      <div class="feature-icon">03</div>
      <h3>Dokumen Terpusat</h3>
      <p>Pengelolaan dokumen magang menjadi lebih terorganisir dan mudah diakses oleh pengguna.</p>
    </div>
  </div>
</section>

<!-- 3. ALUR MAGANG -->
<section class="section alur" id="alur">
  <div class="section-title">
    <p class="eyebrow">ALUR</p>
    <h2>Alur Magang SIMASTA</h2>
    <p>Ikuti langkah mudah berikut untuk mengikuti magang di BPS Kota Batu.</p>
  </div>
  <div class="alur-grid" id="alurGrid">
    <div class="alur-item is-active" tabindex="0">
      <div class="alur-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M19 8v6M22 11h-6"/></svg></div>
      <h4>Registrasi</h4><p>Membuat akun mahasiswa</p>
    </div>
    <div class="alur-item" tabindex="0">
      <div class="alur-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><path d="M14 2v6h6M12 18v-6M9 15l3-3 3 3"/></svg></div>
      <h4>Pengajuan</h4><p>Mengajukan kegiatan magang</p>
    </div>
    <div class="alur-item" tabindex="0">
      <div class="alur-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 11l3 3L22 4"/><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"/></svg></div>
      <h4>Verifikasi</h4><p>Pemeriksaan pengajuan</p>
    </div>
    <div class="alur-item" tabindex="0">
      <div class="alur-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg></div>
      <h4>Penempatan</h4><p>Penentuan tempat magang</p>
    </div>
    <div class="alur-item" tabindex="0">
      <div class="alur-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="7" width="20" height="14" rx="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/></svg></div>
      <h4>Pelaksanaan</h4><p>Melaksanakan kegiatan magang</p>
    </div>
    <div class="alur-item" tabindex="0">
      <div class="alur-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 19.500A2.500 2.500 0 0 1 6.500 17H20"/><path d="M6.500 2H20v20H6.500A2.500 2.500 0 0 1 4 19.500v-15A2.500 2.500 0 0 1 6.500 2z"/></svg></div>
      <h4>Logbook</h4><p>Mencatat kegiatan magang</p>
    </div>
    <div class="alur-item" tabindex="0">
      <div class="alur-icon"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="6"/><path d="M15.500 13.500 17 22l-5-3-5 3 1.500-8.500"/></svg></div>
      <h4>Penilaian</h4><p>Penilaian hasil magang</p>
    </div>
  </div>
</section>

<!-- CTA -->
<section class="cta">
  <h2>Siap Jadi Bagian dari BPS Kota Batu?</h2>
  <p>Masuk ke SIMASTA untuk mendaftar dan mengelola kegiatan magang kamu.</p>
  <a href="/login" class="btn-primary">Masuk ke SIMASTA →</a>
</section>

<!-- FOOTER + HUBUNGI KAMI -->
<footer id="kontak">
  <div class="footer-grid">
    <div>
      <div class="footer-brand">
        <span class="footer-logo"><img src="{{ asset('images/logo-bps.png') }}" alt="Logo BPS"></span>
        <span><b>SIMASTA</b><small>BPS KOTA BATU</small></span>
      </div>
      <p>Sistem Magang Statistik Kota Batu — platform resmi Badan Pusat Statistik Kota Batu untuk mahasiswa dari berbagai kampus dan universitas.</p>
    </div>

    <div>
      <h3>Kontak Kami</h3>
      <ul class="contact-list">
        <li>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0 1 18 0z"/><circle cx="12" cy="10" r="3"/></svg>
          <span>Jl. Melati, Songgokerto, Kec. Batu, Kota Batu, Jawa Timur, Indonesia</span>
        </li>
        <li>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.920v3a2 2 0 0 1-2.180 2 19.790 19.790 0 0 1-8.630-3.070 19.500 19.500 0 0 1-6-6A19.790 19.790 0 0 1 2.120 4.180 2 2 0 0 1 4.110 2h3a2 2 0 0 1 2 1.720c.130.960.360 1.900.700 2.810a2 2 0 0 1-.450 2.110L8.090 9.910a16 16 0 0 0 6 6l1.270-1.270a2 2 0 0 1 2.110-.450c.910.340 1.850.570 2.810.700A2 2 0 0 1 22 16.920z"/></svg>
          <a href="https://wa.me/6282190003579" target="_blank" rel="noopener">+62 821-9000-3579</a>
        </li>
        <li>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/></svg>
          <a href="mailto:bps3579@bps.go.id">bps3579@bps.go.id</a>
        </li>
        <li>
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.300 15.300 0 0 1 4 10 15.300 15.300 0 0 1-4 10 15.300 15.300 0 0 1-4-10 15.300 15.300 0 0 1 4-10z"/></svg>
          <a href="https://batukota.bps.go.id/id" target="_blank" rel="noopener">batukota.bps.go.id</a>
        </li>
      </ul>
    </div>

    <div>
      <h3>Sosial Media</h3>
      <div class="social-row">
        <a href="https://www.instagram.com/bpskotabatu" target="_blank" rel="noopener" aria-label="Instagram BPS Kota Batu" title="Instagram"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="5"/><circle cx="12" cy="12" r="4"/><circle cx="17.500" cy="6.500" r="1" fill="currentColor"/></svg></a>
        <a href="https://wa.me/6282190003579" target="_blank" rel="noopener" aria-label="WhatsApp BPS Kota Batu" title="WhatsApp"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a9 9 0 0 1-13.400 7.800L3 21l1.300-4.500A9 9 0 1 1 21 12z"/><path d="M9 9c0 3 3 6 6 6l1.500-1.500-2-1-1 .8c-.8-.4-1.700-1.300-2.100-2.100l.8-1-1-2z"/></svg></a>
        <a href="https://www.linkedin.com/company/badan-pusat-statistik-kota-batu/" target="_blank" rel="noopener" aria-label="LinkedIn BPS Kota Batu" title="LinkedIn"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M4.980 3.500a2.500 2.500 0 1 1 0 5 2.500 2.500 0 0 1 0-5zM3 9.500h4V21H3zM9.500 9.500h3.800v1.600h.1c.5-1 1.800-2 3.800-2 4 0 4.800 2.600 4.800 6V21h-4v-5c0-1.300 0-3-1.800-3s-2.100 1.400-2.100 2.900V21h-4z"/></svg></a>
        <a href="https://www.youtube.com/channel/UC_pcLwhiv5VU5y7WNVIA1pQ" target="_blank" rel="noopener" aria-label="YouTube BPS Kota Batu" title="YouTube"><svg viewBox="0 0 24 24" fill="currentColor"><path d="M22.500 6.800a2.800 2.800 0 0 0-2-2C18.800 4.300 12 4.300 12 4.300s-6.800 0-8.500.5a2.800 2.800 0 0 0-2 2C1 8.500 1 12 1 12s0 3.500.5 5.200a2.800 2.800 0 0 0 2 2c1.700.5 8.500.5 8.500.5s6.800 0 8.500-.5a2.800 2.800 0 0 0 2-2c.5-1.700.5-5.200.5-5.200s0-3.500-.5-5.200zM9.800 15.100V8.900l5.700 3.100-5.700 3.100z"/></svg></a>
        <a href="https://batukota.bps.go.id/id" target="_blank" rel="noopener" aria-label="Website resmi BPS Kota Batu" title="Website"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M2 12h20"/><path d="M12 2a15.300 15.300 0 0 1 4 10 15.300 15.300 0 0 1-4 10 15.300 15.300 0 0 1-4-10 15.300 15.300 0 0 1 4-10z"/></svg></a>
      </div>
      <p class="social-note">@bpskotabatu</p>
    </div>
  </div>
  <div class="footer-bottom">
    <span>© 2026 SIMASTA — BPS Kota Batu. All Rights Reserved.</span>
    <a href="https://batukota.bps.go.id/id" target="_blank" rel="noopener">batukota.bps.go.id</a>
  </div>
</footer>

<script>
const navbar = document.getElementById('navbar');
const menuToggle = document.getElementById('menuToggle');
const navMenu = document.getElementById('navMenu');
const links = [...navMenu.querySelectorAll('a[href^="#"]')];
const sections = links.map(a => document.querySelector(a.getAttribute('href')));

menuToggle.addEventListener('click', () => {
  const open = navMenu.classList.toggle('active');
  menuToggle.setAttribute('aria-expanded', open);
});
links.forEach(l => l.addEventListener('click', () => {
  navMenu.classList.remove('active');
  menuToggle.setAttribute('aria-expanded', 'false');
}));

function onScroll() {
  const y = window.scrollY;
  navbar.classList.toggle('scrolled', y > 50);
  const pos = y + 140;
  let current = 0;
  sections.forEach((s, i) => { if (s && s.offsetTop <= pos) current = i; });
  if (window.innerHeight + y >= document.body.scrollHeight - 4) current = sections.length - 1;
  links.forEach((a, i) => a.classList.toggle('active', i === current));
}
window.addEventListener('scroll', onScroll, { passive: true });
onScroll();

// Stepper alur: langkah yang disentuh/di-hover/difokus jadi aktif
const steps = [...document.querySelectorAll('#alurGrid .alur-item')];
function setStep(el) {
  steps.forEach(s => s.classList.toggle('is-active', s === el));
}
steps.forEach(s => {
  s.addEventListener('mouseenter', () => setStep(s));
  s.addEventListener('focus', () => setStep(s));
  s.addEventListener('click', () => setStep(s));
});
</script>
</body>
</html>