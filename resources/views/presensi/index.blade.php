<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="csrf-token" content="{{ csrf_token() }}">
    <meta name="referrer" content="{{ in_array(request()->getHost(), ['localhost', '127.0.0.1']) ? 'no-referrer-when-downgrade' : 'strict-origin-when-cross-origin' }}">
    <title>Presensi Magang | BPS Kota Batu</title>
    <link rel="stylesheet" href="{{ asset('presensi-assets/app.css') }}?v={{ filemtime(public_path('presensi-assets/app.css')) }}">
    <link rel="stylesheet" href="{{ asset('presensi-assets/auth.css') }}?v={{ filemtime(public_path('presensi-assets/auth.css')) }}">
    <script type="module" src="{{ asset('presensi-assets/app.js') }}?v={{ filemtime(public_path('presensi-assets/app.js')) }}"></script>
</head>
<body class="presensi-page auth-screen" data-auth-mode="{{ $authMode }}" data-local-test="{{ config('presensi.local_test') ? 'true' : 'false' }}">
    <header class="topbar presensi-topbar">
        <a href="{{ $presensiHome }}" class="brand"><img src="{{ asset('images/logo-bps.png') }}" alt="Logo BPS"><span><strong>Presensi<span class="brand-accent">.</span></strong><small>BADAN PUSAT STATISTIK KOTA BATU</small></span></a>
        <span class="header-label" id="header-label"><span class="status-dot"></span>Sistem Presensi Magang</span>
        <details class="account-menu" id="account-menu" hidden>
            <summary class="account-trigger"><span class="account-avatar" aria-hidden="true"><svg viewBox="0 0 24 24" fill="none"><circle cx="12" cy="8" r="3.5"/><path d="M5 20a7 7 0 0 1 14 0"/></svg></span><span>Akun</span><svg class="account-chevron" viewBox="0 0 20 20" fill="none" aria-hidden="true"><path d="m5 8 5 5 5-5"/></svg></summary>
            <div class="account-popover"><div class="account-info"><span>Akun presensi</span><strong id="account-name"></strong><span class="role-tag" id="role-tag"></span></div><button type="button" id="logout" class="account-logout"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M10 4H5v16h5M14 8l4 4-4 4M8 12h10"/></svg>Keluar</button></div>
        </details>
    </header>
    <main>
        @if (config('presensi.local_test'))
            <p class="local-test-banner" role="note">Mode uji lokal. Data pada halaman ini terpisah dari Android dan hosting.</p>
        @endif
        <div id="notice" class="notice" role="status" aria-live="polite" hidden></div>
        <section id="auth" class="auth-layout" aria-label="Akses akun presensi" hidden>
            <div class="auth-intro">
                <div class="intro-topline"><span class="intro-pill"><span class="status-dot"></span>PRESENSI BPS KOTA BATU</span><span class="intro-year">{{ date('Y') }}</span></div>
                <div class="intro-copy"><h1>Awali hari baik.<br>Catat kehadiranmu.</h1><p>Teman perjalanan magangmu, dari presensi pertama hingga hari terakhir.</p></div>
                <div class="attendance-art" aria-hidden="true">
                    <div class="art-orbit orbit-one"></div><div class="art-orbit orbit-two"></div>
                    <div class="art-calendar"><div class="calendar-rings"><i></i><i></i></div><div class="calendar-caption"><span>SETIAP LANGKAH BERARTI</span><svg viewBox="0 0 24 24" fill="none"><path d="M5 7h14M5 12h14M5 17h8" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/></svg></div><div class="calendar-days"><span>S</span><span>S</span><span>R</span><span>K</span><span>J</span></div><div class="calendar-marks"><span class="checked">✓</span><span class="checked">✓</span><span class="checked">✓</span><span class="current">✓</span><span class="next">·</span></div><div class="calendar-bottom"><span class="art-progress"><i></i></span><span>Satu hari, satu langkah maju.</span></div></div>
                    <div class="art-pin"><svg viewBox="0 0 24 24" fill="none"><path d="M19 10c0 5-7 10-7 10S5 15 5 10a7 7 0 0 1 14 0Z" stroke="currentColor" stroke-width="1.7"/><circle cx="12" cy="10" r="2.3" stroke="currentColor" stroke-width="1.7"/></svg></div>
                    <div class="art-check"><svg viewBox="0 0 24 24" fill="none"><path d="m6 12 4 4 8-8" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"/></svg></div>
                    <div class="art-caption"><span class="caption-icon"><svg viewBox="0 0 24 24" fill="none"><path d="M8 3h8v18H8zM11 17h2" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"/></svg></span><div><strong>Satu akun, tetap terhubung.</strong><small>Akses melalui web dan Android.</small></div><span class="caption-check">✓</span></div>
                </div>
                <div class="intro-bottom"><span><svg viewBox="0 0 20 20" fill="none"><path d="m10 2 6 2.5v4.7c0 4.1-6 7.8-6 7.8S4 13.3 4 9.2V4.5L10 2Z" stroke="currentColor" stroke-width="1.4"/><path d="m7 9.5 2 2 4-4" stroke="currentColor" stroke-width="1.4" stroke-linecap="round"/></svg>Presensi akurat, aktivitas terpantau.</span><span>BPS · KOTA BATU</span></div>
            </div>
            <div class="card auth-card">
                <div class="auth-tabs" role="group" aria-label="Akun presensi"><button type="button" data-auth="login" class="selected" aria-pressed="true">Masuk</button><button type="button" data-auth="register" aria-pressed="false">Daftar akun</button></div>
                <div class="auth-heading"><span class="auth-eyebrow">SELAMAT DATANG DI PRESENSI</span><h2 id="auth-title">Masuk ke akunmu</h2><p class="muted" id="auth-description">Lanjutkan aktivitas magangmu di BPS Kota Batu.</p></div>
                <div id="google-signin" data-client-id="{{ config('presensi.google_client_id') }}"><div id="google-official-button" hidden></div>
                <button id="google-unavailable" type="button" class="google-button" disabled aria-describedby="google-status"><svg viewBox="0 0 48 48" aria-hidden="true"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5Z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6C44.4 38.02 46.98 31.87 46.98 24.55Z"/><path fill="#FBBC05" d="M10.53 28.59A14.4 14.4 0 0 1 9.77 24c0-1.59.27-3.13.76-4.59l-7.98-6.19A23.9 23.9 0 0 0 0 24c0 3.87.93 7.53 2.56 10.78l7.97-6.19Z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.91-5.8l-7.73-6c-2.15 1.45-4.92 2.3-8.18 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48Z"/></svg><span>Lanjutkan dengan Google</span></button></div>
                <p id="google-status" class="google-status">Menyiapkan login Google…</p>
                <button type="button" id="google-retry" class="text-link google-retry" data-google-retry hidden>Coba muat Google lagi</button>
                <div class="auth-divider"><span>atau gunakan email</span></div>
                <form id="auth-form">
                    <label id="name-field" hidden>Nama lengkap<span class="auth-input"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><circle cx="12" cy="8" r="3.5" stroke="currentColor" stroke-width="1.6"/><path d="M5 21v-2a7 7 0 0 1 14 0v2" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg><input name="nama_lengkap" autocomplete="name" maxlength="150" placeholder="Nama lengkapmu"></span></label>
                    <label>Email<span class="auth-input"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="3" y="5" width="18" height="14" rx="3" stroke="currentColor" stroke-width="1.6"/><path d="m4 7 8 6 8-6" stroke="currentColor" stroke-width="1.6" stroke-linejoin="round"/></svg><input name="email" type="email" autocomplete="username" required maxlength="254" placeholder="nama@email.com"></span></label>
                    <label>Kata sandi<span class="auth-input"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="5" y="10" width="14" height="11" rx="3" stroke="currentColor" stroke-width="1.6"/><path d="M8 10V7a4 4 0 0 1 8 0v3" stroke="currentColor" stroke-width="1.6" stroke-linecap="round"/></svg><input id="login-password" name="password" type="password" autocomplete="current-password" required maxlength="256" placeholder="Masukkan kata sandi"><button type="button" class="password-toggle" data-toggle-password="login-password" aria-label="Tampilkan kata sandi" aria-pressed="false"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z" stroke="currentColor" stroke-width="1.6"/><circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="1.6"/></svg></button></span></label>
                    <label id="confirmation-field" hidden>Ulangi kata sandi<span class="auth-input"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><rect x="5" y="10" width="14" height="11" rx="3" stroke="currentColor" stroke-width="1.6"/><path d="M8 10V7a4 4 0 0 1 8 0v3" stroke="currentColor" stroke-width="1.6"/></svg><input id="register-confirmation" name="confirmation" type="password" autocomplete="new-password" maxlength="256" placeholder="Ulangi kata sandi"><button type="button" class="password-toggle" data-toggle-password="register-confirmation" aria-label="Tampilkan kata sandi" aria-pressed="false"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M2 12s4-7 10-7 10 7 10 7-4 7-10 7S2 12 2 12Z" stroke="currentColor" stroke-width="1.6"/><circle cx="12" cy="12" r="3" stroke="currentColor" stroke-width="1.6"/></svg></button></span></label>
                    <p id="auth-error" class="form-error" role="alert" hidden></p>
                    <button type="submit" class="button primary wide" id="auth-submit">Masuk ke Presensi <span aria-hidden="true">→</span></button>
                </form>
                <p class="auth-help">Gunakan akun presensi yang sama dengan aplikasi Android.</p>
                <p class="service-status" id="service-status" role="status">Memeriksa layanan…</p>
            </div>
        </section>
        <section id="workspace" hidden>
            <div class="workspace-heading"><div><span class="eyebrow">PRESENSI BPS KOTA BATU</span><h1 id="greeting">Selamat datang</h1><p class="muted" id="workspace-subtitle">Kelola kehadiran dan aktivitas magang Anda.</p></div></div>
            <div class="sync-line"><span class="status-dot"></span><span id="sync-status" role="status" aria-live="polite">{{ config('presensi.local_test') ? 'Data uji disimpan di komputer ini.' : 'Data mengikuti akun presensi Android Anda.' }}</span><button type="button" class="refresh-link" id="refresh"><svg viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="M20 7v5h-5M4 17v-5h5M5.5 9a7 7 0 0 1 12-2L20 12M4 12l2.5 5a7 7 0 0 0 12-2"/></svg>Perbarui</button></div>
            <nav id="tabs" class="tabs" aria-label="Menu presensi"></nav>
            <div id="content" aria-live="polite"></div>
        </section>
        <div id="loading" class="loading-panel" role="status"><span class="spinner"></span>Menyiapkan presensi…</div>
        <noscript><p class="card">Aktifkan JavaScript untuk menggunakan presensi.</p></noscript>
    </main>
    <footer class="page-footer"><span>© {{ date('Y') }} BPS Kota Batu. Sistem Presensi Magang.</span><span>Dibuat untuk setiap langkah perjalanan magangmu.</span></footer>
    <dialog id="modal"><div class="modal-heading"><h2 id="modal-title"></h2><button type="button" id="close-modal" class="icon-button" aria-label="Tutup">×</button></div><div id="modal-body"></div></dialog>
</body>
</html>
