@php
    // Ikon Google (dipakai di 2 tombol)
    $googleIcon = '<svg viewBox="0 0 48 48" aria-hidden="true"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/></svg>';
    $eyeIcon = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>';
@endphp
<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Masuk & Daftar - SIMASTA</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{
  --neon:#34D399;--neon-dark:#10B981;--neon-soft:#D1FAE5;
  --orange:#FB923C;--orange-dark:#EA580C;--orange-soft:#FFEDD5;--orange-tint:#FFF7ED;
  --blue:#60A5FA;--blue-dark:#3B82F6;--blue-soft:#DBEAFE;
  --navy:#1E293B;--navy-soft:#334155;--muted:#64748b;
}
body{font-family:Arial,sans-serif;min-height:100vh;color:var(--navy)}
.auth-wrapper{display:flex;flex-direction:column;min-height:100vh}

/* ===== Panel kiri ===== */
.auth-side{position:relative;overflow:hidden;display:flex;flex-direction:column;padding:32px 28px;
  background:
   radial-gradient(circle at 12% 18%,rgba(52,211,153,.38),transparent 46%),
   radial-gradient(circle at 90% 14%,rgba(96,165,250,.38),transparent 50%),
   radial-gradient(circle at 55% 96%,rgba(251,146,60,.32),transparent 48%),
   linear-gradient(160deg,#EAFBF3,#EAF3FF)}
.auth-side::before{content:"";position:absolute;width:340px;height:340px;border-radius:50%;
  background:rgba(255,255,255,.45);right:-110px;bottom:-110px}
.auth-side>*{position:relative;z-index:1}
.auth-side-logo{display:flex;align-items:center;gap:12px;margin-bottom:40px}
.auth-side-logo img{width:46px;height:46px;border-radius:10px}
.auth-side-logo .name{font-size:18px;font-weight:bold;line-height:1.2}
.auth-side-logo .sub{font-size:10px;letter-spacing:1px;color:var(--muted)}
.auth-side-badge{display:inline-flex;align-items:center;gap:8px;align-self:flex-start;background:#fff;
  border:1px solid var(--neon-soft);color:var(--neon-dark);padding:8px 16px;border-radius:30px;
  font-size:11px;font-weight:700;letter-spacing:1px;margin-bottom:22px;box-shadow:0 4px 12px rgba(16,185,129,.12)}
.auth-side-badge::before{content:"";width:6px;height:6px;border-radius:50%;background:var(--neon)}
.auth-side h1{font-size:30px;line-height:1.25;margin-bottom:16px;max-width:420px}
.auth-side h1 span{background:linear-gradient(120deg,var(--neon-dark),var(--blue-dark),var(--orange-dark));
  -webkit-background-clip:text;background-clip:text;-webkit-text-fill-color:transparent}
.auth-side p{color:#475569;font-size:15px;line-height:1.7;max-width:380px}
.auth-side-footer{margin-top:auto;padding-top:24px;font-size:12px;color:#94a3b8}
.side-swap{transition:opacity .25s ease,transform .25s ease}
.side-swap.out{opacity:0;transform:translateY(8px)}

@media(min-width:950px){
  .auth-wrapper{flex-direction:row}
  .auth-side{flex:1;padding:50px 55px;height:100vh;position:sticky;top:0;border-right:1px solid rgba(15,23,42,.06)}
  .auth-side-logo{margin-bottom:60px}
}
@media(max-width:949px){.auth-side p,.auth-side-badge,.auth-side-footer{display:none}.auth-side h1{font-size:22px;margin-bottom:0}.auth-side-logo{margin-bottom:18px}}

/* ===== Panel kanan ===== */
.auth-form-side{flex:1;display:flex;justify-content:center;align-items:flex-start;padding:40px 24px 60px;background:#F8FAFC}
.auth-card{position:relative;overflow:hidden;width:100%;max-width:560px;background:#fff;border-radius:16px;
  box-shadow:0 20px 50px rgba(15,23,42,.08)}
.auth-card::before{content:"";position:absolute;top:0;left:0;right:0;height:5px;z-index:2;
  background:linear-gradient(90deg,var(--neon),var(--blue),var(--orange))}

/* Tab pill */
.tabs{position:relative;display:grid;grid-template-columns:1fr 1fr;margin:26px 36px 0;padding:5px;background:#EEF2F7;border-radius:14px}
.tab{border:0;position:relative;z-index:1;background:none;border-radius:10px;padding:11px 8px;color:var(--muted);
  font-size:14px;font-weight:700;transition:color .3s}
.tab:hover,.tab.active{color:var(--navy)}
.tab-indicator{position:absolute;top:5px;bottom:5px;left:5px;width:calc(50% - 5px);border-radius:10px;background:#fff;
  box-shadow:0 2px 10px rgba(15,23,42,.10),0 0 0 1px rgba(15,23,42,.04);transition:transform .5s cubic-bezier(.77,0,.18,1)}
.tabs[data-active="daftar"] .tab-indicator{transform:translateX(100%)}

/* Track geser */
.viewport{overflow:hidden;transition:height .5s cubic-bezier(.77,0,.18,1)}
.track{display:flex;width:200%;align-items:flex-start;transition:transform .55s cubic-bezier(.77,0,.18,1)}
.track[data-active="daftar"]{transform:translateX(-50%)}
.pane{width:50%;padding:28px 36px 34px;opacity:1;transition:opacity .35s ease,transform .55s cubic-bezier(.77,0,.18,1),visibility 0s}
.pane[aria-hidden="true"]{visibility:hidden;opacity:0;pointer-events:none;transition:opacity .25s ease,transform .55s cubic-bezier(.77,0,.18,1),visibility 0s .55s}
#pane-masuk[aria-hidden="true"]{transform:translateX(-14%)}
#pane-daftar[aria-hidden="true"]{transform:translateX(14%)}
.pane[aria-hidden="false"] .stagger{animation:rise .5s cubic-bezier(.2,.7,.2,1) both;animation-delay:calc(var(--i,0)*60ms + 180ms)}
@keyframes rise{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:none}}

.pane-title{font-size:24px;font-weight:800;margin-bottom:6px}
.pane-desc{font-size:13.5px;line-height:1.6;color:var(--muted);margin-bottom:22px}

/* Tombol Google + pemisah */
.btn-google{display:flex;align-items:center;justify-content:center;gap:10px;width:100%;padding:12px;background:#fff;
  border:1px solid #d1d5db;border-radius:10px;color:var(--navy);font-size:14px;font-weight:700;text-decoration:none;transition:.2s}
.btn-google:hover{background:#f8fafc;border-color:#94a3b8;box-shadow:0 4px 14px rgba(15,23,42,.08)}
.btn-google svg{width:18px;height:18px}
.divider{display:flex;align-items:center;gap:12px;margin:20px 0;color:#94a3b8;font-size:12.5px}
.divider::before,.divider::after{content:"";flex:1;height:1px;background:#e5e7eb}

/* Form */
.form-group{margin-bottom:16px}
label{display:block;margin-bottom:6px;font-weight:600;font-size:13px}
.input-wrap{position:relative}
button{font-family:inherit;border:0;outline-offset:2px;cursor:pointer;-webkit-appearance:none;appearance:none}
input{width:100%;padding:12px;border:1px solid #d1d5db;border-radius:8px;font-size:14px;background:#f8fafc;font-family:inherit;transition:.2s}
input::placeholder{color:#9ca3af}
input:focus{outline:none;border-color:var(--blue);background:#fff;box-shadow:0 0 0 3px rgba(96,165,250,.15)}
.has-toggle input{padding-right:44px}
.eye{display:flex;align-items:center;justify-content:center;position:absolute;right:4px;top:50%;transform:translateY(-50%);
  width:38px;height:38px;padding:0;background:none;color:var(--muted);border-radius:8px}
.eye svg{width:19px;height:19px;pointer-events:none}
.eye:hover{background:#eef2f7}

/* Section register */
.form-section{margin-bottom:24px}
.sec-blue{--c:var(--blue-dark);--line:#BFDBFE}
.sec-green{--c:var(--neon-dark);--line:#A7F3D0}
.sec-orange{--c:var(--orange-dark);--line:#FED7AA}
.form-section-title{font-size:12px;font-weight:800;letter-spacing:.5px;text-transform:uppercase;color:var(--c);
  margin-bottom:14px;padding-bottom:8px;border-bottom:1px dashed var(--line)}
.form-section input:focus{border-color:var(--c);box-shadow:0 0 0 3px color-mix(in srgb,var(--c) 18%,transparent)}
.form-row{display:grid;grid-template-columns:1fr 1fr;gap:14px;margin-bottom:16px}
.form-row .form-group{margin-bottom:0}
.info-box{background:var(--orange-tint);border:1px solid var(--orange-soft);border-radius:10px;padding:12px 14px;
  font-size:12.5px;color:var(--navy-soft);line-height:1.6;margin-bottom:16px}
.info-box strong{color:var(--orange-dark)}

.btn-submit{width:100%;padding:13px;border-radius:8px;background:linear-gradient(120deg,#93C5FD,#6EE7B7);
  color:#0F2A4D;font-size:14px;font-weight:700;transition:.2s;box-shadow:0 10px 25px rgba(96,165,250,.30)}
.btn-submit:hover{opacity:.92;transform:translateY(-1px)}
.switch{text-align:center;margin-top:18px;font-size:13.5px;color:var(--muted)}
.switch button{width:auto;display:inline;padding:0;background:none;color:var(--orange-dark);font-weight:700;font-size:inherit}
.switch button:hover{text-decoration:underline}
.alert{background:#fef2f2;border:1px solid #fecaca;color:#b91c1c;border-radius:8px;padding:10px 12px;font-size:12.5px;margin-bottom:16px;line-height:1.6}
.alert.ok{background:#f0fdf4;border-color:#bbf7d0;color:#15803d}

:focus-visible{outline:2px solid var(--blue-dark);outline-offset:2px}
@media(max-width:600px){
  .auth-form-side{padding:20px 12px 40px}
  .pane{padding:22px 18px 28px}.tabs{margin:20px 18px 0}
  .form-row{grid-template-columns:1fr;margin-bottom:0}
  .form-row .form-group{margin-bottom:16px}
}
@media(prefers-reduced-motion:reduce){.track,.viewport,.tab-indicator,.pane,.side-swap{transition:none!important}.stagger{animation:none!important}}
</style>
</head>
<body>
<div class="auth-wrapper">

  {{-- PANEL KIRI --}}
  <div class="auth-side">
    <div class="auth-side-logo">
      <img src="{{ asset('images/logo-bps.png') }}" alt="Logo BPS">
      <div>
        <div class="name">SIMASTA</div>
        <div class="sub">BADAN PUSAT STATISTIK KOTA BATU</div>
      </div>
    </div>
    <span class="auth-side-badge">SISTEM MAGANG RESMI BPS KOTA BATU</span>
    <h1 class="side-swap" id="side-h1">Satu Akun untuk <span>Seluruh Proses Magangmu</span> di BPS Kota Batu.</h1>
    <p class="side-swap" id="side-p">Daftar dengan nama, nomor telepon, dan email. Data kampus dilengkapi di Profil setelah kamu login.</p>   
    <div class="auth-side-footer">© {{ date('Y') }} SIMASTA — BPS Kota Batu</div>
  </div>

  {{-- PANEL KANAN --}}
  <div class="auth-form-side">
    <div class="auth-card">

      <div class="tabs" id="tabs" data-active="masuk" role="tablist">
        <button type="button" class="tab active" id="tab-masuk" role="tab" aria-selected="true" aria-controls="pane-masuk" data-target="masuk">Masuk</button>
        <button type="button" class="tab" id="tab-daftar" role="tab" aria-selected="false" aria-controls="pane-daftar" data-target="daftar">Daftar</button>
        <span class="tab-indicator"></span>
      </div>

      <div class="viewport" id="viewport">
        <div class="track" id="track" data-active="masuk">

          {{-- ===== MASUK ===== --}}
          <section class="pane" id="pane-masuk" role="tabpanel" aria-labelledby="tab-masuk">
            <h2 class="pane-title stagger" style="--i:0">Masuk ke SIMASTA</h2>
            <p class="pane-desc stagger" style="--i:1">Gunakan email dan kata sandi, atau akun Google kamu.</p>

            <form action="/login" method="POST">
              @csrf
              @if (request()->is('login') && $errors->any())
                <div class="alert">{{ $errors->first() }}</div>
              @endif
              @if (session('success'))
                <div class="alert ok">{{ session('success') }}</div>
              @endif

              <div class="form-group stagger" style="--i:2">
                <label for="login-email">Email</label>
                <input id="login-email" type="email" name="email" placeholder="nama@email.com" value="{{ request()->is('login') ? old('email') : '' }}" required>
              </div>

              <div class="form-group stagger" style="--i:3">
                <label for="login-password">Kata Sandi</label>
                <div class="input-wrap has-toggle">
                  <input id="login-password" type="password" name="password" placeholder="Masukkan kata sandi" required>
                  <button type="button" class="eye" data-eye="login-password" aria-label="Tampilkan kata sandi">{!! $eyeIcon !!}</button>
                </div>
              </div>

              <button type="submit" class="btn-submit stagger" style="--i:4">Masuk</button>
            </form>

            <div class="divider stagger" style="--i:5">Atau</div>

            <a href="/auth/google/redirect" class="btn-google stagger" style="--i:6">{!! $googleIcon !!} Masuk dengan Google</a>

            <p class="switch">Belum punya akun? <button type="button" data-target="daftar">Daftar sekarang</button></p>
          </section>

          {{-- ===== DAFTAR ===== --}}
          <section class="pane" id="pane-daftar" role="tabpanel" aria-labelledby="tab-daftar" aria-hidden="true">
            <h2 class="pane-title stagger" style="--i:0">Registrasi Akun</h2>
            <p class="pane-desc stagger" style="--i:1">Lengkapi data berikut untuk membuat akun magang mahasiswa di BPS Kota Batu.</p>

            <a href="/auth/google/redirect" class="btn-google stagger" style="--i:2">{!! $googleIcon !!} Daftar dengan Google</a>

            <div class="divider stagger" style="--i:3">Atau isi data di bawah</div>

            <form action="/register" method="POST">
              @csrf

              @if (request()->is('register') && $errors->any())
                <div class="alert">
                  @foreach ($errors->all() as $error)
                    <div>• {{ $error }}</div>
                  @endforeach
                </div>
              @endif

{{-- DATA DIRI --}}
<div class="stagger form-section sec-blue" style="--i:4">
  <div class="form-section-title">👤 Data Diri</div>

  <div class="form-group">
    <label for="nama_lengkap">Nama Lengkap</label>
    <input id="nama_lengkap" type="text" name="nama_lengkap" placeholder="Nama lengkap" value="{{ old('nama_lengkap') }}" autocomplete="name" required>
  </div>

  <div class="form-group">
    <label for="no_telp">No. Telp Aktif</label>
    <input id="no_telp" type="tel" name="no_telp" placeholder="08xxxxxxxxxx" value="{{ old('no_telp') }}" inputmode="numeric" autocomplete="tel" required>
  </div>
</div>

              {{-- KEAMANAN AKUN --}}
              <div class="stagger form-section sec-orange" style="--i:6">
                <div class="form-section-title">🔐 Keamanan Akun</div>
                <div class="info-box">
                  Setelah mendaftar, kami mengirim <strong>kode OTP</strong> ke email kamu untuk memverifikasi akun. Setelah akun aktif dan login, Anda akan mengajukan <strong>program Magang</strong> pada dashboard SIMASTA.
                </div>
                <div class="form-group">
                  <label for="reg-email">Alamat Email</label>
                  <input id="reg-email" type="email" name="email" placeholder="nama@email.com" value="{{ request()->is('register') ? old('email') : '' }}" required>
                </div>
                <div class="form-row">
                  <div class="form-group">
                    <label for="reg-password">Kata Sandi</label>
                    <div class="input-wrap has-toggle">
                      <input id="reg-password" type="password" name="password" placeholder="Min. 8 karakter" minlength="8" required>
                      <button type="button" class="eye" data-eye="reg-password" aria-label="Tampilkan kata sandi">{!! $eyeIcon !!}</button>
                    </div>
                  </div>
                  <div class="form-group">
                    <label for="reg-password2">Konfirmasi Kata Sandi</label>
                    <div class="input-wrap has-toggle">
                      <input id="reg-password2" type="password" name="password_confirmation" placeholder="Ulangi kata sandi" required>
                      <button type="button" class="eye" data-eye="reg-password2" aria-label="Tampilkan kata sandi">{!! $eyeIcon !!}</button>
                    </div>
                  </div>
                </div>
              </div>

              <button type="submit" class="btn-submit">Daftar Sekarang</button>
            </form>

            <p class="switch">Sudah punya akun? <button type="button" data-target="masuk">Masuk di sini</button></p>
          </section>

        </div>
      </div>
    </div>
  </div>
</div>

<script>
(function () {
  var tabs = document.getElementById('tabs'),
      track = document.getElementById('track'),
      viewport = document.getElementById('viewport'),
      panes = { masuk: document.getElementById('pane-masuk'), daftar: document.getElementById('pane-daftar') },
      h1 = document.getElementById('side-h1'), sp = document.getElementById('side-p');

  var URLS = { masuk: '{{ url('/login') }}', daftar: '{{ url('/register') }}' };
  var START = '{{ request()->is('register') ? 'daftar' : 'masuk' }}';
  var copy = {
    masuk:  ['Selamat datang kembali di <span>SIMASTA</span>.', 'Masuk untuk memantau status pengajuan magang dan kelola berkasmu.'],
    daftar: ['Satu Akun untuk <span>Seluruh Proses Magangmu</span> di BPS Kota Batu.', 'Daftar dengan nama, nomor telepon, dan email. Data kampus dilengkapi di Profil setelah kamu login.']
  };

  function fit(name) { viewport.style.height = panes[name].offsetHeight + 'px'; }

  function swapSide(name) {
    h1.classList.add('out'); sp.classList.add('out');
    setTimeout(function () {
      h1.innerHTML = copy[name][0]; sp.textContent = copy[name][1];
      h1.classList.remove('out'); sp.classList.remove('out');
    }, 250);
  }

  function show(name, push) {
    if (tabs.dataset.active !== name) swapSide(name);
    tabs.dataset.active = track.dataset.active = name;
    ['masuk', 'daftar'].forEach(function (n) {
      var on = n === name, t = document.getElementById('tab-' + n);
      panes[n].setAttribute('aria-hidden', on ? 'false' : 'true');
      t.classList.toggle('active', on);
      t.setAttribute('aria-selected', on);
    });
    fit(name);
    if (push) { history.replaceState(null, '', URLS[name]); window.scrollTo({ top: 0, behavior: 'smooth' }); }
  }

  document.querySelectorAll('[data-target]').forEach(function (el) {
    el.addEventListener('click', function () { show(el.dataset.target, true); });
  });

  var EYE = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/></svg>',
      EYE_OFF = '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.9 10.9 0 0 1 12 19c-6.5 0-10-7-10-7a18.5 18.5 0 0 1 5.06-5.94"/><path d="M9.9 4.24A10.9 10.9 0 0 1 12 5c6.5 0 10 7 10 7a18.5 18.5 0 0 1-2.16 3.19"/><path d="M14.12 14.12A3 3 0 1 1 9.88 9.88"/><path d="M1 1l22 22"/></svg>';
  document.querySelectorAll('[data-eye]').forEach(function (b) {
    b.addEventListener('click', function () {
      var i = document.getElementById(b.dataset.eye), reveal = i.type === 'password';
      i.type = reveal ? 'text' : 'password';
      b.innerHTML = reveal ? EYE_OFF : EYE;
      b.setAttribute('aria-label', reveal ? 'Sembunyikan kata sandi' : 'Tampilkan kata sandi');
    });
  });

  show(START, false);
  h1.innerHTML = copy[START][0]; sp.textContent = copy[START][1];

  window.addEventListener('resize', function () { fit(track.dataset.active); });
  if (window.ResizeObserver) {
    var ro = new ResizeObserver(function () { fit(track.dataset.active); });
    ro.observe(panes.masuk); ro.observe(panes.daftar);
  }
})();
</script>
</body>
</html>