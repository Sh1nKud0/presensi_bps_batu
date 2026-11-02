@extends('layouts.admin')

@section('title', 'Penilaian - SIMASTA')

@section('page-title', 'Penilaian')

@section('user-role', 'Admin')

@section('user-avatar', 'A')

@section('sidebar')
    @include('layouts.admin')
@endsection

@section('content')

<div class="card">

    <div style="margin-bottom:25px;">
        <h2>Penilaian Magang</h2>
        <p>Kelola hasil penilaian mahasiswa selama pelaksanaan magang.</p>
    </div>

    <div class="table-container">

        <table>

            <thead>
                <tr>
                    <th>No</th>
                    <th>Mahasiswa</th>
                    <th>NIM</th>
                    <th>Pembimbing</th>
                    <th>Nilai</th>
                    <th>Status</th>
                    <th>Aksi</th>
                </tr>
            </thead>

            <tbody>

                <tr>
                    <td colspan="7" style="text-align:center;">
                        Belum ada data penilaian.
                    </td>
                </tr>

            </tbody>

        </table>

    </div>

</div>

@endsection