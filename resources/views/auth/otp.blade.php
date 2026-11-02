<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Verifikasi Email - SIMASTA</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
:root{
  --neon:#34D399;--neon-dark:#10B981;--neon-soft:#D1FAE5;
  --orange:#FB923C;--orange-dark:#EA580C;--orange-soft:#FFEDD5;
  --blue:#60A5FA;--blue-dark:#3B82F6;--blue-soft:#DBEAFE;
  --navy:#1E293B;--muted:#64748b;
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
@media(min-width:950px){
  .auth-wrapper{flex-direction:row}
  .auth-side{flex:1;padding:50px 55px;height:100vh;position:sticky;top:0;border-right:1px solid rgba(15,23,42,.06)}
  .auth-side-logo{margin-bottom:60px}
}
@media(max-width:949px){.auth-side p,.auth-side-badge{display:none}.auth-side h1{font-size:22px;margin-bottom:0}.auth-side-logo{margin-bottom:18px}.auth-side-footer{display:none}}

/* ===== Panel kanan ===== */
.auth-form-side{flex:1;display:flex;justify-content:center;align-items:flex-start;padding:40px 24px 60px;background:#F8FAFC}
.auth-card{position:relative;overflow:hidden;width:100%;max-width:480px;background:#fff;border-radius:16px;
  box-shadow:0 20px 50px rgba(15,23,42,.08);padding:40px 36px 34px}
.auth-card::before{content:"";position:absolute;top:0;left:0;right:0;height:5px;
  background:linear-gradient(90deg,var(--neon),var(--blue),var(--orange))}

.pane-title{font-size:24px;font-weight:800;margin-bottom:8px}
.pane-desc{font-size:13.5px;line-height:1.6;color:var(--muted);margin-bottom:24px}
.pane-desc b{color:var(--navy);word-break:break-all}

label{display:block;margin-bottom:8px;font-weight:600;font-size:13px}
button{font-family:inherit;border:0;outline-offset:2px;cursor:pointer;-webkit-appearance:none;appearance:none}
.code-input{width:100%;padding:14px 12px;border:1px solid #d1d5db;border-radius:8px;background:#f8fafc;
  font-family:inherit;font-size:28px;font-weight:700;letter-spacing:14px;text-align:center;text-indent:14px;transition:.2s}
.code-input::placeholder{color:#cbd5e1;letter-spacing:14px}
.code-input:focus{outline:none;border-color:var(--blue);background:#fff;box-shadow:0 0 0 3px rgba(96,165,250,.15)}
.hint{font-size:12px;color:var(--muted);margin:10px 0 20px;line-height:1.6}

.btn-submit{width:100%;padding:13px;border-radius:8px;background:linear-gradient(120deg,#93C5FD,#6EE7B7);
  color:#0F2A4D;font-size:14px;font-weight:700;transition:.2s;box-shadow:0 10px 25px rgba(96,165,250,.30)}
.btn-submit:hover{opacity:.92;transform:translateY(-1px)}

.resend{text-align:center;margin-top:20px;font-size:13.5px;color:var(--muted)}
.resend form{display:inline}
.link-btn{background:none;padding:0;color:var(--orange-dark);font-weight:700;font-size:inherit}
.link-btn:hover{text-decoration:underline}
.link-btn:disabled{color:#94a3b8;cursor:not-allowed;text-decoration:none}
.back{display:block;text-align:center;margin-top:14px;font-size:13px;color:var(--blue-dark);text-decoration:none;font-weight:600}
.back:hover{text-decoration:underline}

.alert{border-radius:8px;padding:10px 12px;font-size:12.5px;margin-bottom:16px;line-height:1.6}
.alert-error{background:#fef2f2;border:1px solid #fecaca;color:#b91c1c}
.alert-ok{background:#f0fdf4;border:1px solid #bbf7d0;color:#15803d}

:focus-visible{outline:2px solid var(--blue-dark);outline-offset:2px}
@media(max-width:600px){
  .auth-form-side{padding:20px 12px 40px}
  .auth-card{padding:32px 20px 28px}
  .code-input{font-size:24px;letter-spacing:10px;text-indent:10px}
}
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
    <h1>Satu langkah lagi untuk <span>mengaktifkan akunmu</span>.</h1>
    <p>Kami mengirim kode verifikasi ke email yang kamu daftarkan. Masukkan kode itu untuk memastikan email tersebut milikmu.</p>
    <div class="auth-side-footer">© {{ date('Y') }} SIMASTA — BPS Kota Batu</div>
  </div>

  {{-- PANEL KANAN --}}
  <div class="auth-form-side">
    <div class="auth-card">

      <h2 class="pane-title">Verifikasi Email</h2>
      <p class="pane-desc">Masukkan 6 digit kode yang dikirim ke <b>{{ $email }}</b>.</p>

      @if (session('success'))
        <div class="alert alert-ok">{{ session('success') }}</div>
      @endif
      @error('code')
        <div class="alert alert-error">{{ $message }}</div>
      @enderror

      <form action="{{ route('otp.verify') }}" method="POST">
        @csrf
        <label for="code">Kode verifikasi</label>
        <input id="code" class="code-input" type="text" name="code" placeholder="••••••"
               maxlength="6" inputmode="numeric" pattern="[0-9]{6}" autocomplete="one-time-code" autofocus required>
        <p class="hint">Kode berlaku 10 menit. Jangan bagikan kode ini ke siapa pun. Setelah 5 kali salah, kode terkunci dan kamu perlu meminta kode baru.</p>
        <button type="submit" class="btn-submit">Verifikasi</button>
      </form>

      <div class="resend">
        Belum menerima kode?
        <form action="{{ route('otp.resend') }}" method="POST" id="resend-form">
          @csrf
          <button type="submit" class="link-btn" id="resend-btn">Kirim ulang kode</button>
        </form>
      </div>
      <a class="back" href="/login">Kembali ke halaman masuk</a>

    </div>
  </div>
</div>

<script>
(function () {
  // Hanya angka yang boleh diketik
  var code = document.getElementById('code');
  code.addEventListener('input', function () {
    code.value = code.value.replace(/\D/g, '').slice(0, 6);
  });

  // Tombol kirim ulang dijeda 30 detik supaya tidak spam
  var btn = document.getElementById('resend-btn'), left = 30;
  btn.disabled = true;
  btn.textContent = 'Kirim ulang kode (' + left + ' detik)';
  var timer = setInterval(function () {
    left--;
    if (left <= 0) {
      clearInterval(timer);
      btn.disabled = false;
      btn.textContent = 'Kirim ulang kode';
    } else {
      btn.textContent = 'Kirim ulang kode (' + left + ' detik)';
    }
  }, 1000);
})();
</script>
</body>
</html>