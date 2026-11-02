@extends('layouts.app')

@section('title', 'Logbook Magang - SIMASTA')

@section('page-title', 'Logbook Magang')

@section('user-role', 'Mahasiswa')

@section('user-avatar', 'M')

@section('sidebar')

    @include('layouts.mahasiswa')

@endsection

@section('content')

<div class="welcome">

    <h1>
        Logbook Magang
    </h1>

    <p>
        Catat seluruh kegiatan magang kamu selama
        melaksanakan kegiatan di BPS Kota Batu.
    </p>

</div>


<!-- RINGKASAN -->

<div class="card-grid">


    <div class="card stat-card">

        <h3>
            Total Kegiatan
        </h3>

        <div class="number">
            0
        </div>

        <p>
            Kegiatan tercatat
        </p>

    </div>


    <div class="card stat-card">

        <h3>
            Menunggu Verifikasi
        </h3>

        <div class="number">
            0
        </div>

        <p>
            Belum diverifikasi
        </p>

    </div>


    <div class="card stat-card">

        <h3>
            Disetujui
        </h3>

        <div class="number">
            0
        </div>

        <p>
            Kegiatan disetujui
        </p>

    </div>


    <div class="card stat-card">

        <h3>
            Ditolak
        </h3>

        <div class="number">
            0
        </div>

        <p>
            Perlu diperbaiki
        </p>

    </div>


</div>


<br>


<!-- TOMBOL TAMBAH -->

<div class="logbook-header">
    <div>

        <h2>
            Riwayat Logbook
        </h2>

        <p>
            Daftar kegiatan magang yang telah kamu catat.
        </p>
    </div>
         <a
                href="#form-logbook">
            
                <button class="btn-primary">
                    + Tambah Kegiatan
                </button>
        </a>
</div>
<br>


<!-- TABEL LOGBOOK -->

<div class="card">

    <div class="table-wrapper">

        <table class="logbook-table">

            <thead>

                <tr>

                    <th>
                        No
                    </th>

                    <th>
                        Tanggal
                    </th>

                    <th>
                        Kegiatan
                    </th>

                    <th>
                        Jam
                    </th>

                    <th>
                        Status
                    </th>

                    <th>
                        Aksi
                    </th>

                </tr>

            </thead>


            <tbody>


            </tbody>

        </table>

    </div>

</div>


<br>


<!-- FORM TAMBAH LOGBOOK -->

<div
    class="card"
    id="form-logbook">

    <h2>
        Tambah Kegiatan Logbook
    </h2>

    <p class="form-description">

        Isi kegiatan magang yang telah kamu lakukan
        dengan lengkap dan benar.

    </p>


    <form>


        <!-- TANGGAL -->

        <div class="form-group">

            <label>
                Tanggal Kegiatan
            </label>

            <input
                type="date"
                name="tanggal">

        </div>


        <!-- GRID -->

        <div class="form-grid">


            <!-- JAM MASUK -->

            <div class="form-group">

                <label>
                    Jam Masuk
                </label>

                <input
                    type="time"
                    name="jam_masuk">

            </div>


            <!-- JAM SELESAI -->

            <div class="form-group">

                <label>
                    Jam Selesai
                </label>

                <input
                    type="time"
                    name="jam_selesai">

            </div>


        </div>


        <!-- KEGIATAN -->

        <div class="form-group">

            <label>
                Nama Kegiatan
            </label>

            <input
                type="text"
                name="kegiatan"
                placeholder="Contoh: Membuat desain website SIMASTA">

        </div>


        <!-- URAIAN -->

        <div class="form-group">

            <label>
                Uraian Kegiatan
            </label>

            <textarea
                name="uraian"
                rows="5"
                placeholder="Jelaskan kegiatan yang kamu lakukan secara rinci..."></textarea>

        </div>


        <!-- HASIL -->

        <div class="form-group">

            <label>
                Hasil Kegiatan
            </label>

            <textarea
                name="hasil"
                rows="4"
                placeholder="Tuliskan hasil dari kegiatan yang dilakukan..."></textarea>

        </div>


        <!-- CATATAN -->

        <div class="form-group">

            <label>
                Catatan Tambahan
            </label>

            <textarea
                name="catatan"
                rows="3"
                placeholder="Catatan tambahan jika ada..."></textarea>

        </div>


        <!-- ACTION -->

        <div class="form-actions">

            <button
                type="reset"
                class="btn-secondary">
                Batal
            </button>

            <button
                type="button"
                class="btn-primary">

                Simpan Logbook

            </button>

        </div>


    </form>

</div>

@endsection