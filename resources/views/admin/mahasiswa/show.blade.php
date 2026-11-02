@extends('layouts.admin')

@section('title', 'Detail Mahasiswa - SIMASTA')
@section('page-title', 'Detail Mahasiswa')
@section('user-role', 'Admin')
@section('user-avatar', 'A')

@section('content')

<div class="card">

    <div style="
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 25px;
    ">
        <div>
            <h2>Detail Mahasiswa</h2>
            <p>Informasi lengkap data mahasiswa yang terdaftar di SIMASTA.</p>
        </div>

        <a href="{{ route('admin.mahasiswa.index') }}" class="btn-secondary">
            Kembali
        </a>
    </div>

    <div class="info-list">

        <div class="info-item">
            <span>Nama Mahasiswa</span>
            <strong>{{ $mahasiswa->nama }}</strong>
        </div>

        <div class="info-item">
            <span>NIM</span>
            <strong>{{ $mahasiswa->nim }}</strong>
        </div>

        <div class="info-item">
            <span>Email</span>
            <strong>{{ $mahasiswa->email }}</strong>
        </div>

        <div class="info-item">
            <span>No. Telepon</span>
            <strong>
                {{ $mahasiswa->no_telepon ?? '-' }}
            </strong>
        </div>

        <div class="info-item">
            <span>Perguruan Tinggi</span>
            <strong>{{ $mahasiswa->perguruan_tinggi }}</strong>
        </div>

        <div class="info-item">
            <span>Program Studi</span>
            <strong>{{ $mahasiswa->program_studi }}</strong>
        </div>

        <div class="info-item">
            <span>Semester</span>
            <strong>
                {{ $mahasiswa->semester ?? '-' }}
            </strong>
        </div>

        <div class="info-item">
            <span>Tahun Angkatan</span>
            <strong>
                {{ $mahasiswa->tahun_angkatan ?? '-' }}
            </strong>
        </div>

        <div class="info-item">
            <span>Alamat</span>
            <strong>
                {{ $mahasiswa->alamat ?? '-' }}
            </strong>
        </div>

        <div class="info-item">
            <span>Kota</span>
            <strong>
                {{ $mahasiswa->kota ?? '-' }}
            </strong>
        </div>

    </div>

    <div style="
        display: flex;
        gap: 10px;
        margin-top: 25px;
    ">

        <a href="{{ route('admin.mahasiswa.edit', $mahasiswa) }}"
           class="btn-primary">
            Edit Data
        </a>

        <a href="{{ route('admin.mahasiswa.index') }}"
           class="btn-secondary">
            Kembali
        </a>

    </div>

</div>

@endsection