{{-- resources/views/layouts/mahasiswa.blade.php --}}
@php
    // status: belum_diajukan | diproses | diverifikasi | diterima | ditolak
    $statusMagang = auth()->user()->statusMagang();
    $diterima     = $statusMagang === 'diterima';

    // [label, path, icon, terkunci?]
    $menus = [
        ['Beranda',                'mahasiswa/dashboard',  'bi-house-door',         false],
        ['Dokumen Magang',         'mahasiswa/dokumen',    'bi-file-earmark-text',  false],
        ['Surat Keterangan',       'mahasiswa/surat',      'bi-file-earmark-check', false],
        ['Logbook',                'mahasiswa/logbook',    'bi-journal-text',       !$diterima],
        ['Penilaian & Sertifikat', 'mahasiswa/penilaian',  'bi-award',              !$diterima],
        ['Pengumuman',             'mahasiswa/pengumuman', 'bi-megaphone',          false],
        ['Bantuan',                'mahasiswa/bantuan',    'bi-question-circle',    false],
    ];
@endphp

<link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.3/font/bootstrap-icons.min.css">

<style>
:root{ --sb-w:250px; }
html.sb-collapsed{ --sb-w:78px; }

.mhs-side{
    --blue:#1d5fa8; --blue-dark:#12457f; --green:#2fa266; --orange:#f5a65b; --orange-dark:#ee8a3a;
    position:fixed; top:0; left:0; bottom:0;
    width:var(--sb-w); height:100vh; z-index:100; overflow:hidden;
    display:flex; flex-direction:column; color:#fff;
    transition:width .3s ease;
    background:
        radial-gradient(circle at 100% 0%, rgba(47,162,102,.35) 0, transparent 40%),
        radial-gradient(circle at 0% 100%, rgba(245,166,91,.25) 0, transparent 35%),
        linear-gradient(180deg,var(--blue) 0%,var(--blue-dark) 100%);
}

/* logo */
.mhs-logo{display:flex; align-items:center; gap:12px; padding:18px;
    border-bottom:1px solid rgba(255,255,255,.15); flex-shrink:0; white-space:nowrap}
.mhs-logo img{width:42px; height:42px; object-fit:contain; flex-shrink:0;
    filter:drop-shadow(0 2px 4px rgba(0,0,0,.25))}
.mhs-logo strong{display:block; font-size:16px; font-weight:700; line-height:1.2}
.mhs-logo small{font-size:10px; letter-spacing:1px; opacity:.8}

/* menu */
.mhs-menu{list-style:none; margin:0; padding:12px; flex:1; overflow-y:auto; overflow-x:hidden}
.mhs-menu li{margin-bottom:3px}
.mhs-menu::-webkit-scrollbar{width:5px}
.mhs-menu::-webkit-scrollbar-thumb{background:rgba(255,255,255,.28); border-radius:10px}
.mhs-menu::-webkit-scrollbar-track{background:transparent}
.mhs-menu{scrollbar-width:thin; scrollbar-color:rgba(255,255,255,.28) transparent}

.mhs-menu a, .mhs-menu .locked, .mhs-toggle{
    display:flex; align-items:center; gap:12px; width:100%;
    padding:10px 14px; border-radius:12px; font-size:14px; font-weight:500;
    color:#fff; text-decoration:none; transition:.2s; white-space:nowrap;
    border:0; background:transparent; font-family:inherit; cursor:pointer; text-align:left;
}
.mhs-menu i{font-size:17px; width:20px; text-align:center; flex-shrink:0}
.mhs-menu a:hover, .mhs-toggle:hover{background:rgba(255,255,255,.14)}
.mhs-menu a:focus-visible, .mhs-menu .locked:focus-visible, .mhs-toggle:focus-visible,
.mhs-user-top:focus-visible, .mhs-quick a:focus-visible, .mhs-logout:focus-visible{
    outline:2px solid #fff; outline-offset:2px}

/* AKTIF = ORANYE */
.mhs-menu a.active{
    background:linear-gradient(120deg,var(--orange),var(--orange-dark));
    color:#fff; font-weight:600;
    box-shadow:0 6px 16px rgba(238,138,58,.4);
}
.mhs-menu a.active i{color:#fff}

/* terkunci */
.mhs-menu .locked{opacity:.5; cursor:not-allowed; position:relative}
.mhs-menu .locked:hover{background:rgba(255,255,255,.07)}
.mhs-menu .locked .lock{margin-left:auto; font-size:13px; width:auto}

/* tombol tutup/buka menu */
.mhs-toggle{margin-bottom:6px; border-bottom:1px solid rgba(255,255,255,.12); border-radius:12px 12px 0 0; padding-bottom:12px}
.mhs-toggle i{transition:transform .3s}

/* ===== kartu user ===== */
.mhs-user{margin:12px; padding:10px; border-radius:16px;
    background:rgba(255,255,255,.12); flex-shrink:0; overflow:hidden}
.mhs-user-top{
    display:flex; align-items:center; gap:10px; padding:8px; margin-bottom:6px;
    border-radius:12px; color:#fff; text-decoration:none; transition:.2s;
}
.mhs-user-top:hover{background:rgba(255,255,255,.1)}
.mhs-user-top.active{
    background:linear-gradient(120deg,var(--orange),var(--orange-dark));
    box-shadow:0 6px 16px rgba(238,138,58,.35);
}
.mhs-user-top.active .mhs-badge{background:#fff; color:#b45309}
.mhs-avatar{width:38px; height:38px; border-radius:50%; background:var(--green);
    display:grid; place-items:center; font-weight:700; flex-shrink:0}
.mhs-user-info{min-width:0; flex:1}
.mhs-user b{font-size:13px; display:block; white-space:nowrap; overflow:hidden; text-overflow:ellipsis}
.mhs-user small{font-size:11px; opacity:.85; display:block; white-space:nowrap; overflow:hidden; text-overflow:ellipsis}
.mhs-badge{display:inline-block; margin-top:4px; padding:2px 8px; border-radius:20px;
    font-size:10px; font-weight:600; background:var(--orange); color:#5a3200}
.mhs-badge.ok{background:var(--green); color:#fff}
.mhs-chev{font-size:14px; opacity:.7; transition:.2s; flex-shrink:0}
.mhs-user-top:hover .mhs-chev{transform:translateX(3px); opacity:1}

.mhs-logout{
    width:100%; display:flex; align-items:center; justify-content:center; gap:8px;
    padding:10px; border:0; border-radius:12px; background:rgba(255,255,255,.18);
    color:#fff; font-weight:600; font-size:13px; cursor:pointer; font-family:inherit; transition:.2s;
}
.mhs-logout:hover{background:var(--orange); color:#5a3200}

/* toast */
.mhs-toast{position:fixed; left:50%; bottom:24px; transform:translate(-50%,16px); z-index:300;
    background:#14213d; color:#fff; padding:11px 16px; border-radius:12px; font-size:13px;
    max-width:90vw; opacity:0; pointer-events:none; transition:.25s}
.mhs-toast.show{opacity:1; transform:translate(-50%,0)}

/* ===== MODE TERTUTUP (hanya ikon) ===== */
html.sb-collapsed .mhs-logo{justify-content:center; padding:18px 0}
html.sb-collapsed .mhs-logo > div,
html.sb-collapsed .mhs-menu span,
html.sb-collapsed .mhs-user-info,
html.sb-collapsed .mhs-chev,
html.sb-collapsed .mhs-quick,
html.sb-collapsed .mhs-logout span{display:none}

html.sb-collapsed .mhs-menu{padding:12px 10px}
html.sb-collapsed .mhs-menu a,
html.sb-collapsed .mhs-menu .locked,
html.sb-collapsed .mhs-toggle{justify-content:center; padding:11px 0}
html.sb-collapsed .mhs-toggle i{transform:rotate(180deg)}
html.sb-collapsed .mhs-menu .locked .lock{position:absolute; top:5px; right:12px; font-size:9px; margin:0}

html.sb-collapsed .mhs-user{margin:10px; padding:6px}
html.sb-collapsed .mhs-user-top{justify-content:center; padding:6px 0}
</style>

<aside class="mhs-side">

    <div class="mhs-logo">
        <img src="{{ asset('images/logo-bps.png') }}" alt="Logo BPS">
        <div>
            <strong>SIMASTA</strong>
            <small>BPS KOTA BATU</small>
        </div>
    </div>

    <ul class="mhs-menu">

        <li>
            <button type="button" class="mhs-toggle" id="mhsToggle" title="Tutup / buka menu">
                <i class="bi bi-chevron-double-left"></i>
                <span>Tutup Menu</span>
            </button>
        </li>

        @foreach($menus as [$label, $path, $icon, $locked])
            <li>
                @if($locked)
                    <button type="button" class="locked" data-locked="{{ $label }}"
                            aria-disabled="true" title="{{ $label }} (terbuka setelah lolos magang)">
                        <i class="bi {{ $icon }}"></i>
                        <span>{{ $label }}</span>
                        <i class="bi bi-lock-fill lock"></i>
                    </button>
                @else
                    <a href="/{{ $path }}" title="{{ $label }}"
                       class="{{ request()->is($path.'*') ? 'active' : '' }}">
                        <i class="bi {{ $icon }}"></i>
                        <span>{{ $label }}</span>
                    </a>
                @endif
            </li>
        @endforeach
    </ul>

    {{-- KARTU USER: klik langsung ke Profil (sudah termasuk Posisi Magang) --}}
    <div class="mhs-user">

        <a href="/mahasiswa/profil" title="Profil & Posisi Magang"
           class="mhs-user-top {{ request()->is('mahasiswa/profil*') ? 'active' : '' }}">
            <div class="mhs-avatar">{{ strtoupper(substr(auth()->user()->name ?? 'M', 0, 1)) }}</div>
            <div class="mhs-user-info">
                <b>{{ auth()->user()->name ?? 'Mahasiswa' }}</b>
                <small>{{ auth()->user()->email ?? '' }}</small>
                <span class="mhs-badge {{ $diterima ? 'ok' : '' }}">
                    {{ $diterima ? 'Peserta Magang' : 'Calon Peserta' }}
                </span>
            </div>
            <i class="bi bi-chevron-right mhs-chev"></i>
        </a>

        <form method="POST" action="/logout">
            @csrf
            <button type="submit" class="mhs-logout" title="Keluar">
                <i class="bi bi-box-arrow-right"></i> <span>Keluar</span>
            </button>
        </form>
    </div>

</aside>

<div class="mhs-toast" id="mhsToast" role="status"></div>

<script>
(function () {
    var root = document.documentElement;
    var KEY  = 'simasta_sidebar_collapsed';

    try { if (localStorage.getItem(KEY) === '1') root.classList.add('sb-collapsed'); } catch (e) {}

    document.getElementById('mhsToggle').addEventListener('click', function () {
        var closed = root.classList.toggle('sb-collapsed');
        try { localStorage.setItem(KEY, closed ? '1' : '0'); } catch (e) {}
    });

    var toast = document.getElementById('mhsToast'), timer;
    function show(msg) {
        toast.textContent = msg;
        toast.classList.add('show');
        clearTimeout(timer);
        timer = setTimeout(function () { toast.classList.remove('show'); }, 3000);
    }

    document.querySelectorAll('[data-locked]').forEach(function (btn) {
        btn.addEventListener('click', function () {
            show('"' + btn.dataset.locked + '" terbuka setelah kamu dinyatakan lolos magang di BPS.');
        });
    });

    // pesan dari middleware saat URL terkunci dibuka manual
    @if(session('terkunci'))
        show(@json(session('terkunci')));
    @endif
})();
</script>