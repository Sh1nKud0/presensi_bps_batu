```blade
@extends('layouts.admin')

@section('title', 'Data Mahasiswa - SIMASTA')
@section('page-title', 'Data Mahasiswa')
@section('user-role', 'Admin')
@section('user-avatar', 'A')

@section('content')

<style>
    /* Kartu utama */
    .mahasiswa-card {
        width: 100%;
        box-sizing: border-box;
        overflow: hidden;
    }

    /* Header halaman */
    .mahasiswa-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 20px;
        margin-bottom: 25px;
    }

    .mahasiswa-header h2 {
        margin: 0 0 8px;
        color: #1e293b;
        font-size: 22px;
        font-weight: 700;
    }

    .mahasiswa-header p {
        margin: 0;
        color: #64748b;
        font-size: 14px;
    }

    /* Tombol tambah */
    .btn-tambah-mahasiswa {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 7px;
        padding: 12px 18px;
        background: linear-gradient(135deg, #3b82f6, #10b981);
        color: #ffffff;
        border: none;
        border-radius: 10px;
        font-family: inherit;
        font-size: 14px;
        font-weight: 600;
        text-decoration: none;
        white-space: nowrap;
        box-sizing: border-box;
        transition: 0.2s ease;
    }

    .btn-tambah-mahasiswa:hover {
        filter: brightness(0.95);
        transform: translateY(-1px);
    }

    /* Notifikasi berhasil */
    .mahasiswa-alert-success {
        display: flex;
        align-items: center;
        gap: 10px;
        padding: 13px 16px;
        margin-bottom: 20px;
        color: #166534;
        background: #f0fdf4;
        border: 1px solid #bbf7d0;
        border-radius: 9px;
        font-size: 14px;
    }

    /* Tabel */
    .mahasiswa-table-wrapper {
        width: 100%;
        overflow-x: auto;
        border-radius: 8px;
    }

    .mahasiswa-table {
        width: 100%;
        min-width: 850px;
        border-collapse: collapse;
    }

    .mahasiswa-table thead {
        background: #f8fafc;
    }

    .mahasiswa-table th {
        padding: 15px 16px;
        color: #64748b;
        font-size: 12px;
        font-weight: 700;
        text-align: left;
        text-transform: uppercase;
        letter-spacing: 0.4px;
        border-bottom: 1px solid #e2e8f0;
        white-space: nowrap;
    }

    .mahasiswa-table td {
        padding: 16px;
        color: #334155;
        font-size: 13px;
        vertical-align: middle;
        border-bottom: 1px solid #edf2f7;
    }

    .mahasiswa-table tbody tr:hover {
        background: #f8fafc;
    }

    .mahasiswa-table tbody tr:last-child td {
        border-bottom: none;
    }

    /* Tombol aksi */
    .action-buttons {
        display: flex;
        align-items: center;
        gap: 7px;
        flex-wrap: nowrap;
    }

    .action-form {
        display: inline-flex;
        margin: 0;
        padding: 0;
    }

    .btn-action {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-width: 62px;
        min-height: 33px;
        padding: 8px 11px;
        border: 1px solid transparent;
        border-radius: 7px;
        font-family: inherit;
        font-size: 12px;
        font-weight: 600;
        line-height: 1.2;
        text-decoration: none;
        white-space: nowrap;
        cursor: pointer;
        box-sizing: border-box;
        transition: 0.2s ease;
    }

    /* Detail */
    .btn-detail {
        color: #2563eb;
        background: #eff6ff;
        border-color: #bfdbfe;
    }

    .btn-detail:hover {
        color: #1d4ed8;
        background: #dbeafe;
    }

    /* Edit */
    .btn-edit {
        color: #ffffff;
        background: #0d9488;
        border-color: #0d9488;
    }

    .btn-edit:hover {
        background: #0f766e;
        border-color: #0f766e;
    }

    /* Hapus */
    .btn-delete {
        color: #be123c;
        background: #fff1f2;
        border-color: #fecdd3;
    }

    .btn-delete:hover {
        background: #ffe4e6;
        border-color: #fda4af;
    }

    /* Data kosong */
    .mahasiswa-empty {
        padding: 35px 15px !important;
        text-align: center;
        color: #94a3b8 !important;
    }

    /* Responsif */
    @media (max-width: 768px) {
        .mahasiswa-header {
            align-items: flex-start;
            flex-direction: column;
        }

        .btn-tambah-mahasiswa {
            width: 100%;
        }

        .mahasiswa-table {
            min-width: 850px;
        }
    }
</style>

<div class="card mahasiswa-card">

    {{-- Header --}}
    <div class="mahasiswa-header">
        <div>
            <h2>Data Mahasiswa</h2>
            <p>Kelola data mahasiswa yang terdaftar di SIMASTA.</p>
        </div>

        <a href="{{ route('admin.mahasiswa.create') }}"
           class="btn-tambah-mahasiswa">
            <span>+</span>
            Tambah Mahasiswa
        </a>
    </div>

    {{-- Notifikasi berhasil --}}
    @if(session('success'))
        <div class="mahasiswa-alert-success">
            <span>✓</span>
            <span>{{ session('success') }}</span>
        </div>
    @endif

    {{-- Tabel mahasiswa --}}
    <div class="mahasiswa-table-wrapper">
        <table class="mahasiswa-table">

            <thead>
                <tr>
                    <th>No.</th>
                    <th>Nama</th>
                    <th>NIM</th>
                    <th>Email</th>
                    <th>Program Studi</th>
                    <th>Perguruan Tinggi</th>
                    <th>Aksi</th>
                </tr>
            </thead>

            <tbody>
                @forelse($mahasiswa as $item)
                    <tr>
                        <td>{{ $loop->iteration }}</td>
                        <td><strong>{{ $item->nama }}</strong></td>
                        <td>{{ $item->nim }}</td>
                        <td>{{ $item->email }}</td>
                        <td>{{ $item->program_studi }}</td>
                        <td>{{ $item->perguruan_tinggi }}</td>

                        <td>
                            <div class="action-buttons">

                                <a href="{{ route('admin.mahasiswa.show', $item) }}"
                                   class="btn-action btn-detail">
                                    Detail
                                </a>

                                <a href="{{ route('admin.mahasiswa.edit', $item) }}"
                                   class="btn-action btn-edit">
                                    Edit
                                </a>

                                <form
                                    action="{{ route('admin.mahasiswa.destroy', $item) }}"
                                    method="POST"
                                    class="action-form"
                                    onsubmit="return confirm('Yakin ingin menghapus data mahasiswa ini?')"
                                >
                                    @csrf
                                    @method('DELETE')

                                    <button type="submit"
                                            class="btn-action btn-delete">
                                        Hapus
                                    </button>
                                </form>

                            </div>
                        </td>
                    </tr>

                @empty
                    <tr>
                        <td colspan="7" class="mahasiswa-empty">
                            Belum ada data mahasiswa yang terdaftar.
                        </td>
                    </tr>
                @endforelse
            </tbody>

        </table>
    </div>

</div>

@endsection
```