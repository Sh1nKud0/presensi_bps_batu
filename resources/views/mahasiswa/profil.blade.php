@extends('layouts.app')

@section('title', 'Profil Saya - SIMASTA')
@section('page-title', 'Profil Saya')
@section('user-role', 'Mahasiswa')

@section('user-avatar')
    {{ strtoupper(substr(auth()->user()->name ?? 'M', 0, 1)) }}
@endsection

@section('sidebar')
    @include('layouts.mahasiswa')
@endsection

@section('content')

@php
    $m         = $mhs ?? null;
    $pengajuan = $user->pengajuan;
    $status    = $user->statusMagang();
    $diterima  = $status === 'diterima';

    $v    = fn ($k) => old($k, $m->$k ?? '');
    $foto = !empty($m->foto) ? asset('storage/'.$m->foto) : null;

    // kolom yang dihitung untuk kelengkapan profil
    $f = ['jenis_kelamin','no_telepon','perguruan_tinggi','program_studi',
          'alamat_kampus','nim','semester','dosen_pembimbing','foto'];
    $terisi = collect($f)->filter(fn ($k) => filled($m->$k ?? null))->count();
    $persen = (int) round($terisi / count($f) * 100);

    $label = [
        'belum_diajukan' => ['Calon Peserta',        ''],
        'diproses'       => ['Pengajuan Diproses',   'info'],
        'diverifikasi'   => ['Berkas Terverifikasi', 'info'],
        'diterima'       => ['Peserta Magang',       'ok'],
        'ditolak'        => ['Pengajuan Ditolak',    'bad'],
    ][$status] ?? ['Calon Peserta', ''];
@endphp

<style>
    body{background:#fff}

    .pf-tabs{display:inline-flex; gap:6px; padding:5px; margin-bottom:20px; background:#eef2f7; border-radius:14px}
    .pf-tab{display:flex; align-items:center; gap:8px; padding:10px 20px; border:0; border-radius:10px;
        background:transparent; color:#64748b; font-size:14px; font-weight:700; font-family:inherit; cursor:pointer; transition:.2s}
    .pf-tab.on{background:#fff; color:#1d5fa8; box-shadow:0 2px 10px rgba(15,23,42,.1)}
    .pf-panel{display:none}
    .pf-panel.on{display:block}

    /* kartu putih besar */
    .pf-wrap{max-width:1040px; margin:0 auto; background:#fff; border:1px solid #e5eaf1; border-radius:20px;
        box-shadow:0 8px 30px rgba(15,23,42,.06); overflow:hidden}
    .pf-bar-top{height:5px; background:linear-gradient(90deg,#34d399,#60a5fa,#fb923c)}
    .pf{display:grid; grid-template-columns:280px minmax(0,1fr); gap:0}

    /* kolom kiri */
    .pf-side{padding:32px 24px; text-align:center; border-right:1px solid #edf2f7}
    .pf-photo{position:relative; width:128px; height:128px; margin:0 auto 16px}
    .pf-photo .img{width:128px; height:128px; border-radius:50%; overflow:hidden; display:grid; place-items:center;
        font-size:48px; font-weight:700; color:#fff; border:4px solid #eaf2fc;
        background:linear-gradient(135deg,#2fa266,#1d5fa8); box-shadow:0 10px 24px rgba(29,95,168,.25)}
    .pf-photo .img img{width:100%; height:100%; object-fit:cover}
    .pf-photo label{display:none; position:absolute; right:2px; bottom:2px; width:38px; height:38px; place-items:center;
        border-radius:50%; cursor:pointer; color:#fff; font-size:17px; border:3px solid #fff;
        background:linear-gradient(120deg,#f5a65b,#ee8a3a); box-shadow:0 4px 10px rgba(238,138,58,.4); transition:.2s}
    .pf-photo label:hover{transform:scale(1.08)}
    .pf-photo input{display:none}
    .pf-hint{display:none; font-size:11.5px; color:#94a3b8; margin:-6px 0 14px}
    .pf-wrap.editing .pf-photo label{display:grid}
    .pf-wrap.editing .pf-hint{display:block}

    .pf-side h2{margin:0 0 4px; font-size:19px; color:#183153}
    .pf-mail{font-size:13px; color:#64748b; word-break:break-all; margin-bottom:14px}
    .pf-status{display:inline-flex; align-items:center; gap:6px; padding:7px 14px; border-radius:20px;
        font-size:12px; font-weight:700; color:#a16207; background:#fef3c7}
    .pf-status.ok{color:#166534; background:#dcfce7}
    .pf-status.bad{color:#991b1b; background:#fee2e2}
    .pf-status.info{color:#1d5fa8; background:#dbeafe}

    .pf-mini{margin-top:20px; padding-top:18px; border-top:1px dashed #e2e8f0; text-align:left; display:grid; gap:10px}
    .pf-mini div{display:flex; align-items:center; gap:10px; font-size:13px; color:#475569}
    .pf-mini i{display:grid; place-items:center; width:30px; height:30px; border-radius:9px; flex-shrink:0;
        color:#1d5fa8; background:#eaf2fc; font-size:14px}
    .pf-mini span{min-width:0; overflow-wrap:anywhere}

    .pf-progress{margin-top:20px; text-align:left}
    .pf-progress-top{display:flex; justify-content:space-between; font-size:12px; font-weight:700; color:#475569; margin-bottom:8px}
    .pf-bar{height:9px; border-radius:20px; background:#e8edf3; overflow:hidden}
    .pf-bar i{display:block; height:100%; border-radius:20px; background:linear-gradient(90deg,#f5a65b,#2fa266)}
    .pf-progress small{display:block; margin-top:8px; font-size:11.5px; color:#94a3b8; line-height:1.5}

    /* kolom kanan */
    .pf-form{padding:32px 36px}
    .pf-head{display:flex; align-items:center; justify-content:space-between; gap:12px;
        margin-bottom:22px; padding-bottom:16px; border-bottom:1px solid #edf2f7}
    .pf-title{display:flex; align-items:center; gap:10px; margin:0; font-size:17px; color:#183153}
    .pf-title i{display:grid; place-items:center; width:32px; height:32px; border-radius:10px; font-size:16px; color:#fff}
    .pf-title i.blue{background:linear-gradient(135deg,#3b82f6,#1d5fa8)}
    .pf-title i.orange{background:linear-gradient(135deg,#f5a65b,#ee8a3a)}

    .pf-edit{display:inline-flex; align-items:center; gap:6px; padding:8px 14px; border:0; border-radius:10px;
        background:#eaf2fc; color:#1d5fa8; font-size:14px; font-weight:700; font-family:inherit; cursor:pointer; transition:.2s}
    .pf-edit:hover{background:#f5a65b; color:#fff}
    .pf-wrap.editing .pf-edit{display:none}

    .pf-sec2{margin-top:26px; padding-top:24px; border-top:1px solid #edf2f7}
    .pf-sec2 .pf-title{margin-bottom:18px}

    /* kolom terkunci saat mode lihat */
    .pf-fs{border:0; padding:0; margin:0; min-width:0}
    .pf-fs:disabled input, .pf-fs:disabled select, .pf-fs:disabled textarea{
        background:#f8fafc; color:#475569; -webkit-text-fill-color:#475569; opacity:1;
        cursor:default; border-color:#e5eaf1}
    .pf-fs:disabled select{-webkit-appearance:none; appearance:none; background-image:none}
    .pf-fs:disabled .pf-req{display:none}

    .pf-grid{display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:16px}
    .pf-field{min-width:0}
    .pf-field.full{grid-column:1 / -1}
    .pf-field label.l{display:block; margin-bottom:6px; font-size:12.5px; font-weight:600; color:#334155}
    .pf-field label.l b{color:#dc2626}
    .pf-field input:not([type=file]), .pf-field select, .pf-field textarea{
        width:100%; padding:11px 14px; font-size:14px; font-family:inherit; color:#1e293b;
        background:#fff; border:1px solid #dbe3ec; border-radius:10px; outline:none; transition:.2s}
    .pf-field textarea{min-height:80px; resize:vertical; line-height:1.5}
    .pf-field input:focus, .pf-field select:focus, .pf-field textarea:focus{
        border-color:#f5a65b; box-shadow:0 0 0 4px rgba(245,166,91,.18)}
    .pf-field input[readonly]{background:#f1f5f9; color:#64748b; cursor:not-allowed}
    .pf-field small{display:block; margin-top:5px; font-size:11.5px; color:#94a3b8}
    .pf-err{margin-top:5px; font-size:12px; color:#dc2626}

/* tombol Batal + Simpan: hanya muncul saat mode edit */
.pf-foot{
    display:none;
    margin-top:28px;
    padding-top:20px;
    border-top:1px solid #edf2f7;
}
.pf-wrap.editing .pf-foot{
    display:flex;
    flex-direction:row;
    justify-content:flex-end;
    align-items:center;
    gap:10px;
    flex-wrap:wrap;
}

.pf-foot .pf-btn{
    all:unset;                      /* buang semua CSS bawaan layout */
    box-sizing:border-box;
    display:inline-flex;
    align-items:center;
    justify-content:center;
    gap:6px;
    flex:0 0 auto;                  /* jangan melebar / memanjang */
    width:auto;
    min-width:130px;
    height:42px;
    min-height:0;
    padding:0 22px;
    margin:0;
    border-radius:10px;
    font-family:inherit;
    font-size:13px;
    font-weight:700;
    line-height:1;
    white-space:nowrap;
    cursor:pointer;
    transition:.2s;
}
.pf-foot .pf-btn-cancel{color:#475569; background:#e8edf3}
.pf-foot .pf-btn-cancel:hover{background:#d9e0e8}
.pf-foot .pf-btn-save{
    color:#fff;
    background:linear-gradient(120deg,#f5a65b,#ee8a3a);
    box-shadow:0 6px 14px rgba(238,138,58,.3);
}
.pf-foot .pf-btn-save:hover{opacity:.92}

    /* popup notifikasi */
    .swal2-timer-progress-bar{background:#f5a65b !important}

    /* posisi magang */
    .pos{padding:32px 36px}
    .pos .pf-title{margin-bottom:18px}
    .pos-lock{text-align:center; padding:40px 20px}
    .pos-lock i{display:grid; place-items:center; width:74px; height:74px; margin:0 auto 16px;
        border-radius:50%; font-size:30px; color:#94a3b8; background:#eef2f7}
    .pos-lock h3{margin:0 0 8px; color:#183153}
    .pos-lock p{margin:0 auto; max-width:440px; color:#64748b; line-height:1.7; font-size:14px}
    .pos-grid{display:grid; grid-template-columns:repeat(2,minmax(0,1fr)); gap:14px}
    .pos-item{padding:16px; background:#f8fafc; border:1px solid #e5eaf1; border-radius:12px}
    .pos-item span{display:block; font-size:12px; color:#64748b; margin-bottom:6px}
    .pos-item strong{color:#1e293b; font-size:15px}

    @media (max-width:900px){
        .pf{grid-template-columns:1fr}
        .pf-side{border-right:0; border-bottom:1px solid #edf2f7}
    }
    @media (max-width:640px){
    .pf-form, .pos{padding:22px 18px}
    .pf-grid, .pos-grid{grid-template-columns:1fr}
    .pf-wrap.editing .pf-foot{flex-direction:column-reverse; align-items:stretch}
    .pf-foot .pf-btn{width:100%}
    }
</style>

@if($errors->any())
    <div class="pf-alert bad">
        <i class="bi bi-exclamation-circle"></i> Profil belum tersimpan:
        <ul style="margin:6px 0 0 18px">
            @foreach($errors->all() as $e)
                <li>{{ $e }}</li>
            @endforeach
        </ul>
    </div>
@endif

<div style="max-width:1040px; margin:0 auto">
    <div class="pf-tabs">
        <button type="button" class="pf-tab on" data-tab="profil"><i class="bi bi-person"></i> Data Profil</button>
        <button type="button" class="pf-tab" data-tab="posisi">
            <i class="bi {{ $diterima ? 'bi-people' : 'bi-lock-fill' }}"></i> Posisi Magang
        </button>
    </div>
</div>

{{-- ================= TAB PROFIL ================= --}}
<div class="pf-panel on" id="panel-profil">
<form class="pf-wrap" id="pfForm" data-err="{{ $errors->any() ? '1' : '0' }}"
      method="POST" action="/mahasiswa/profil" enctype="multipart/form-data">
    @csrf
    <div class="pf-bar-top"></div>

    <div class="pf">

        {{-- KOLOM KIRI --}}
        <aside class="pf-side">
            <div class="pf-photo">
                <div class="img" id="fotoBox">
                    @if($foto)
                        <img src="{{ $foto }}" alt="Foto profil">
                    @else
                        {{ strtoupper(substr($user->name ?? 'M', 0, 1)) }}
                    @endif
                </div>
                <label for="foto" title="Ganti foto"><i class="bi bi-camera-fill"></i></label>
                <input type="file" id="foto" name="foto" accept="image/png,image/jpeg,image/webp">
            </div>
            <div class="pf-hint">JPG, PNG, atau WEBP, maks. 2 MB</div>
            @error('foto')<div class="pf-err" style="margin:-8px 0 12px">{{ $message }}</div>@enderror

            <h2>{{ $user->name }}</h2>
            <div class="pf-mail">{{ $user->email }}</div>

            <span class="pf-status {{ $label[1] }}">
                <i class="bi {{ $diterima ? 'bi-patch-check-fill' : 'bi-hourglass-split' }}"></i>
                {{ $label[0] }}
            </span>

            <div class="pf-mini">
                <div><i class="bi bi-telephone"></i><span>{{ $m->no_telepon ?? '-' }}</span></div>
                <div><i class="bi bi-mortarboard"></i><span>{{ $m->perguruan_tinggi ?? 'Universitas belum diisi' }}</span></div>
                <div><i class="bi bi-book"></i><span>{{ $m->program_studi ?? 'Program studi belum diisi' }}</span></div>
                <div><i class="bi bi-person-badge"></i><span>{{ $m->nim ?? 'NIM belum diisi' }}</span></div>
            </div>

            <div class="pf-progress">
                <div class="pf-progress-top"><span>Kelengkapan profil</span><span>{{ $persen }}%</span></div>
                <div class="pf-bar"><i style="width:{{ $persen }}%"></i></div>
                <small>{{ $persen < 100 ? 'Lengkapi data agar pengajuan magang bisa diproses.' : 'Profil kamu sudah lengkap.' }}</small>
            </div>
        </aside>

        {{-- KOLOM KANAN --}}
        <div class="pf-form">

            <div class="pf-head">
                <h3 class="pf-title"><i class="bi bi-person-vcard blue"></i> Informasi Pribadi &amp; Akademik</h3>
                <button type="button" class="pf-edit" id="btnEdit"><i class="bi bi-pencil-square"></i> Edit</button>
            </div>

            <fieldset class="pf-fs" id="pfFields" disabled>

                {{-- INFORMASI PRIBADI --}}
                <div class="pf-grid">
                    <div class="pf-field full">
                        <label class="l">Nama Lengkap</label>
                        <input type="text" value="{{ $user->name }}" readonly>
                        <small>Nama mengikuti akun saat mendaftar.</small>
                    </div>
                    <div class="pf-field">
                        <label class="l">Email</label>
                        <input type="email" value="{{ $user->email }}" readonly>
                    </div>
                    <div class="pf-field">
                        <label class="l">Jenis Kelamin <b class="pf-req">*</b></label>
                        <select name="jenis_kelamin">
                            <option value="">Pilih jenis kelamin</option>
                            <option value="Laki-laki" @selected($v('jenis_kelamin') === 'Laki-laki')>Laki-laki</option>
                            <option value="Perempuan" @selected($v('jenis_kelamin') === 'Perempuan')>Perempuan</option>
                        </select>
                        @error('jenis_kelamin')<div class="pf-err">{{ $message }}</div>@enderror
                    </div>
                    <div class="pf-field">
                        <label class="l">Nomor Telepon <b class="pf-req">*</b></label>
                        <input type="text" name="no_telepon" value="{{ $v('no_telepon') }}" inputmode="tel">
                        @error('no_telepon')<div class="pf-err">{{ $message }}</div>@enderror
                    </div>
                </div>

                {{-- DATA AKADEMIK --}}
                <section class="pf-sec2">
                    <h3 class="pf-title"><i class="bi bi-mortarboard orange"></i> Data Akademik</h3>
                    <div class="pf-grid">
                        <div class="pf-field"><label class="l">Asal Universitas</label>
                            <input type="text" name="perguruan_tinggi" value="{{ $v('perguruan_tinggi') }}"></div>
                        <div class="pf-field"><label class="l">Program Studi</label>
                            <input type="text" name="program_studi" value="{{ $v('program_studi') }}"></div>
                        <div class="pf-field full"><label class="l">Alamat Universitas</label>
                            <textarea name="alamat_kampus">{{ $v('alamat_kampus') }}</textarea></div>
                        <div class="pf-field"><label class="l">Kecamatan Universitas</label>
                            <input type="text" name="kecamatan_kampus" value="{{ $v('kecamatan_kampus') }}"></div>
                        <div class="pf-field"><label class="l">Kelurahan Universitas</label>
                            <input type="text" name="kelurahan_kampus" value="{{ $v('kelurahan_kampus') }}"></div>
                        <div class="pf-field"><label class="l">NIM / NPM</label>
                            <input type="text" name="nim" value="{{ $v('nim') }}">
                            @error('nim')<div class="pf-err">{{ $message }}</div>@enderror</div>
                        <div class="pf-field"><label class="l">Semester</label>
                            <input type="number" name="semester" value="{{ $v('semester') }}" min="1" max="14"></div>
                        <div class="pf-field full"><label class="l">Dosen Pembimbing</label>
                            <input type="text" name="dosen_pembimbing" value="{{ $v('dosen_pembimbing') }}"></div>
                    </div>
                </section>

            </fieldset>

<div class="pf-foot">
    <button type="button" id="btnBatal" class="pf-btn pf-btn-cancel">Batal</button>
    <button type="submit" class="pf-btn pf-btn-save"><i class="bi bi-check2"></i> Simpan Perubahan</button>
</div>
        </div>
    </div>
</form>
</div>

{{-- ================= TAB POSISI MAGANG ================= --}}
<div class="pf-panel" id="panel-posisi">
    <div class="pf-wrap">
        <div class="pf-bar-top"></div>
        <div class="pos">
            <h3 class="pf-title"><i class="bi bi-people orange"></i> Posisi Magang</h3>

            @if(!$diterima)
                <div class="pos-lock">
                    <i class="bi bi-lock-fill"></i>
                    <h3>Belum Tersedia</h3>
                    <p>Bidang penempatan, pembimbing lapangan, dan periode magang akan tampil di sini setelah pengajuan magangmu dinyatakan diterima.</p>
                </div>
            @else
                <div class="pos-grid">
                    <div class="pos-item"><span>Instansi</span><strong>{{ $pengajuan->instansi ?? 'BPS Kota Batu' }}</strong></div>
                    <div class="pos-item"><span>Bidang Penempatan</span><strong>{{ $pengajuan->bidang ?? 'Belum ditentukan' }}</strong></div>
                    <div class="pos-item"><span>Pembimbing Lapangan</span><strong>{{ $pengajuan->pembimbing ?? 'Belum ditentukan' }}</strong></div>
                    <div class="pos-item"><span>Periode Magang</span>
                        <strong>
                            @if(!empty($pengajuan->periode_mulai) && !empty($pengajuan->periode_selesai))
                                {{ \Carbon\Carbon::parse($pengajuan->periode_mulai)->translatedFormat('d M Y') }}
                                - {{ \Carbon\Carbon::parse($pengajuan->periode_selesai)->translatedFormat('d M Y') }}
                            @else Belum ditentukan @endif
                        </strong>
                    </div>
                </div>
            @endif
        </div>
    </div>
</div>

<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script>
(function () {
    // ===== tab Data Profil / Posisi Magang =====
    var tabs = document.querySelectorAll('.pf-tab'), panels = document.querySelectorAll('.pf-panel');
    function openTab(name) {
        tabs.forEach(function (t) { t.classList.toggle('on', t.dataset.tab === name); });
        panels.forEach(function (p) { p.classList.toggle('on', p.id === 'panel-' + name); });
        history.replaceState(null, '', name === 'posisi' ? '#posisi' : location.pathname);
    }
    tabs.forEach(function (t) { t.addEventListener('click', function () { openTab(t.dataset.tab); }); });
    if (location.hash === '#posisi') openTab('posisi');

    // ===== mode lihat / edit =====
    var form = document.getElementById('pfForm'),
        fields = document.getElementById('pfFields'),
        fotoBox = document.getElementById('fotoBox'),
        fotoInput = document.getElementById('foto'),
        fotoAwal = fotoBox.innerHTML,
        hasErr = form.dataset.err === '1';

    function setEdit(on) {
        fields.disabled = !on;
        form.classList.toggle('editing', on);
    }

    document.getElementById('btnEdit').addEventListener('click', function () { setEdit(true); });

    document.getElementById('btnBatal').addEventListener('click', function () {
        if (hasErr) { window.location.href = '/mahasiswa/profil'; return; } // buang isian yang salah
        form.reset();
        fotoBox.innerHTML = fotoAwal;
        setEdit(false);
    });

    if (hasErr) setEdit(true); // validasi gagal: langsung kembali ke mode edit

    // ===== pratinjau foto =====
    fotoInput.addEventListener('change', function () {
        var file = fotoInput.files[0];
        if (!file) return;
        if (file.size > 2 * 1024 * 1024) { alert('Ukuran foto maksimal 2 MB.'); fotoInput.value = ''; return; }
        var reader = new FileReader();
        reader.onload = function (e) { fotoBox.innerHTML = '<img src="' + e.target.result + '" alt="Foto profil">'; };
        reader.readAsDataURL(file);
    });

    // ===== popup notifikasi sukses =====
    @if(session('success'))
        var pesan = @json(session('success'));
        if (window.Swal) {
            Swal.fire({
                icon: 'success',
                iconColor: '#2fa266',
                title: 'Tersimpan!',
                text: pesan,
                timer: 2500,
                timerProgressBar: true,
                showConfirmButton: false
            });
        } else {
            alert(pesan);
        }
    @endif
})();
</script>

@endsection