@extends('layouts.app')


@section('title', 'Dashboard Pembimbing - SIMASTA')


@section('page-title', 'Dashboard Pembimbing')


@section(
    'page-description',
    'Monitoring mahasiswa magang BPS Kota Batu'
)


@section('content')


<div class="cards">


    <div class="card stat-card">

        <h3>
            Mahasiswa Bimbingan
        </h3>

        <div class="number">
            0
        </div>

    </div>


    <div class="card stat-card">

        <h3>
            Logbook Menunggu
        </h3>

        <div class="number">
            0
        </div>

    </div>


    <div class="card stat-card">

        <h3>
            Logbook Disetujui
        </h3>

        <div class="number">
            0
        </div>

    </div>


    <div class="card stat-card">

        <h3>
            Penilaian
        </h3>

        <div class="number">
            0
        </div>

    </div>


</div>


<br>


<div class="card">

    <h2>
        Mahasiswa Bimbingan
    </h2>

    <br>


    <div class="table-container">

        <table>

            <thead>

                <tr>

                    <th>
                        No
                    </th>

                    <th>
                        Nama Mahasiswa
                    </th>

                    <th>
                        Kampus
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

                <tr>

                    <td>
                        -
                    </td>

                    <td>
                        Belum ada data
                    </td>

                    <td>
                        -
                    </td>

                    <td>

                        <span
                            class="badge badge-warning">

                            Belum ada

                        </span>

                    </td>

                    <td>

                        <button
                            class="btn btn-secondary">

                            Detail

                        </button>

                    </td>

                </tr>

            </tbody>

        </table>

    </div>

</div>


@endsection