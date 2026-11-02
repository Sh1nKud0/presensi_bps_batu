@extends('layouts.app')

@section('title', 'Penempatan Magang - SIMASTA')

@section('page-title', 'Penempatan Magang')

@section('user-role', 'Mahasiswa')

@section('user-avatar', 'M')

@section('sidebar')

    @include('layouts.mahasiswa')

@endsection

@section('content')

<div class="welcome">

    <h1>
        Penempatan Magang
    </h1>

    <p>
        Informasi mengenai penempatan dan pembimbing
        kegiatan magang kamu di BPS Kota Batu.
    </p>

</div>


<!-- STATUS PENEMPATAN -->

<div class="placement-status">

    <div class="placement-status-icon">
        ✓
    </div>

    <div>

        <span>
            Status Penempatan
        </span>

        <h2>
            Magang Aktif
        </h2>

        <p>
            Penempatan magang telah ditetapkan oleh
            pihak BPS Kota Batu.
        </p>

    </div>

</div>


<br>


<!-- INFORMASI INSTANSI -->

<div class="card">

    <h2>
        Informasi Instansi
    </h2>

    <div class="placement-grid">


        <div class="placement-item">

            <span>
                Instansi
            </span>

            <strong>
                Badan Pusat Statistik Kota Batu
            </strong>

        </div>


        <div class="placement-item">

            <span>
                Lokasi
            </span>

            <strong>
                Kota Batu, Jawa Timur
            </strong>

        </div>


        <div class="placement-item">

            <span>
                Unit / Bagian
            </span>

            <strong>
                -
            </strong>

        </div>


        <div class="placement-item">

            <span>
                Posisi Magang
            </span>

            <strong>
                -
            </strong>

        </div>


    </div>

</div>


<br>


<!-- PERIODE MAGANG -->

<div class="card">

    <h2>
        Periode Magang
    </h2>

    <div class="placement-grid">


        <div class="placement-item">

            <span>
                Tanggal Mulai
            </span>

            <strong>
                -
            </strong>

        </div>


        <div class="placement-item">

            <span>
                Tanggal Selesai
            </span>

            <strong>
                -
            </strong>

        </div>


        <div class="placement-item">

            <span>
                Durasi
            </span>

            <strong>
                -
            </strong>

        </div>


        <div class="placement-item">

            <span>
                Status
            </span>

            <strong class="status-text">
                Aktif
            </strong>

        </div>


    </div>

</div>


<br>


<!-- PEMBIMBING -->

<div class="card">

    <h2>
        Pembimbing Magang
    </h2>


    <div class="supervisor-grid">


        <!-- PEMBIMBING LAPANGAN -->

        <div class="supervisor-card">

            <div class="supervisor-icon">
                👤
            </div>

            <div>

                <span>
                    Pembimbing Lapangan
                </span>

                <h3>
                    -
                </h3>

                <p>
                    BPS Kota Batu
                </p>

            </div>

        </div>


        <!-- DOSEN PEMBIMBING -->

        <div class="supervisor-card">

            <div class="supervisor-icon">
                👨‍🏫
            </div>

            <div>

                <span>
                    Dosen Pembimbing
                </span>

                <h3>
                    -
                </h3>

                <p>
                    Perguruan Tinggi
                </p>

            </div>

        </div>


    </div>

</div>


<br>


<!-- CATATAN -->

<div class="card">

    <h2>
        Catatan Penempatan
    </h2>

    <p class="placement-note">

        Informasi penempatan akan diperbarui oleh
        administrator SIMASTA setelah proses verifikasi
        dan penentuan pembimbing selesai.

    </p>

</div>

@endsection