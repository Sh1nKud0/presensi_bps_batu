```blade
@extends('layouts.admin')

@section('title', 'Pengajuan Magang - SIMASTA')
@section('page-title', 'Pengajuan Magang')
@section('user-role', 'Admin')
@section('user-avatar', 'A')

@section('content')

<style>
    /* Kartu utama */
    .pengajuan-card {
        width: 100%;
        box-sizing: border-box;
        overflow: hidden;
    }

    /* Header halaman */
    .pengajuan-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        gap: 16px;
        margin-bottom: 25px;
    }

    .pengajuan-header h2 {
        margin: 0 0 8px;
        color: #1e293b;
        font-size: 22px;
        font-weight: 700;
    }

    .pengajuan-header p {
        margin: 0;
        color: #64748b;
        font-size: 14px;
        line-height: 1.6;
    }

    .pengajuan-header-icon {
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
        width: 48px;
        height: 48px;
        border-radius: 14px;
        background: #eff6ff;
        color: #2563eb;
        font-size: 23px;
    }

    /* Ringkasan */
    .pengajuan-summary {
        display: grid;
        grid-template-columns: repeat(3, minmax(0, 1fr));
        gap: 16px;
        margin-bottom: 25px;
    }

    .pengajuan-summary-item {
        display: flex;
        align-items: center;
        gap: 14px;
        padding: 18px;
        background: #ffffff;
        border: 1px solid #e2e8f0;
        border-radius: 12px;
    }

    .summary-icon {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 44px;
        height: 44px;
        flex-shrink: 0;
        border-radius: 11px;
        font-size: 20px;
    }

    .summary-blue {
        color: #2563eb;
        background: #eff6ff;
    }

    .summary-yellow {
        color: #b45309;
        background: #fffbeb;
    }

    .summary-green {
        color: #15803d;
        background: #f0fdf4;
    }

    .summary-label {
        margin-bottom: 5px;
        color: #64748b;
        font-size: 12px;
    }

    .summary-number {
        color: #1e293b;
        font-size: 22px;
        font-weight: 700;
    }

    /* Pembungkus tabel */
    .pengajuan-table-wrapper {
        width: 100%;
        overflow-x: auto;
        border: 1px solid #e2e8f0;
        border-radius: 10px;
    }

    .pengajuan-table {
        width: 100%;
        min-width: 850px;
        border-collapse: collapse;
    }

    .pengajuan-table thead {
        background: #f8fafc;
    }

    .pengajuan-table th {
        padding: 15px 16px;
        color: #64748b;
        font-size: 11px;
        font-weight: 700;
        text-align: left;
        text-transform: uppercase;
        letter-spacing: 0.5px;
        white-space: nowrap;
        border-bottom: 1px solid #e2e8f0;
    }

    .pengajuan-table td {
        padding: 16px;
        color: #334155;
        font-size: 13px;
        vertical-align: middle;
        border-bottom: 1px solid #edf2f7;
    }

    .pengajuan-table tbody tr:last-child td {
        border-bottom: none;
    }

    .pengajuan-table tbody tr:hover {
        background: #f8fafc;
    }

    /* Label status */
    .pengajuan-status {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        gap: 6px;
        padding: 7px 11px;
        border: 1px solid #fde68a;
        border-radius: 20px;
        color: #92400e;
        background: #fffbeb;
        font-size: 12px;
        font-weight: 600;
        white-space: nowrap;
    }

    .status-dot {
        width: 6px;
        height: 6px;
        border-radius: 50%;
        background: #f59e0b;
    }

    /* Tombol Detail */
    .pengajuan-btn-detail {
        display: inline-flex;
        align-items: center;
        justify-content: center;
        min-width: 70px;
        min-height: 34px;
        padding: 8px 13px;
        color: #2563eb;
        background: #eff6ff;
        border: 1px solid #bfdbfe;
        border-radius: 7px;
        font-family: inherit;
        font-size: 12px;
        font-weight: 600;
        text-decoration: none;
        white-space: nowrap;
        box-sizing: border-box;
        cursor: pointer;
        transition: 0.2s ease;
    }

    .pengajuan-btn-detail:hover {
        color: #1d4ed8;
        background: #dbeafe;
        border-color: #93c5fd;
    }

    /* Tampilan ketika data kosong */
    .pengajuan-empty {
        padding: 45px 20px !important;
        text-align: center;
    }

    .empty-icon {
        display: flex;
        align-items: center;
        justify-content: center;
        width: 54px;
        height: 54px;
        margin: 0 auto 14px;
        border-radius: 50%;
        color: #64748b;
        background: #f1f5f9;
        font-size: 25px;
    }

    .empty-title {
        margin-bottom: 6px;
        color: #334155;
        font-size: 14px;
        font-weight: 600;
    }

    .empty-description {
        color: #94a3b8;
        font-size: 12px;
    }

    /* Responsif */
    @media (max-width: 900px) {
        .pengajuan-summary {
            grid-template-columns: 1fr;
            gap: 10px;
        }
    }

    @media (max-width: 600px) {
        .pengajuan-header h2 {
            font-size: 19px;
        }

        .pengajuan-header-icon {
            width: 42px;
            height: 42px;
        }
    }
</style>

<div class="card pengajuan-card">

    {{-- Header --}}
    <div class="pengajuan-header">
        <div>
            <h2>Pengajuan Magang</h2>
            <p>
                Kelola dan verifikasi pengajuan magang mahasiswa
                yang masuk ke BPS Kota Batu.
            </p>
        </div>

        <div class="pengajuan-header-icon" aria-hidden="true">
            &#128203;
        </div>
    </div>

    {{-- Ringkasan sementara --}}
    <div class="pengajuan-summary">

        <div class="pengajuan-summary-item">
            <div class="summary-icon summary-blue">
                &#128203;
            </div>
            <div>
                <div class="summary-label">Total Pengajuan</div>
                <div class="summary-number">0</div>
            </div>
        </div>

        <div class="pengajuan-summary-item">
            <div class="summary-icon summary-yellow">
                &#9203;
            </div>
            <div>
                <div class="summary-label">Menunggu Verifikasi</div>
                <div class="summary-number">0</div>
            </div>
        </div>

        <div class="pengajuan-summary-item">
            <div class="summary-icon summary-green">
                &#10003;
            </div>
            <div>
                <div class="summary-label">Disetujui</div>
                <div class="summary-number">0</div>
            </div>
        </div>

    </div>

    {{-- Tabel pengajuan --}}
    <div class="pengajuan-table-wrapper">
        <table class="pengajuan-table">

            <thead>
                <tr>
                    <th>No.</th>
                    <th>Mahasiswa</th>
                    <th>NIM</th>
                    <th>Tempat Magang</th>
                    <th>Tanggal Pengajuan</th>
                    <th>Status</th>
                    <th>Aksi</th>
                </tr>
            </thead>

            <tbody>
                {{-- Data belum terhubung dengan database pengajuan --}}
                <tr>
                    <td colspan="7" class="pengajuan-empty">
                        <div class="empty-icon" aria-hidden="true">
                            &#128203;
                        </div>

                        <div class="empty-title">
                            Belum ada data pengajuan
                        </div>

                        <div class="empty-description">
                            Data pengajuan magang mahasiswa akan muncul
                            di halaman ini setelah fitur pengajuan diaktifkan.
                        </div>
                    </td>
                </tr>
            </tbody>

        </table>
    </div>

</div>

@endsection
```