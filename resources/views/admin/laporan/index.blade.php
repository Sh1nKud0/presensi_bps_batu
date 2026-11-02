@extends('layouts.admin')

@section('title', 'Laporan - SIMASTA')

@section('page-title', 'Laporan')

@section('user-role', 'Admin')

@section('user-avatar', 'A')

@section('sidebar')
    @include('layouts.admin')
@endsection

@section('content')

<div class="card">

    <div style="margin-bottom:25px;">
        <h2>Laporan Magang</h2>
        <p>Kelola dan lihat laporan kegiatan magang mahasiswa.</p>
    </div>

    <div style="
        display:grid;
        grid-template-columns:repeat(auto-fit, minmax(220px, 1fr));
        gap:20px;
    ">

        <div class="card" style="margin:0;">
            <h3>Data Mahasiswa</h3>
            <p>Rekap data mahasiswa magang.</p>
            <span class="badge badge-warning">
                Lihat Laporan
            </button>
        </div>

        <div class="card" style="margin:0;">
            <h3>Pengajuan Magang</h3>
            <p>Rekap pengajuan magang mahasiswa.</p>
            <span class="badge badge-warning">
                Lihat Laporan
            </button>
        </div>

        <div class="card" style="margin:0;">
            <h3>Logbook</h3>
            <p>Rekap kegiatan mahasiswa selama magang.</p>
            <span class="badge badge-warning">
                Lihat Laporan
            </button>
        </div>

        <div class="card" style="margin:0;">
            <h3>Penilaian</h3>
            <p>Rekap hasil penilaian mahasiswa.</p>
            <span class="badge badge-warning">
                Lihat Laporan
            </button>
        </div>

    </div>

</div>

@endsection