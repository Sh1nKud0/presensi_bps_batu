{{-- resources/views/mahasiswa/dashboard.blade.php --}}
@extends('layouts.app')

@section('title', 'Dashboard Mahasiswa - SIMASTA')
@section('page-title', 'Dashboard Mahasiswa')

@section('sidebar')
    @include('layouts.mahasiswa')
@endsection

@section('user-role')
    Mahasiswa
@endsection

@section('user-avatar')
    {{ strtoupper(substr(auth()->user()->name ?? 'M', 0, 1)) }}
@endsection

@section('page-description', 'Selamat datang di Sistem Informasi Manajemen Magang BPS Kota Batu')

@section('content')

@php
    $pengajuan = auth()->user()->pengajuan;
    $status    = $pengajuan->status ?? 'belum_diajukan';
    $diterima  = $status === 'diterima';

    $labelStatus = [
        'belum_diajukan' => 'Belum Diajukan',
        'diproses'       => 'Sedang Diproses',
        'diverifikasi'   => 'Berkas Terverifikasi',
        'diterima'       => 'Diterima',
        'ditolak'        => 'Ditolak',
    ][$status] ?? 'Belum Diajukan';

    $catatanStatus = [
        'belum_diajukan' => 'Silakan isi data dan unggah dokumen di menu Dokumen Magang.',
        'diproses'       => 'Pengajuan kamu sedang menunggu pemeriksaan admin.',
        'diverifikasi'   => 'Berkas sudah diperiksa, menunggu keputusan seleksi.',
        'diterima'       => 'Selamat, pengajuan magang kamu diterima.',
        'ditolak'        => 'Pengajuan belum dapat diterima.',
    ][$status] ?? '';

    $badgeClass = match ($status) {
        'diterima' => 'ok',
        'ditolak'  => 'bad',
        default    => 'pending',
    };

    $statusMagang = $diterima ? 'Aktif' : 'Belum Aktif';

    // ===== Data penempatan (diisi admin dari website admin) =====
    // Sesuaikan nama kolom dengan tabel pengajuan kamu.
    $instansi   = $pengajuan->instansi ?? null;
    $posisi     = $pengajuan->posisi ?? null;
    $pembimbing = $pengajuan->pembimbing_lapangan ?? null;

    $periode = '-';
    $progress = null; $hariKe = null; $totalHari = null;
    if (!empty($pengajuan->periode_mulai) && !empty($pengajuan->periode_selesai)) {
        $mulai   = \Carbon\Carbon::parse($pengajuan->periode_mulai)->startOfDay();
        $selesai = \Carbon\Carbon::parse($pengajuan->periode_selesai)->startOfDay();
        $periode = $mulai->translatedFormat('d M Y') . ' - ' . $selesai->translatedFormat('d M Y');

        if ($diterima) {
            $totalHari = max((int) $mulai->diffInDays($selesai) + 1, 1);
            $hariKe    = min(max((int) $mulai->diffInDays(now()->startOfDay(), false) + 1, 0), $totalHari);
            $progress  = (int) round($hariKe / $totalHari * 100);
        }
    }

    // Placeholder sampai modul logbook & penilaian dibuat
    $totalLogbook = 0;
    $nilaiAkhir   = null;

    // ===== Kelengkapan berkas (hanya tahap seleksi) =====
    // Aktif otomatis kalau model Pengajuan punya relasi dokumen().
    // Sesuaikan 'jenis' dengan kolom jenis dokumen di tabelmu.
    $persyaratan  = ['Surat pengantar kampus', 'CV', 'Transkrip nilai', 'Proposal magang'];
    $punyaDokumen = $pengajuan && method_exists($pengajuan, 'dokumen');
    $terunggah    = $punyaDokumen ? $pengajuan->dokumen->pluck('jenis')->all() : [];
    $jumlahLengkap = collect($persyaratan)->filter(fn ($p) => in_array($p, $terunggah))->count();

    // ===== Langkah berikutnya =====
    $berikutnya = [
        'belum_diajukan' => ['Isi form pengajuan', 'Lengkapi form dan unggah dokumen persyaratan.', 'Mulai pengajuan', '/mahasiswa/dokumen'],
        'diproses'       => ['Menunggu pemeriksaan admin', 'Admin sedang memeriksa berkasmu. Pastikan semua dokumen sudah lengkap.', 'Cek dokumen', '/mahasiswa/dokumen'],
        'diverifikasi'   => ['Menunggu keputusan seleksi', 'Berkasmu sudah terverifikasi. BPS akan menentukan hasil seleksi.', null, null],
        'diterima'       => ['Mulai kegiatan magang', 'Isi presensi harian dan logbook mulai hari pertama magang.', 'Buka presensi', '/mahasiswa/presensi'],
        'ditolak'        => ['Pengajuan belum diterima', 'Baca catatan admin di bagian atas untuk alasannya.', null, null],
    ][$status] ?? [];

    $aktif = match ($status) {
        'belum_diajukan'      => 0,
        'diproses'            => 1,
        'diverifikasi'        => 2,
        'diterima', 'ditolak' => 3,
        default               => 0,
    };

    $steps = [
        ['Pengajuan',         'Isi form & upload dokumen'],
        ['Verifikasi Berkas', 'Admin memeriksa berkas'],
        ['Seleksi',           'Penentuan oleh BPS'],
        ['Keputusan',         $status === 'ditolak' ? 'Ditolak' : ($status === 'diterima' ? 'Diterima' : 'Diterima / Ditolak')],
    ];

    // ===== Akses cepat mengikuti tahap =====
    $akses = $diterima ? [
        ['/mahasiswa/presensi',   'bi-geo-alt',         'Presensi',                 'Catat kehadiran harian magang.'],
        ['/mahasiswa/logbook',    'bi-journal-text',    'Logbook',                  'Isi kegiatan harian magang.'],
        ['/mahasiswa/penempatan', 'bi-people',          'Posisi Magang',            'Lihat posisi dan pembimbing lapangan.'],
        ['/mahasiswa/penilaian',  'bi-clipboard-check', 'Penilaian & Sertifikat', 'Lihat nilai dan sertifikat magang.'],
    ] : [
        ['/mahasiswa/dokumen',  'bi-file-earmark-text', 'Dokumen Magang',   'Isi data dan unggah dokumen persyaratan.'],
        ['/mahasiswa/profil',     'bi-person',             'Profil Mahasiswa', 'Periksa dan lengkapi informasi diri.'],
    ];
@endphp

<style>
    .student-dashboard{display:flex; flex-direction:column; gap:24px}

    /* sapaan */
    .student-welcome{
        position:relative; overflow:hidden; padding:30px; border-radius:18px;
        color:#16324f; border:1px solid #dbeafe;
        background:linear-gradient(120deg,#d9f7eb 0%,#e8f1ff 60%,#dce9ff 100%);
    }
    .student-welcome::after{
        content:""; position:absolute; width:180px; height:180px; right:-45px; top:-70px;
        border-radius:50%; background:rgba(245,166,91,.18);
    }
    .welcome-label{
        display:inline-block; padding:6px 12px; margin-bottom:14px; border-radius:20px;
        color:#18794e; background:rgba(255,255,255,.8);
        font-size:12px; font-weight:700; letter-spacing:.5px;
    }
    .student-welcome h1{margin:0 0 10px; font-size:clamp(23px,3vw,30px); line-height:1.35; color:#183153}
    .student-welcome p{margin:0; color:#52677f; line-height:1.7}

    .student-section-title{margin:0 0 5px; color:#1e293b; font-size:20px}
    .student-section-description{margin:0 0 20px; color:#64748b; font-size:14px; line-height:1.6}

    /* stepper */
    .stepper{display:flex; background:#fff; border:1px solid #e5eaf1; border-radius:16px;
        padding:26px 20px; box-shadow:0 4px 14px rgba(15,23,42,.035)}
    .step{flex:1; text-align:center; position:relative; min-width:0; padding:0 6px}
    .step:not(:last-child)::after{
        content:''; position:absolute; top:20px; left:50%; width:100%; height:4px;
        background:#e3e8ef; z-index:0;
    }
    .step.done:not(:last-child)::after{background:#2fa266}
    .step-dot{
        position:relative; z-index:1; width:42px; height:42px; margin:0 auto 10px;
        border-radius:50%; display:grid; place-items:center; font-weight:700;
        background:#e3e8ef; color:#8794a6;
    }
    .step.done .step-dot{background:#2fa266; color:#fff}
    .step.current .step-dot{background:#f5a65b; color:#fff; box-shadow:0 0 0 6px rgba(245,166,91,.25)}
    .step.rejected .step-dot{background:#d64545; color:#fff}
    .step b{display:block; font-size:14px; color:#1d5fa8}
    .step small{font-size:12px; color:#7a8696}

    /* banner hasil */
    .student-alert{padding:16px 20px; border-radius:14px; background:#fff; border:1px solid #e5eaf1;
        border-left-width:5px; color:#334155; line-height:1.6}
    .student-alert.ok{border-left-color:#2fa266}
    .student-alert.bad{border-left-color:#d64545}
    .student-alert.info{border-left-color:#f5a65b}

    /* statistik */
    .student-stat-grid{display:grid; grid-template-columns:repeat(4,minmax(0,1fr)); gap:16px}
    .student-stat-card{
        min-width:0; padding:22px; background:#fff; border:1px solid #e5eaf1;
        border-radius:16px; box-shadow:0 4px 14px rgba(15,23,42,.035);
    }
    .student-stat-card.locked{background:#f8fafc; box-shadow:none}
    .student-stat-card.locked .student-stat-value{color:#94a3b8}
    .student-stat-top{display:flex; align-items:center; justify-content:space-between; gap:10px; margin-bottom:18px}
    .student-stat-icon{display:grid; place-items:center; width:44px; height:44px; border-radius:13px; font-size:21px}
    .student-stat-icon.blue{color:#1d5fa8; background:#eaf2fc}
    .student-stat-icon.green{color:#168653; background:#e9f9ef}
    .student-stat-icon.orange{color:#c77716; background:#fff4df}
    .student-stat-icon.purple{color:#7c3aed; background:#f3e8ff}
    .student-stat-icon.gray{color:#94a3b8; background:#eef1f5}
    .student-stat-label{color:#64748b; font-size:13px; font-weight:600}
    .student-stat-value{margin:0 0 8px; color:#1e293b; font-size:21px; font-weight:700; overflow-wrap:anywhere}
    .student-stat-note{margin:0; color:#94a3b8; font-size:12px; line-height:1.5}

    /* panel + dua kolom */
    .student-duo{display:grid; grid-template-columns:1.1fr 1fr; gap:16px}
    .student-panel{
        min-width:0; padding:25px; background:#fff; border:1px solid #e5eaf1;
        border-radius:16px; box-shadow:0 4px 14px rgba(15,23,42,.035);
    }
    .student-panel h3{margin:0 0 4px; color:#1e293b; font-size:17px}
    .student-panel .student-section-description{margin-bottom:16px}

    /* kelengkapan berkas */
    .berkas-head{display:flex; align-items:center; gap:16px; margin-bottom:16px}
    .ring{--p:0; flex-shrink:0; width:84px; height:84px; border-radius:50%; display:grid; place-items:center;
        background:conic-gradient(#1d5fa8 calc(var(--p)*1%), #e8edf5 0)}
    .ring div{display:grid; place-items:center; width:64px; height:64px; border-radius:50%; background:#fff;
        font-weight:800; color:#1e293b; font-size:15px}
    .berkas-item{display:flex; align-items:center; gap:10px; padding:11px 13px; margin-bottom:8px;
        border:1px solid #e5eaf1; border-radius:12px; font-size:14px; color:#334155}
    .berkas-item:last-child{margin-bottom:0}
    .berkas-item i{font-size:18px; color:#cbd5e1}
    .berkas-item.y i{color:#2fa266}
    .berkas-item span{flex:1}
    .berkas-item em{font-style:normal; font-size:12px; color:#94a3b8}

    /* langkah berikutnya */
    .student-next{display:flex; flex-direction:column; justify-content:space-between; gap:18px; color:#fff; border:0;
        background:linear-gradient(130deg,#1d5fa8,#3b82d9)}
    .student-next.ok{background:linear-gradient(130deg,#168653,#2fa266)}
    .student-next h3{color:#fff}
    .student-next p{margin:0; opacity:.92; line-height:1.65; font-size:14px}
    .student-next a{align-self:flex-start; padding:11px 18px; border-radius:12px; background:#fff; color:#1d5fa8;
        font-weight:700; font-size:14px; text-decoration:none}
    .student-next.ok a{color:#0f6b41}
    .student-next a:focus-visible{outline:2px solid #fff; outline-offset:3px}

    /* tabel */
    .student-table-wrap{width:100%; overflow-x:auto}
    .student-table{width:100%; border-collapse:collapse; min-width:520px}
    .student-table th{
        padding:14px 16px; background:#f8fafc; color:#64748b; text-align:left;
        font-size:12px; text-transform:uppercase; letter-spacing:.4px; border-bottom:1px solid #e2e8f0;
    }
    .student-table td{padding:16px; color:#334155; font-size:14px; border-bottom:1px solid #edf2f7}
    .student-table tr:last-child td{border-bottom:none}

    .student-status{display:inline-flex; align-items:center; padding:6px 10px; border-radius:20px;
        font-size:12px; font-weight:650; white-space:nowrap}
    .student-status.pending{color:#a16207; background:#fef3c7}
    .student-status.neutral{color:#475569; background:#f1f5f9}
    .student-status.ok{color:#166534; background:#dcfce7}
    .student-status.bad{color:#991b1b; background:#fee2e2}

    /* akses cepat */
    .student-actions{display:grid; grid-template-columns:repeat(auto-fit,minmax(230px,1fr)); gap:14px}
    .student-action{
        display:flex; align-items:flex-start; gap:13px; padding:18px; color:inherit;
        text-decoration:none; background:#fff; border:1px solid #e5eaf1; border-radius:14px;
        transition:transform .2s, box-shadow .2s, border-color .2s;
    }
    .student-action:hover{transform:translateY(-3px); border-color:#b7d4fa; box-shadow:0 8px 20px rgba(29,95,168,.1)}
    .student-action-icon{
        display:grid; place-items:center; flex:0 0 42px; width:42px; height:42px;
        border-radius:12px; color:#1d5fa8; background:#eaf2fc; font-size:20px;
    }
    .student-action strong{display:block; margin:2px 0 6px; color:#1e293b; font-size:14px}
    .student-action span{display:block; color:#64748b; font-size:12px; line-height:1.6}

    @media (max-width:1100px){
        .student-stat-grid{grid-template-columns:repeat(2,minmax(0,1fr))}
        .student-duo{grid-template-columns:1fr}
    }
    @media (max-width:640px){
        .student-welcome,.student-panel{padding:20px}
        .student-stat-grid{grid-template-columns:1fr}
        .student-stat-card{padding:18px}
        .stepper{flex-direction:column; gap:18px}
        .step{display:flex; align-items:center; gap:14px; text-align:left}
        .step:not(:last-child)::after{display:none}
        .step-dot{margin:0; flex-shrink:0}
    }
    @media (prefers-reduced-motion:reduce){ .student-action{transition:none} .student-action:hover{transform:none} }
</style>

<div class="student-dashboard">

    {{-- SAPAAN --}}
    <section class="student-welcome">
        <span class="welcome-label">SIMASTA · BPS KOTA BATU</span>
        <h1>Selamat Datang, {{ auth()->user()->name ?? 'Mahasiswa' }} 👋</h1>
        <p>Pantau pengajuan dan kelola kegiatan magangmu melalui satu dashboard SIMASTA.</p>
    </section>

    {{-- TAHAPAN PENGAJUAN --}}
    <section>
        <h2 class="student-section-title">Tahapan Pengajuan</h2>
        <p class="student-section-description">Pantau sampai tahap mana pengajuan magang kamu berjalan.</p>

        <div class="stepper">
            @foreach($steps as $i => $s)
                @php
                    $cls = '';
                    if ($status === 'diterima' && $i === 3)       $cls = 'done';
                    elseif ($status === 'ditolak' && $i === 3)    $cls = 'rejected';
                    elseif ($i < $aktif)                          $cls = 'done';
                    elseif ($i === $aktif)                        $cls = 'current';
                @endphp
                <div class="step {{ $cls }}">
                    <div class="step-dot">
                        @if($cls === 'done') <i class="bi bi-check-lg"></i>
                        @elseif($cls === 'rejected') <i class="bi bi-x-lg"></i>
                        @else {{ $i + 1 }}
                        @endif
                    </div>
                    <div>
                        <b>{{ $s[0] }}</b>
                        <small>{{ $s[1] }}</small>
                    </div>
                </div>
            @endforeach
        </div>
    </section>

    {{-- BANNER STATUS --}}
    @if($status === 'diterima')
        <div class="student-alert ok">
            🎉 Selamat! Pengajuan magang kamu <b>diterima</b>. Menu Presensi, Posisi Magang, Logbook, dan Penilaian &amp; Sertifikat sudah terbuka.
        </div>
    @elseif($status === 'ditolak')
        <div class="student-alert bad">
            Mohon maaf, pengajuan magang kamu belum dapat kami terima.
            @if(!empty($pengajuan->catatan_admin))
                <br><b>Catatan admin:</b> {{ $pengajuan->catatan_admin }}
            @endif
        </div>
    @elseif($status === 'belum_diajukan')
        <div class="student-alert info">
            Kamu belum mengajukan magang. Mulai dari menu <b>Dokumen Magang</b>.
        </div>
    @endif

    {{-- RINGKASAN --}}
    <section>
        <h2 class="student-section-title">Ringkasan Magang</h2>
        <p class="student-section-description">Informasi singkat mengenai proses magang kamu saat ini.</p>

        <div class="student-stat-grid">

            <article class="student-stat-card">
                <div class="student-stat-top">
                    <span class="student-stat-label">Status Pengajuan</span>
                    <div class="student-stat-icon blue"><i class="bi bi-send"></i></div>
                </div>
                <h3 class="student-stat-value">{{ $labelStatus }}</h3>
                <p class="student-stat-note">{{ $catatanStatus }}</p>
            </article>

            <article class="student-stat-card">
                <div class="student-stat-top">
                    <span class="student-stat-label">Status Magang</span>
                    <div class="student-stat-icon green"><i class="bi bi-check2-circle"></i></div>
                </div>
                <h3 class="student-stat-value">{{ $statusMagang }}</h3>
                <p class="student-stat-note">
                    {{ $diterima ? 'Kamu sudah terdaftar sebagai peserta magang.' : 'Informasi aktif setelah pengajuan disetujui.' }}
                </p>
            </article>

            <article class="student-stat-card {{ $diterima ? '' : 'locked' }}">
                <div class="student-stat-top">
                    <span class="student-stat-label">Total Logbook</span>
                    <div class="student-stat-icon {{ $diterima ? 'orange' : 'gray' }}">
                        <i class="bi {{ $diterima ? 'bi-journal-text' : 'bi-lock-fill' }}"></i>
                    </div>
                </div>
                <h3 class="student-stat-value">{{ $diterima ? $totalLogbook.' Entri' : 'Terkunci' }}</h3>
                <p class="student-stat-note">
                    {{ $diterima ? 'Jumlah catatan kegiatan magang yang tersimpan.' : 'Terbuka setelah kamu lolos magang.' }}
                </p>
            </article>

            <article class="student-stat-card {{ $diterima ? '' : 'locked' }}">
                <div class="student-stat-top">
                    <span class="student-stat-label">Nilai Akhir</span>
                    <div class="student-stat-icon {{ $diterima ? 'purple' : 'gray' }}">
                        <i class="bi {{ $diterima ? 'bi-star' : 'bi-lock-fill' }}"></i>
                    </div>
                </div>
                <h3 class="student-stat-value">{{ $diterima ? ($nilaiAkhir ?? 'Belum Ada') : 'Terkunci' }}</h3>
                <p class="student-stat-note">
                    {{ $diterima ? 'Nilai dari admin dan pembimbing tampil setelah penilaian selesai.' : 'Terbuka setelah kamu lolos magang.' }}
                </p>
            </article>

        </div>
    </section>

    {{-- DUA KOLOM: berkas / progres + langkah berikutnya --}}
    <section class="student-duo">

        @if($diterima)
            <div class="student-panel">
                <div class="berkas-head">
                    <div class="ring" style="--p:{{ $progress ?? 0 }}"><div>{{ $progress ?? 0 }}%</div></div>
                    <div>
                        <h3>Progres Magang</h3>
                        <p class="student-section-description" style="margin:0">
                            @if($progress !== null)
                                Hari ke-{{ $hariKe }} dari {{ $totalHari }} hari.
                            @else
                                Periode magang belum ditetapkan admin.
                            @endif
                        </p>
                    </div>
                </div>
                <div class="berkas-item y"><i class="bi bi-calendar-event"></i><span>Periode</span><em>{{ $periode }}</em></div>
                <div class="berkas-item y"><i class="bi bi-journal-text"></i><span>Logbook terisi</span><em>{{ $totalLogbook }} entri</em></div>
            </div>
        @elseif($punyaDokumen)
            <div class="student-panel">
                <div class="berkas-head">
                    <div class="ring" style="--p:{{ round($jumlahLengkap / count($persyaratan) * 100) }}">
                        <div>{{ $jumlahLengkap }}/{{ count($persyaratan) }}</div>
                    </div>
                    <div>
                        <h3>Kelengkapan Berkas</h3>
                        <p class="student-section-description" style="margin:0">Lengkapi agar bisa diverifikasi admin.</p>
                    </div>
                </div>
                @foreach($persyaratan as $p)
                    @php $ada = in_array($p, $terunggah); @endphp
                    <div class="berkas-item {{ $ada ? 'y' : '' }}">
                        <i class="bi {{ $ada ? 'bi-check-circle-fill' : 'bi-circle' }}"></i>
                        <span>{{ $p }}</span>
                        <em>{{ $ada ? 'Terunggah' : 'Belum diunggah' }}</em>
                    </div>
                @endforeach
            </div>
        @endif

        <div class="student-panel student-next {{ $diterima ? 'ok' : '' }}" @if(!$diterima && !$punyaDokumen) style="grid-column:1/-1" @endif>
            <div>
                <h3>{{ $berikutnya[0] ?? 'Langkah berikutnya' }}</h3>
                <p>{{ $berikutnya[1] ?? '' }}</p>
            </div>
            @if(!empty($berikutnya[2]))
                <a href="{{ url($berikutnya[3]) }}">{{ $berikutnya[2] }}</a>
            @endif
        </div>

    </section>

    {{-- PENEMPATAN MAGANG --}}
    <section class="student-panel">
        <h2 class="student-section-title">Penempatan Magang</h2>
        <p class="student-section-description">Posisi dan pembimbing lapangan ditentukan oleh admin BPS Kota Batu.</p>

        <div class="student-table-wrap">
            <table class="student-table">
                <thead>
                    <tr>
                        <th>Informasi</th>
                        <th>Detail</th>
                        <th>Status</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>Instansi</td>
                        <td>{{ $instansi ?: 'BPS Kota Batu' }}</td>
                        <td><span class="student-status {{ $badgeClass }}">{{ $labelStatus }}</span></td>
                    </tr>
                    <tr>
                        <td>Posisi Magang</td>
                        <td>{{ $posisi ?: 'Belum ditentukan' }}</td>
                        <td>
                            <span class="student-status {{ $posisi ? 'ok' : 'neutral' }}">
                                {{ $posisi ? 'Sudah ditentukan' : 'Menunggu admin' }}
                            </span>
                        </td>
                    </tr>
                    <tr>
                        <td>Pembimbing Lapangan</td>
                        <td>{{ $pembimbing ?: 'Belum ditentukan' }}</td>
                        <td>
                            <span class="student-status {{ $pembimbing ? 'ok' : 'neutral' }}">
                                {{ $pembimbing ? 'Sudah ditetapkan' : 'Menunggu admin' }}
                            </span>
                        </td>
                    </tr>
                    <tr>
                        <td>Periode Magang</td>
                        <td>{{ $periode }}</td>
                        <td>
                            <span class="student-status {{ $periode !== '-' ? 'ok' : 'neutral' }}">
                                {{ $periode !== '-' ? 'Tersedia' : 'Belum tersedia' }}
                            </span>
                        </td>
                    </tr>
                </tbody>
            </table>
        </div>
    </section>

    {{-- AKSES CEPAT --}}
    <section>
        <h2 class="student-section-title">Akses Cepat</h2>
        <p class="student-section-description">Pilih menu untuk melanjutkan proses magang.</p>

        <div class="student-actions">
            @foreach($akses as [$href, $icon, $judul, $deskripsi])
                <a class="student-action" href="{{ url($href) }}">
                    <div class="student-action-icon"><i class="bi {{ $icon }}"></i></div>
                    <div>
                        <strong>{{ $judul }}</strong>
                        <span>{{ $deskripsi }}</span>
                    </div>
                </a>
            @endforeach
        </div>
    </section>

</div>

@endsection