{{-- resources/views/mahasiswa/bantuan.blade.php --}}
@extends('layouts.app')

@section('title', 'Bantuan - SIMASTA')
@section('page-title', 'Bantuan')

@section('sidebar')
    @include('layouts.mahasiswa')
@endsection

@section('user-role')
    Mahasiswa
@endsection

@section('user-avatar')
    {{ strtoupper(substr(auth()->user()->name ?? 'M', 0, 1)) }}
@endsection

@section('page-description', 'Panduan penggunaan SIMASTA dan kontak admin')

@section('content')

@php
    // ISI sesuai kontak resmi BPS Kota Batu. Baris yang null tidak ditampilkan.
    $kontak = [
        'email'    => null,   // contoh: 'admin@domain.go.id'
        'whatsapp' => null,   // contoh: '6281234567890'
        'jam'      => 'Hari kerja, jam kerja kantor',
    ];

    $alur = [
        ['Pengajuan',         'Isi data dan unggah dokumen persyaratan di menu Dokumen Magang.'],
        ['Verifikasi Berkas', 'Admin memeriksa kelengkapan berkas yang kamu kirim.'],
        ['Seleksi',           'BPS Kota Batu menentukan peserta magang.'],
        ['Keputusan',         'Jika lolos, menu kegiatan terbuka dan admin menetapkan posisi serta pembimbing lapangan.'],
    ];

    $faq = [
        ['Kenapa beberapa menu terkunci?',
         'Presensi, Posisi Magang, Logbook, dan Penilaian & Sertifikat hanya terbuka setelah kamu dinyatakan lolos magang di BPS Kota Batu.'],
        ['Di mana saya melihat status pengajuan?',
         'Di halaman Beranda. Bagian Tahapan Pengajuan menunjukkan sampai tahap mana pengajuanmu berjalan.'],
        ['Siapa yang menentukan posisi magang dan pembimbing lapangan?',
         'Admin BPS Kota Batu. Setelah ditetapkan, informasinya tampil di menu Posisi Magang dan kamu tidak perlu mengisinya sendiri.'],
        ['Bagaimana format dokumen yang harus diunggah?',
         'Semua dokumen berformat PDF dengan ukuran maksimal 5 MB per file.'],
        ['Bagaimana cara mendapatkan sertifikat magang?',
         'Setelah penilaian dari admin dan pembimbing magang selesai, hasil nilai dan sertifikat tersedia di menu Penilaian & Sertifikat.'],
    ];

    $adaKontak = !empty($kontak['email']) || !empty($kontak['whatsapp']);
@endphp

<style>
    .bt-page{display:flex; flex-direction:column; gap:24px}
    .bt-hero{padding:28px 30px; border-radius:18px; border:1px solid #dbeafe; color:#16324f;
        background:linear-gradient(120deg,#d9f7eb 0%,#e8f1ff 60%,#dce9ff 100%)}
    .bt-hero h1{margin:0 0 8px; font-size:clamp(22px,3vw,28px); color:#183153}
    .bt-hero p{margin:0; color:#52677f; line-height:1.7}

    .bt-title{margin:0 0 5px; color:#1e293b; font-size:20px}
    .bt-desc{margin:0 0 18px; color:#64748b; font-size:14px; line-height:1.6}

    .bt-steps{display:grid; grid-template-columns:repeat(auto-fit,minmax(210px,1fr)); gap:14px}
    .bt-step{padding:20px; background:#fff; border:1px solid #e5eaf1; border-radius:16px}
    .bt-step i{display:grid; place-items:center; width:34px; height:34px; margin-bottom:12px; border-radius:50%;
        background:#eaf2fc; color:#1d5fa8; font-style:normal; font-weight:700}
    .bt-step b{display:block; margin-bottom:5px; color:#1e293b; font-size:15px}
    .bt-step span{color:#64748b; font-size:13px; line-height:1.6}

    .bt-duo{display:grid; grid-template-columns:1.5fr 1fr; gap:16px; align-items:start}
    .bt-panel{padding:24px; background:#fff; border:1px solid #e5eaf1; border-radius:16px;
        box-shadow:0 4px 14px rgba(15,23,42,.035)}

    .bt-faq details{border:1px solid #e5eaf1; border-radius:12px; margin-bottom:10px; background:#fff}
    .bt-faq details:last-child{margin-bottom:0}
    .bt-faq summary{display:flex; justify-content:space-between; align-items:center; gap:12px; padding:15px 16px;
        cursor:pointer; list-style:none; color:#1e293b; font-weight:600; font-size:14px}
    .bt-faq summary::-webkit-details-marker{display:none}
    .bt-faq summary::after{content:"+"; flex-shrink:0; color:#1d5fa8; font-size:20px; line-height:1}
    .bt-faq details[open] summary::after{content:"\2212"}
    .bt-faq details[open]{border-color:#b7d4fa; background:#f8fbff}
    .bt-faq summary:focus-visible{outline:2px solid #1d5fa8; outline-offset:2px; border-radius:12px}
    .bt-faq p{margin:0; padding:0 16px 16px; color:#64748b; font-size:14px; line-height:1.7}

    .bt-contact{color:#fff; border:0; background:linear-gradient(130deg,#1d5fa8,#3b82d9)}
    .bt-contact h3{margin:0 0 6px; font-size:18px}
    .bt-contact p{margin:0 0 16px; opacity:.92; line-height:1.65; font-size:14px}
    .bt-row{display:flex; align-items:center; gap:12px; padding:12px 14px; margin-bottom:10px;
        border-radius:12px; background:rgba(255,255,255,.14); color:#fff; text-decoration:none; font-size:14px}
    .bt-row i{font-size:18px; flex-shrink:0}
    a.bt-row:hover{background:rgba(255,255,255,.22)}
    a.bt-row:focus-visible{outline:2px solid #fff; outline-offset:2px}

    @media (max-width:980px){ .bt-duo{grid-template-columns:1fr} }
    @media (max-width:640px){ .bt-hero,.bt-panel{padding:20px} }
</style>

<div class="bt-page">

    <section class="bt-hero">
        <h1>Bantuan</h1>
        <p>Panduan singkat memakai SIMASTA dan cara menghubungi admin BPS Kota Batu.</p>
    </section>

    <section>
        <h2 class="bt-title">Alur magang di SIMASTA</h2>
        <p class="bt-desc">Empat tahap yang akan kamu lalui, dari pengajuan sampai keputusan.</p>

        <div class="bt-steps">
            @foreach($alur as $i => $a)
                <div class="bt-step">
                    <i>{{ $i + 1 }}</i>
                    <b>{{ $a[0] }}</b>
                    <span>{{ $a[1] }}</span>
                </div>
            @endforeach
        </div>
    </section>

    <section class="bt-duo">

        <div class="bt-panel">
            <h2 class="bt-title">Pertanyaan yang sering diajukan</h2>
            <p class="bt-desc">Klik pertanyaan untuk melihat jawabannya.</p>

            <div class="bt-faq">
                @foreach($faq as $f)
                    <details>
                        <summary>{{ $f[0] }}</summary>
                        <p>{{ $f[1] }}</p>
                    </details>
                @endforeach
            </div>
        </div>

        <div class="bt-panel bt-contact">
            <h3>Masih butuh bantuan?</h3>
            <p>Hubungi admin SIMASTA. Sebutkan nama dan NIM-mu supaya lebih cepat dibantu.</p>

            @if(!empty($kontak['email']))
                <a class="bt-row" href="mailto:{{ $kontak['email'] }}">
                    <i class="bi bi-envelope"></i><span>{{ $kontak['email'] }}</span>
                </a>
            @endif

            @if(!empty($kontak['whatsapp']))
                <a class="bt-row" href="https://wa.me/{{ preg_replace('/\D/', '', $kontak['whatsapp']) }}" target="_blank" rel="noopener">
                    <i class="bi bi-whatsapp"></i><span>Chat WhatsApp admin</span>
                </a>
            @endif

            @unless($adaKontak)
                <div class="bt-row">
                    <i class="bi bi-building"></i><span>Datang ke sekretariat BPS Kota Batu pada jam kerja.</span>
                </div>
            @endunless

            @if(!empty($kontak['jam']))
                <div class="bt-row">
                    <i class="bi bi-clock"></i><span>{{ $kontak['jam'] }}</span>
                </div>
            @endif
        </div>

    </section>

</div>

@endsection