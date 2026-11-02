{{-- resources/views/mahasiswa/surat.blade.php --}}
@extends('layouts.app')

@section('title', 'Surat Keterangan - SIMASTA')
@section('page-title', 'Surat Keterangan')

@section('sidebar')
    @include('layouts.mahasiswa')
@endsection

@section('user-role')
    Mahasiswa
@endsection

@section('user-avatar')
    {{ strtoupper(substr(auth()->user()->name ?? 'M', 0, 1)) }}
@endsection

@section('page-description', 'Ajukan dan unduh surat keterangan magang')

@section('content')

@php
    // Jenis surat yang bisa diajukan. Ubah sesuai surat yang benar-benar diterbitkan BPS Kota Batu.
    $jenisSurat = [
        'Surat Keterangan Magang',
        'Surat Balasan Permohonan Magang',
        'Surat Keterangan Selesai Magang',
    ];

    /*
     * $surat dikirim dari controller, berisi baris dengan kolom:
     *   jenis, keperluan, status (diajukan|diproses|terbit|ditolak), file (path PDF, boleh kosong), created_at
     * Contoh controller nanti:
     *   return view('mahasiswa.surat', ['surat' => auth()->user()->surat()->latest()->get()]);
     *
     * CONTOH di bawah hanya tampil saat APP_DEBUG=true, jadi tidak terlihat di server produksi.
     */
    $contoh = [
        ['jenis' => 'Contoh: Surat Keterangan Magang', 'keperluan' => 'Contoh keperluan', 'status' => 'terbit',   'file' => 'contoh.pdf', 'created_at' => now()->subDays(9)],
        ['jenis' => 'Contoh: Surat Balasan Permohonan Magang', 'keperluan' => 'Contoh keperluan', 'status' => 'diproses', 'file' => null, 'created_at' => now()->subDays(3)],
        ['jenis' => 'Contoh: Surat Keterangan Selesai Magang', 'keperluan' => 'Contoh keperluan', 'status' => 'diajukan', 'file' => null, 'created_at' => now()->subDay()],
    ];

    $daftar = collect($surat ?? (config('app.debug') ? $contoh : []))
        ->map(fn ($s) => (object) (is_array($s) ? $s : $s->toArray()));

    $labelStatus = ['diajukan' => 'Diajukan', 'diproses' => 'Diproses admin', 'terbit' => 'Sudah terbit', 'ditolak' => 'Ditolak'];
@endphp

<style>
    .sk-page{display:flex; flex-direction:column; gap:22px}
    .sk-hero{padding:28px 30px; border-radius:18px; border:1px solid #dbeafe; color:#16324f;
        background:linear-gradient(120deg,#d9f7eb 0%,#e8f1ff 60%,#dce9ff 100%)}
    .sk-hero h1{margin:0 0 8px; font-size:clamp(22px,3vw,28px); color:#183153}
    .sk-hero p{margin:0; color:#52677f; line-height:1.7}

    .sk-duo{display:grid; grid-template-columns:1.4fr 1fr; gap:16px; align-items:start}
    .sk-panel{padding:24px; background:#fff; border:1px solid #e5eaf1; border-radius:16px;
        box-shadow:0 4px 14px rgba(15,23,42,.035); min-width:0}
    .sk-title{margin:0 0 5px; color:#1e293b; font-size:18px}
    .sk-desc{margin:0 0 18px; color:#64748b; font-size:14px; line-height:1.6}

    .sk-field{margin-bottom:16px}
    .sk-field label{display:block; margin-bottom:7px; color:#334155; font-size:13px; font-weight:600}
    .sk-field select, .sk-field textarea{width:100%; padding:11px 13px; border:1px solid #d5dde8; border-radius:12px;
        background:#fff; color:#1e293b; font:inherit; font-size:14px}
    .sk-field select:focus, .sk-field textarea:focus{outline:2px solid #b7d4fa; border-color:#1d5fa8}
    .sk-btn{padding:12px 20px; border:0; border-radius:12px; background:linear-gradient(120deg,#1d5fa8,#3b82d9);
        color:#fff; font:inherit; font-weight:700; font-size:14px; cursor:pointer}
    .sk-btn:focus-visible{outline:2px solid #1d5fa8; outline-offset:3px}

    .sk-flow{list-style:none; margin:0; padding:0}
    .sk-flow li{display:flex; gap:12px; padding-bottom:16px; position:relative}
    .sk-flow li:last-child{padding-bottom:0}
    .sk-flow li:not(:last-child)::before{content:""; position:absolute; left:15px; top:32px; bottom:0; width:2px; background:#e3e8ef}
    .sk-flow i{display:grid; place-items:center; width:32px; height:32px; border-radius:50%; flex-shrink:0;
        background:#eaf2fc; color:#1d5fa8; font-style:normal; font-weight:700; font-size:13px}
    .sk-flow b{display:block; color:#1e293b; font-size:14px}
    .sk-flow span{color:#64748b; font-size:13px; line-height:1.55}

    .sk-wrap{width:100%; overflow-x:auto}
    .sk-table{width:100%; border-collapse:collapse; min-width:560px}
    .sk-table th{padding:13px 16px; background:#f8fafc; color:#64748b; text-align:left; font-size:12px;
        text-transform:uppercase; letter-spacing:.4px; border-bottom:1px solid #e2e8f0}
    .sk-table td{padding:15px 16px; color:#334155; font-size:14px; border-bottom:1px solid #edf2f7; vertical-align:middle}
    .sk-table tr:last-child td{border-bottom:none}
    .sk-chip{display:inline-flex; padding:5px 10px; border-radius:99px; font-size:12px; font-weight:650; white-space:nowrap}
    .sk-chip.diajukan{background:#fef3c7; color:#a16207}
    .sk-chip.diproses{background:#dbeafe; color:#1d4ed8}
    .sk-chip.terbit{background:#dcfce7; color:#166534}
    .sk-chip.ditolak{background:#fee2e2; color:#991b1b}
    .sk-dl{display:inline-flex; align-items:center; gap:6px; padding:7px 13px; border-radius:10px; background:#eaf2fc;
        color:#1d5fa8; font-size:13px; font-weight:700; text-decoration:none}
    .sk-dl:hover{background:#d9e8fb}
    .sk-dl:focus-visible{outline:2px solid #1d5fa8; outline-offset:2px}
    .sk-muted{color:#94a3b8; font-size:13px}

    .sk-empty{padding:40px 20px; text-align:center; color:#64748b}
    .sk-empty i{display:block; margin-bottom:10px; font-size:30px; color:#94a3b8}
    .sk-empty b{display:block; margin-bottom:4px; color:#1e293b}

    @media (max-width:980px){ .sk-duo{grid-template-columns:1fr} }
    @media (max-width:640px){ .sk-hero,.sk-panel{padding:20px} }
</style>

<div class="sk-page">

    <section class="sk-hero">
        <h1>Surat Keterangan</h1>
        <p>Ajukan surat yang kamu perlukan dan unduh setelah diterbitkan oleh admin BPS Kota Batu.</p>
    </section>

    <section class="sk-duo">

        {{-- FORM PENGAJUAN SURAT --}}
        <div class="sk-panel">
            <h2 class="sk-title">Ajukan Surat</h2>
            <p class="sk-desc">Pilih jenis surat dan tuliskan keperluannya.</p>

            <div class="sk-field">
                <label for="jenisSurat">Jenis Surat</label>
                <select id="jenisSurat">
                    <option value="">Pilih jenis surat</option>
                    @foreach($jenisSurat as $j)
                        <option>{{ $j }}</option>
                    @endforeach
                </select>
            </div>

            <div class="sk-field">
                <label for="keperluanSurat">Keperluan</label>
                <textarea id="keperluanSurat" rows="4" placeholder="Contoh: untuk persyaratan administrasi di kampus"></textarea>
            </div>

            <button type="button" class="sk-btn">Ajukan Surat</button>
        </div>

        {{-- ALUR --}}
        <div class="sk-panel">
            <h2 class="sk-title">Alur surat</h2>
            <p class="sk-desc">Dari pengajuan sampai bisa diunduh.</p>

            <ol class="sk-flow">
                <li><i>1</i><div><b>Kamu mengajukan</b><span>Pilih jenis surat dan isi keperluannya.</span></div></li>
                <li><i>2</i><div><b>Admin memproses</b><span>Admin BPS Kota Batu memeriksa dan menyiapkan surat.</span></div></li>
                <li><i>3</i><div><b>Surat terbit</b><span>Tombol Unduh muncul di riwayat di bawah.</span></div></li>
            </ol>
        </div>

    </section>

    {{-- RIWAYAT --}}
    <section class="sk-panel">
        <h2 class="sk-title">Riwayat Surat</h2>
        <p class="sk-desc">Daftar surat yang pernah kamu ajukan beserta statusnya.</p>

        @if($daftar->isEmpty())
            <div class="sk-empty">
                <i class="bi bi-envelope-paper"></i>
                <b>Belum ada pengajuan surat</b>
                Surat yang kamu ajukan akan muncul di sini.
            </div>
        @else
            <div class="sk-wrap">
                <table class="sk-table">
                    <thead>
                        <tr>
                            <th>Jenis Surat</th>
                            <th>Tanggal Ajukan</th>
                            <th>Status</th>
                            <th>Aksi</th>
                        </tr>
                    </thead>
                    <tbody>
                        @foreach($daftar as $s)
                            @php $st = $s->status ?? 'diajukan'; @endphp
                            <tr>
                                <td>{{ $s->jenis }}</td>
                                <td>{{ \Carbon\Carbon::parse($s->created_at)->translatedFormat('d M Y') }}</td>
                                <td><span class="sk-chip {{ $st }}">{{ $labelStatus[$st] ?? ucfirst($st) }}</span></td>
                                <td>
                                    @if($st === 'terbit' && !empty($s->file))
                                        <a class="sk-dl" href="{{ asset('storage/'.$s->file) }}" target="_blank" rel="noopener">
                                            <i class="bi bi-download"></i> Unduh
                                        </a>
                                    @else
                                        <span class="sk-muted">{{ $st === 'ditolak' ? 'Hubungi admin' : 'Menunggu' }}</span>
                                    @endif
                                </td>
                            </tr>
                        @endforeach
                    </tbody>
                </table>
            </div>
        @endif
    </section>

</div>

@endsection