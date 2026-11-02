@extends('layouts.app')

@section('title', 'Pengumuman - SIMASTA')
@section('page-title', 'Pengumuman')

@section('sidebar')
    @include('layouts.mahasiswa')
@endsection

@section('user-role')
    Mahasiswa
@endsection

@section('user-avatar')
    {{ strtoupper(substr(auth()->user()->name ?? 'M', 0, 1)) }}
@endsection

@section('page-description', 'Informasi resmi dari BPS Kota Batu')

@section('content')

@php
    /*
     * $pengumuman dikirim dari controller, berisi baris dengan kolom:
     *   judul, isi, kategori, tanggal (created_at), penting (boolean)
     * Contoh controller nanti:
     *   return view('mahasiswa.pengumuman', ['pengumuman' => Pengumuman::latest()->get()]);
     *
     * Selama belum ada tabelnya, CONTOH di bawah hanya tampil saat APP_DEBUG=true,
     * jadi tidak akan terlihat oleh mahasiswa di server produksi.
     */
    $contoh = [
        ['judul' => 'Contoh: Jadwal pemeriksaan berkas', 'isi' => 'Ini hanya contoh tampilan. Isi pengumuman asli dibuat admin dari website admin.', 'kategori' => 'Seleksi', 'tanggal' => now()->subDays(1), 'penting' => true],
        ['judul' => 'Contoh: Pengumuman umum', 'isi' => 'Contoh teks pengumuman umum untuk seluruh peserta dan calon peserta magang.', 'kategori' => 'Umum', 'tanggal' => now()->subDays(6), 'penting' => false],
        ['judul' => 'Contoh: Informasi kegiatan', 'isi' => 'Contoh informasi kegiatan magang yang diumumkan oleh admin.', 'kategori' => 'Kegiatan', 'tanggal' => now()->subDays(12), 'penting' => false],
    ];

    $daftar = collect($pengumuman ?? (config('app.debug') ? $contoh : []))
        ->map(fn ($p) => (object) (is_array($p) ? $p : $p->toArray()))
        ->sortByDesc(fn ($p) => [(bool) ($p->penting ?? false), $p->tanggal ?? $p->created_at ?? null])
        ->values();

    $kategori = $daftar->pluck('kategori')->filter()->unique()->values();
@endphp

<style>
    .pg-page{display:flex; flex-direction:column; gap:22px}
    .pg-hero{padding:28px 30px; border-radius:18px; border:1px solid #dbeafe; color:#16324f;
        background:linear-gradient(120deg,#d9f7eb 0%,#e8f1ff 60%,#dce9ff 100%)}
    .pg-hero h1{margin:0 0 8px; font-size:clamp(22px,3vw,28px); color:#183153}
    .pg-hero p{margin:0; color:#52677f; line-height:1.7}

    .pg-filter{display:flex; flex-wrap:wrap; gap:8px}
    .pg-chip{padding:8px 15px; border:1px solid #e5eaf1; border-radius:99px; background:#fff; color:#475569;
        font:inherit; font-size:13px; font-weight:600; cursor:pointer; transition:.2s}
    .pg-chip:hover{border-color:#b7d4fa}
    .pg-chip[aria-pressed="true"]{background:#1d5fa8; border-color:#1d5fa8; color:#fff}
    .pg-chip:focus-visible{outline:2px solid #1d5fa8; outline-offset:2px}

    .pg-list{display:flex; flex-direction:column; gap:12px}
    .pg-item{display:flex; gap:16px; padding:20px; background:#fff; border:1px solid #e5eaf1; border-radius:16px;
        box-shadow:0 4px 14px rgba(15,23,42,.035)}
    .pg-item.penting{border-left:5px solid #f5a65b}
    .pg-date{flex-shrink:0; width:58px; text-align:center; padding:8px 0; border-radius:12px; background:#eaf2fc; color:#1d5fa8}
    .pg-date b{display:block; font-size:20px; line-height:1.1}
    .pg-date span{font-size:11px; font-weight:600}
    .pg-body{min-width:0}
    .pg-meta{display:flex; flex-wrap:wrap; align-items:center; gap:8px; margin-bottom:6px}
    .pg-tag{padding:3px 10px; border-radius:99px; background:#f1f5f9; color:#475569; font-size:11px; font-weight:700}
    .pg-tag.warn{background:#fff1de; color:#8a4a00}
    .pg-item h3{margin:0 0 6px; color:#1e293b; font-size:16px; line-height:1.4}
    .pg-item p{margin:0; color:#64748b; font-size:14px; line-height:1.7; overflow-wrap:anywhere}

    .pg-empty{padding:48px 20px; text-align:center; background:#fff; border:1px dashed #cbd5e1; border-radius:16px; color:#64748b}
    .pg-empty i{display:block; margin-bottom:10px; font-size:32px; color:#94a3b8}
    .pg-empty b{display:block; margin-bottom:4px; color:#1e293b}

    @media (max-width:640px){
        .pg-hero{padding:20px}
        .pg-item{flex-direction:column; gap:12px}
        .pg-date{width:auto; align-self:flex-start; padding:6px 14px}
    }
</style>

<div class="pg-page">

    <section class="pg-hero">
        <h1>Pengumuman</h1>
        <p>Informasi resmi dari BPS Kota Batu seputar seleksi dan kegiatan magang.</p>
    </section>

    @if($daftar->isEmpty())

        <div class="pg-empty">
            <i class="bi bi-megaphone"></i>
            <b>Belum ada pengumuman</b>
            Pengumuman dari admin akan muncul di sini.
        </div>

    @else

        @if($kategori->count() > 1)
            <div class="pg-filter" role="group" aria-label="Filter kategori">
                <button type="button" class="pg-chip" data-filter="" aria-pressed="true">Semua</button>
                @foreach($kategori as $k)
                    <button type="button" class="pg-chip" data-filter="{{ $k }}" aria-pressed="false">{{ $k }}</button>
                @endforeach
            </div>
        @endif

        <div class="pg-list" id="pgList">
            @foreach($daftar as $p)
                @php
                    $tgl = \Carbon\Carbon::parse($p->tanggal ?? $p->created_at ?? now());
                @endphp
                <article class="pg-item {{ !empty($p->penting) ? 'penting' : '' }}" data-kategori="{{ $p->kategori ?? '' }}">
                    <div class="pg-date" aria-hidden="true">
                        <b>{{ $tgl->format('d') }}</b>
                        <span>{{ $tgl->translatedFormat('M Y') }}</span>
                    </div>
                    <div class="pg-body">
                        <div class="pg-meta">
                            @if(!empty($p->kategori)) <span class="pg-tag">{{ $p->kategori }}</span> @endif
                            @if(!empty($p->penting)) <span class="pg-tag warn">Penting</span> @endif
                            <time datetime="{{ $tgl->toDateString() }}" style="font-size:12px;color:#94a3b8">{{ $tgl->translatedFormat('d F Y') }}</time>
                        </div>
                        <h3>{{ $p->judul }}</h3>
                        <p>{{ $p->isi }}</p>
                    </div>
                </article>
            @endforeach
        </div>

    @endif

</div>

<script>
(function () {
    var chips = document.querySelectorAll('.pg-chip');
    var items = document.querySelectorAll('#pgList .pg-item');
    chips.forEach(function (chip) {
        chip.addEventListener('click', function () {
            var f = chip.dataset.filter;
            chips.forEach(function (c) { c.setAttribute('aria-pressed', c === chip ? 'true' : 'false'); });
            items.forEach(function (it) {
                it.style.display = (!f || it.dataset.kategori === f) ? '' : 'none';
            });
        });
    });
})();
</script>

@endsection