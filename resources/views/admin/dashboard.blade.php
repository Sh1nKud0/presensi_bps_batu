@extends('layouts.admin')

@section('title', 'Dashboard Admin - SIMASTA')
@section('page-title', 'Dashboard Admin')
@section('user-role', 'Admin')

@section('user-avatar')
    {{ strtoupper(substr(auth()->user()->name ?? 'A', 0, 1)) }}
@endsection

@section('content')

@php
    use App\Models\Mahasiswa;
    use App\Models\Pengajuan;
    use App\Models\User;

    $totalMahasiswa = Mahasiswa::count();
    $totalPengajuan = Pengajuan::count();
    $menunggu       = Pengajuan::whereIn('status', ['diproses', 'diverifikasi'])->count();
    $diterima       = Pengajuan::where('status', 'diterima')->count();
    $ditolak        = Pengajuan::where('status', 'ditolak')->count();
    $pembimbing     = User::where('role', 'pembimbing')->count();

    $terbaru = Pengajuan::with('user')->latest()->take(5)->get();

    // grafik pengajuan per bulan (tahun ini)
    $perBulan = Pengajuan::whereYear('created_at', now()->year)->get()
                    ->groupBy(fn ($p) => $p->created_at->month);
    $namaBulan = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    $dataBulan = [];
    foreach (range(1, 12) as $m) {
        $dataBulan[] = isset($perBulan[$m]) ? $perBulan[$m]->count() : 0;
    }
    $maks = max(max($dataBulan), 1);

    $badge = [
        'diproses'     => ['badge-warning', 'Menunggu'],
        'diverifikasi' => ['badge-info',    'Terverifikasi'],
        'diterima'     => ['badge-success', 'Diterima'],
        'ditolak'      => ['badge-danger',  'Ditolak'],
    ];
@endphp

<style>
    .adm-welcome{
        position:relative; overflow:hidden; padding:30px; border-radius:18px;
        margin-bottom:24px; border:1px solid #dbeafe; color:#16324f;
        background:linear-gradient(120deg,#d9f7eb 0%,#e8f1ff 60%,#dce9ff 100%);
    }
    .adm-welcome::after{content:""; position:absolute; width:180px; height:180px;
        right:-45px; top:-70px; border-radius:50%; background:rgba(245,166,91,.18)}
    .adm-label{display:inline-block; padding:6px 12px; margin-bottom:14px; border-radius:20px;
        color:#18794e; background:rgba(255,255,255,.8); font-size:12px; font-weight:700; letter-spacing:.5px}
    .adm-welcome h1{margin:0 0 10px; font-size:clamp(23px,3vw,30px); line-height:1.35; color:#183153}
    .adm-welcome p{margin:0; color:#52677f; line-height:1.7}

    /* kartu statistik dengan ikon */
    .stat-row{display:flex; align-items:center; justify-content:space-between; gap:12px}
    .stat-ico{display:grid; place-items:center; width:46px; height:46px; border-radius:13px;
        color:#fff; font-size:21px; flex-shrink:0; box-shadow:0 6px 14px rgba(0,0,0,.15)}
    .stat-ico.blue{background:linear-gradient(135deg,#60a5fa,#3b82f6)}
    .stat-ico.green{background:linear-gradient(135deg,#34d399,#10b981)}
    .stat-ico.orange{background:linear-gradient(135deg,#fb923c,#f97316)}
    .stat-ico.purple{background:linear-gradient(135deg,#a78bfa,#7c3aed)}
    .stat-card .number{margin-bottom:4px}
    .stat-card h3{margin-bottom:10px}

    .section-gap{margin-bottom:20px}
    .head-row{display:flex; align-items:flex-start; justify-content:space-between; gap:16px}
    .desc{color:#64748b; font-size:14px; margin-bottom:18px}
    .link-all{color:#3b82f6; font-weight:600; font-size:14px; text-decoration:none; white-space:nowrap}
    .link-all:hover{color:#f97316}

    /* ringkasan status */
    .sum-row{display:flex; align-items:center; gap:12px; padding:11px 0; border-bottom:1px solid #f1f5f9}
    .sum-row:last-child{border-bottom:none}
    .sum-dot{width:12px; height:12px; border-radius:50%; flex-shrink:0}
    .sum-row span{flex:1; color:#475569; font-size:14px}
    .sum-row b{color:#1e293b}

    .trend-chart{height:170px}
    .trend-bar.zero{background:#e3e8ef}

    .btn-detail{display:inline-block; padding:8px 14px; border-radius:10px; font-size:13px; font-weight:600;
        text-decoration:none; color:#1d5fa8; background:#eaf2fc; transition:.2s}
    .btn-detail:hover{background:#f5a65b; color:#fff}

    .empty-row{text-align:center; padding:30px 10px; color:#94a3b8}
    .empty-row i{font-size:32px; display:block; margin-bottom:8px}

    @media (max-width:640px){ .adm-welcome{padding:20px} }
</style>

{{-- SAPAAN --}}
<section class="adm-welcome">
    <span class="adm-label">SIMASTA · BPS KOTA BATU</span>
    <h1>Selamat Datang, {{ auth()->user()->name ?? 'Admin' }} 👋</h1>
    <p>Pantau pendaftaran dan seleksi peserta magang BPS Kota Batu dari satu tempat.</p>
</section>

{{-- STATISTIK --}}
<div class="card-grid section-gap">

    <div class="card stat-card" style="margin-bottom:0">
        <div class="stat-row">
            <div>
                <h3>Total Mahasiswa</h3>
                <div class="number">{{ $totalMahasiswa }}</div>
                <p>Mahasiswa terdaftar</p>
            </div>
            <div class="stat-ico blue"><i class="bi bi-people"></i></div>
        </div>
    </div>

    <div class="card stat-card" style="margin-bottom:0">
        <div class="stat-row">
            <div>
                <h3>Pengajuan Magang</h3>
                <div class="number">{{ $totalPengajuan }}</div>
                <p>Total pengajuan</p>
            </div>
            <div class="stat-ico green"><i class="bi bi-inbox"></i></div>
        </div>
    </div>

    <div class="card stat-card" style="margin-bottom:0">
        <div class="stat-row">
            <div>
                <h3>Menunggu Verifikasi</h3>
                <div class="number">{{ $menunggu }}</div>
                <p>Pengajuan perlu diperiksa</p>
            </div>
            <div class="stat-ico orange"><i class="bi bi-hourglass-split"></i></div>
        </div>
    </div>

    <div class="card stat-card" style="margin-bottom:0">
        <div class="stat-row">
            <div>
                <h3>Pembimbing</h3>
                <div class="number">{{ $pembimbing }}</div>
                <p>Pembimbing lapangan</p>
            </div>
            <div class="stat-ico purple"><i class="bi bi-person-badge"></i></div>
        </div>
    </div>

</div>

{{-- GRAFIK + STATUS --}}
<div class="grid-2 section-gap">

    <div class="card" style="margin-bottom:0">
        <div class="panel-head">
            <div>
                <h2><i class="bi bi-graph-up-arrow" style="color:#3b82f6"></i> Tren Pengajuan {{ now()->year }}</h2>
                <p class="desc" style="margin-bottom:0">Jumlah pengajuan magang setiap bulan.</p>
            </div>
            <div style="text-align:right">
                <div class="total">{{ $totalPengajuan }}</div>
                <small style="color:#94a3b8">TOTAL</small>
            </div>
        </div>

        <div class="trend-chart">
            @foreach($dataBulan as $i => $n)
                <div class="trend-bar-wrap">
                    <div class="trend-bar {{ $n === 0 ? 'zero' : '' }} {{ $i + 1 === now()->month ? 'is-current' : '' }}"
                         style="height:{{ $n === 0 ? 4 : max(14, round(($n / $maks) * 120)) }}px">
                        @if($n > 0)<span class="val">{{ $n }}</span>@endif
                    </div>
                    <span class="trend-year">{{ $namaBulan[$i] }}</span>
                </div>
            @endforeach
        </div>
    </div>

    <div class="card" style="margin-bottom:0">
        <h2>Status Pengajuan</h2>
        <p class="desc">Sebaran seluruh pengajuan.</p>

        <div class="sum-row"><i class="sum-dot" style="background:#fb923c"></i><span>Menunggu</span><b>{{ $menunggu }}</b></div>
        <div class="sum-row"><i class="sum-dot" style="background:#10b981"></i><span>Diterima</span><b>{{ $diterima }}</b></div>
        <div class="sum-row"><i class="sum-dot" style="background:#dc2626"></i><span>Ditolak</span><b>{{ $ditolak }}</b></div>
        <div class="sum-row"><i class="sum-dot" style="background:#3b82f6"></i><span>Total</span><b>{{ $totalPengajuan }}</b></div>
    </div>

</div>

{{-- PENGAJUAN TERBARU --}}
<div class="card">

    <div class="head-row">
        <div>
            <h2>Pengajuan Terbaru</h2>
            <p class="desc">5 pengajuan magang mahasiswa terakhir.</p>
        </div>
        <a href="/admin/pengajuan" class="link-all">Lihat semua →</a>
    </div>

    <div class="table-container">
        <table>
            <thead>
                <tr>
                    <th>No</th>
                    <th>Mahasiswa</th>
                    <th>Kampus</th>
                    <th>Tanggal</th>
                    <th>Status</th>
                    <th>Aksi</th>
                </tr>
            </thead>
            <tbody>
                @forelse($terbaru as $i => $p)
                    @php [$kelas, $teks] = $badge[$p->status] ?? ['badge-warning', ucfirst($p->status)]; @endphp
                    <tr>
                        <td>{{ $i + 1 }}</td>
                        <td>{{ $p->user->name ?? '-' }}</td>
                        <td>{{ $p->user->mahasiswa->kampus ?? '-' }}</td>
                        <td>{{ $p->created_at->translatedFormat('d M Y') }}</td>
                        <td><span class="badge {{ $kelas }}">{{ $teks }}</span></td>
                        <td><a href="/admin/pengajuan/{{ $p->id }}" class="btn-detail">Detail</a></td>
                    </tr>
                @empty
                    <tr>
                        <td colspan="6">
                            <div class="empty-row">
                                <i class="bi bi-inbox"></i>
                                Belum ada pengajuan masuk.
                            </div>
                        </td>
                    </tr>
                @endforelse
            </tbody>
        </table>
    </div>

</div>

{{-- INFORMASI SISTEM --}}
<div class="card">

    <h2>Informasi Sistem</h2>
    <br>

    <div class="info-list">
        <div class="info-item">
            <span>Sistem</span>
            <strong>SIMASTA</strong>
        </div>

        <div class="info-item">
            <span>Instansi</span>
            <strong>BPS Kota Batu</strong>
        </div>

        <div class="info-item">
            <span>Status Sistem</span>
            <span class="badge badge-success">Aktif</span>
        </div>
    </div>

</div>

@endsection