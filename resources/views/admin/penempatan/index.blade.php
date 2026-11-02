@extends('layouts.admin')

@section('title', 'Penempatan - SIMASTA')

@section('page-title', 'Penempatan')

@section('user-role', 'Admin')

@section('user-avatar', 'A')

@section('sidebar')
    @include('layouts.admin')
@endsection

@section('content')

<div class="card">

    <div style="margin-bottom:25px;">
        <h2>Penempatan Magang</h2>
        <p>Kelola penempatan mahasiswa pada unit atau bagian magang.</p>
    </div>

    <div class="table-container">

        <table>

            <thead>
                <tr>
                    <th>No</th>
                    <th>Mahasiswa</th>
                    <th>NIM</th>
                    <th>Unit/Bagian</th>
                    <th>Pembimbing</th>
                    <th>Periode</th>
                    <th>Status</th>
                </tr>
            </thead>

            <tbody>

                <tr>
                    <td colspan="7" style="text-align:center;">
                        Belum ada data penempatan.
                    </td>
                </tr>

            </tbody>

        </table>

    </div>

</div>

@endsection