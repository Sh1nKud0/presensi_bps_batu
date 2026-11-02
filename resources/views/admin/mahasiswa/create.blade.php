@extends('layouts.admin')

@section('title', 'Tambah Mahasiswa - SIMASTA')
@section('page-title', 'Tambah Mahasiswa')
@section('user-role', 'Admin')
@section('user-avatar', 'A')

@section('content')

<style>
    .em-wrap { max-width: 880px; }

    .em-head { margin-bottom: 24px; }
    .em-head h2 { margin: 0 0 6px; font-size: 1.35rem; line-height: 1.3; }
    .em-head p  { margin: 0; color: #64748b; font-size: .95rem; }

    .em-alert {
        margin-bottom: 24px;
        padding: 14px 16px;
        border: 1px solid #fecaca;
        border-left: 4px solid #dc2626;
        border-radius: 8px;
        background: #fef2f2;
        color: #991b1b;
        font-size: .9rem;
    }
    .em-alert ul { margin: 8px 0 0; padding-left: 18px; }

    .em-section { padding: 22px 0; border-top: 1px solid #e2e8f0; }
    .em-section:first-of-type { border-top: 0; padding-top: 0; }
    .em-section-title { margin: 0 0 2px; font-size: 1rem; font-weight: 600; color: #0f172a; }
    .em-section-desc  { margin: 0 0 16px; font-size: .85rem; color: #64748b; }

    .em-grid { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 16px 20px; }
    .em-full { grid-column: 1 / -1; }

    .em-field label {
        display: block;
        margin-bottom: 6px;
        font-size: .875rem;
        font-weight: 500;
        color: #1e293b;
    }
    .em-field .req { color: #dc2626; margin-left: 2px; }

    .em-field input,
    .em-field textarea {
        width: 100%;
        box-sizing: border-box;
        padding: 10px 12px;
        border: 1px solid #cbd5e1;
        border-radius: 8px;
        background: #fff;
        font: inherit;
        font-size: .95rem;
        color: #0f172a;
        transition: border-color .15s, box-shadow .15s;
    }
    .em-field textarea { min-height: 96px; resize: vertical; line-height: 1.5; }
    .em-field input::placeholder,
    .em-field textarea::placeholder { color: #94a3b8; }
    .em-field input:hover,
    .em-field textarea:hover { border-color: #94a3b8; }
    .em-field input:focus,
    .em-field textarea:focus {
        outline: none;
        border-color: #2563eb;
        box-shadow: 0 0 0 3px rgba(37, 99, 235, .18);
    }
    .em-field.has-error input,
    .em-field.has-error textarea { border-color: #dc2626; }
    .em-error { margin-top: 5px; font-size: .8rem; color: #dc2626; }

    .em-actions {
        display: flex;
        justify-content: flex-end;
        gap: 10px;
        margin-top: 8px;
        padding-top: 20px;
        border-top: 1px solid #e2e8f0;
    }
    .em-btn {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        height: 40px;
        padding: 0 20px;
        border: 1px solid transparent;
        border-radius: 8px;
        font: inherit;
        font-size: .9rem;
        font-weight: 500;
        line-height: 1;
        text-decoration: none;
        white-space: nowrap;
        cursor: pointer;
        transition: background-color .15s, border-color .15s;
    }
    .em-btn:focus-visible { outline: 2px solid #2563eb; outline-offset: 2px; }

    .em-btn-primary { background: #2563eb; color: #fff; }
    .em-btn-primary:hover { background: #1d4ed8; }

    .em-btn-ghost { background: #fff; border-color: #cbd5e1; color: #334155; }
    .em-btn-ghost:hover { background: #f1f5f9; border-color: #94a3b8; }

    @media (max-width: 640px) {
        .em-grid { grid-template-columns: 1fr; }
        .em-actions { flex-direction: column-reverse; }
        .em-btn { width: 100%; }
    }
</style>

<div class="card em-wrap">

    <div class="em-head">
        <h2>Tambah mahasiswa</h2>
        <p>Tambahkan data mahasiswa yang akan terdaftar di SIMASTA.</p>
    </div>

    @if ($errors->any())
        <div class="em-alert alert-danger" role="alert">
            <strong>Data belum dapat disimpan.</strong>
            <ul>
                @foreach ($errors->all() as $error)
                    <li>{{ $error }}</li>
                @endforeach
            </ul>
        </div>
    @endif

    <form action="{{ route('admin.mahasiswa.store') }}" method="POST">
        @csrf

        {{-- IDENTITAS --}}
        <div class="em-section">
            <h3 class="em-section-title">Identitas</h3>
            <p class="em-section-desc">Nama lengkap dan nomor induk mahasiswa.</p>

            <div class="em-grid">
                <div class="em-field em-full @error('nama') has-error @enderror">
                    <label for="nama">Nama mahasiswa <span class="req">*</span></label>
                    <input type="text" id="nama" name="nama"
                        value="{{ old('nama') }}"
                        placeholder="Masukkan nama mahasiswa" required>
                    @error('nama') <div class="em-error">{{ $message }}</div> @enderror
                </div>

                <div class="em-field @error('nim') has-error @enderror">
                    <label for="nim">NIM <span class="req">*</span></label>
                    <input type="text" id="nim" name="nim" inputmode="numeric"
                        value="{{ old('nim') }}"
                        placeholder="Masukkan NIM" required>
                    @error('nim') <div class="em-error">{{ $message }}</div> @enderror
                </div>
            </div>
        </div>

        {{-- KONTAK --}}
        <div class="em-section">
            <h3 class="em-section-title">Kontak</h3>
            <p class="em-section-desc">Email dan nomor telepon yang bisa dihubungi.</p>

            <div class="em-grid">
                <div class="em-field @error('email') has-error @enderror">
                    <label for="email">Email <span class="req">*</span></label>
                    <input type="email" id="email" name="email"
                        value="{{ old('email') }}"
                        placeholder="nama@email.com" required>
                    @error('email') <div class="em-error">{{ $message }}</div> @enderror
                </div>

                <div class="em-field @error('no_telepon') has-error @enderror">
                    <label for="no_telepon">No. telepon</label>
                    <input type="tel" id="no_telepon" name="no_telepon"
                        value="{{ old('no_telepon') }}"
                        placeholder="Contoh: 081234567890">
                    @error('no_telepon') <div class="em-error">{{ $message }}</div> @enderror
                </div>
            </div>
        </div>

        {{-- AKADEMIK --}}
        <div class="em-section">
            <h3 class="em-section-title">Data akademik</h3>
            <p class="em-section-desc">Asal kampus, program studi, dan angkatan.</p>

            <div class="em-grid">
                <div class="em-field @error('perguruan_tinggi') has-error @enderror">
                    <label for="perguruan_tinggi">Perguruan tinggi <span class="req">*</span></label>
                    <input type="text" id="perguruan_tinggi" name="perguruan_tinggi"
                        value="{{ old('perguruan_tinggi') }}"
                        placeholder="Masukkan nama perguruan tinggi" required>
                    @error('perguruan_tinggi') <div class="em-error">{{ $message }}</div> @enderror
                </div>

                <div class="em-field @error('program_studi') has-error @enderror">
                    <label for="program_studi">Program studi <span class="req">*</span></label>
                    <input type="text" id="program_studi" name="program_studi"
                        value="{{ old('program_studi') }}"
                        placeholder="Masukkan program studi" required>
                    @error('program_studi') <div class="em-error">{{ $message }}</div> @enderror
                </div>

                <div class="em-field @error('semester') has-error @enderror">
                    <label for="semester">Semester</label>
                    <input type="text" id="semester" name="semester" inputmode="numeric"
                        value="{{ old('semester') }}"
                        placeholder="Contoh: 5">
                    @error('semester') <div class="em-error">{{ $message }}</div> @enderror
                </div>

                <div class="em-field @error('tahun_angkatan') has-error @enderror">
                    <label for="tahun_angkatan">Tahun angkatan</label>
                    <input type="text" id="tahun_angkatan" name="tahun_angkatan" inputmode="numeric"
                        value="{{ old('tahun_angkatan') }}"
                        placeholder="Contoh: 2024">
                    @error('tahun_angkatan') <div class="em-error">{{ $message }}</div> @enderror
                </div>
            </div>
        </div>

        {{-- ALAMAT --}}
        <div class="em-section">
            <h3 class="em-section-title">Alamat</h3>
            <p class="em-section-desc">Tempat tinggal mahasiswa saat ini.</p>

            <div class="em-grid">
                <div class="em-field em-full @error('alamat') has-error @enderror">
                    <label for="alamat">Alamat</label>
                    <textarea id="alamat" name="alamat" rows="4"
                        placeholder="Masukkan alamat mahasiswa">{{ old('alamat') }}</textarea>
                    @error('alamat') <div class="em-error">{{ $message }}</div> @enderror
                </div>

                <div class="em-field @error('kota') has-error @enderror">
                    <label for="kota">Kota</label>
                    <input type="text" id="kota" name="kota"
                        value="{{ old('kota') }}"
                        placeholder="Contoh: Malang">
                    @error('kota') <div class="em-error">{{ $message }}</div> @enderror
                </div>
            </div>
        </div>

        {{-- TOMBOL --}}
        <div class="em-actions">
            <a href="{{ route('admin.mahasiswa.index') }}" class="em-btn em-btn-ghost">Batal</a>
            <button type="submit" class="em-btn em-btn-primary">Simpan mahasiswa</button>
        </div>

    </form>

</div>

@endsection