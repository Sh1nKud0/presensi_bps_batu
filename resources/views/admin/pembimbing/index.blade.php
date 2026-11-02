@extends('layouts.admin')

@section('title', 'Data Pembimbing - SIMASTA')

@section('page-title', 'Data Pembimbing')

@section('user-role', 'Admin')

@section('user-avatar', 'A')

@section('sidebar')
    @include('layouts.admin')
@endsection

@section('content')

<div class="card">

    <div style="
        display:flex;
        justify-content:space-between;
        align-items:center;
        margin-bottom:25px;
    ">
    </div>

        <div>
            <h2>Data Pembimbing</h2>
            <p>Kelola data pembimbing lapangan mahasiswa</p>
        </div>
            <button class="btn-primary">
            + Tambah Pembimbing
            </button>  
    </div>

    <div class="table-container">
        <table>

            <thead>
                <tr>
                    <th>No</th>
                    <th>Nama Pembimbing</th>
                    <th>Email</th>
                    <th>No. Telepon</th>
                    <th>Jabatan</th>
                    <th>Aksi</th>
                </tr>
            </thead>

            <tbody>

                <tr>
                    <td colspan="6" style="text-align:center;">
                        Belum ada data pembimbing.
                    </td>
                </tr>

            </tbody>

        </table>
    </div>

</div>

@endsection