@extends('layouts.app')

@section('title', 'Penilaian - SIMASTA')

@section('page-title', 'Penilaian Mahasiswa')

@section('user-role', 'Mahasiswa')

@section('user-avatar', 'M')

@section('sidebar')

    @include('layouts.mahasiswa')

@endsection

@section('content')

<div class="welcome">

    <h1>
        Penilaian Mahasiswa
    </h1>

    <p>
        Lihat hasil penilaian kegiatan magang kamu.
    </p>

</div>


<!-- STATUS PENILAIAN -->

<div class="card">

    <h2>
        Status Penilaian
    </h2>

    <br>

    <div class="info-box">

        <div>

            <strong>
                Status
            </strong>

            <p>
                Belum Dinilai
            </p>

        </div>

        <span class="badge badge-warning">
            Menunggu
        </span>

    </div>

</div>


<br>


<!-- HASIL PENILAIAN -->

<div class="card">

    <h2>
        Hasil Penilaian
    </h2>

    <br>

    <div class="table-container">

        <table>

            <thead>

                <tr>

                    <th>
                        Komponen Penilaian
                    </th>

                    <th>
                        Nilai
                    </th>

                    <th>
                        Keterangan
                    </th>

                </tr>

            </thead>

            <tbody>

                <tr>

                    <td>
                        Kedisiplinan
                    </td>

                    <td>
                        -
                    </td>

                    <td>
                        Belum dinilai
                    </td>

                </tr>


                <tr>

                    <td>
                        Tanggung Jawab
                    </td>

                    <td>
                        -
                    </td>

                    <td>
                        Belum dinilai
                    </td>

                </tr>


                <tr>

                    <td>
                        Kerja Sama
                    </td>

                    <td>
                        -
                    </td>

                    <td>
                        Belum dinilai
                    </td>

                </tr>


                <tr>

                    <td>
                        Kinerja
                    </td>

                    <td>
                        -
                    </td>

                    <td>
                        Belum dinilai
                    </td>

                </tr>

            </tbody>

        </table>

    </div>

</div>


<br>


<!-- NILAI AKHIR -->

<div class="card">

    <h2>
        Nilai Akhir
    </h2>

    <br>

    <div class="final-score">

        <div class="score-number">
            -
        </div>

        <p>
            Nilai akhir belum tersedia.
        </p>

    </div>

</div>

@endsection