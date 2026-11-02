@extends('layouts.admin')

@section('title', 'Monitoring Logbook - SIMASTA')

@section('page-title', 'Monitoring Logbook')

@section('user-role', 'Admin')

@section('user-avatar', 'A')

@section('sidebar')
    @include('layouts.admin')
@endsection

@section('content')

<div class="card">

    <div style="margin-bottom:25px;">
        <h2>Monitoring Logbook</h2>
        <p>Monitor aktivitas dan perkembangan mahasiswa selama magang.</p>
    </div>

    <div class="table-container">

        <table>

            <thead>
                <tr>
                    <th>No</th>
                    <th>Mahasiswa</th>
                    <th>Tanggal</th>
                    <th>Kegiatan</th>
                    <th>Status</th>
                    <th>Aksi</th>
                </tr>
            </thead>

            <tbody>

                <tr>
                    <td colspan="6" style="text-align:center;">
                        Belum ada data logbook.
                    </td>
                </tr>

            </tbody>

        </table>

    </div>

</div>

@endsection