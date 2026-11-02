<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('mahasiswas', function (Blueprint $table) {
            $string = ['no_telp','no_wa','nik','jenis_kelamin','provinsi','kota','kecamatan','kelurahan',
                       'perguruan_tinggi','program_studi','kecamatan_kampus','kelurahan_kampus',
                       'nim','dosen_pembimbing'];
            $text   = ['alamat_ktp','alamat_lengkap','alamat_kampus'];

            foreach ($string as $k) {
                if (!Schema::hasColumn('mahasiswas', $k)) $table->string($k)->nullable();
            }
            foreach ($text as $k) {
                if (!Schema::hasColumn('mahasiswas', $k)) $table->text($k)->nullable();
            }
            if (!Schema::hasColumn('mahasiswas', 'semester')) {
                $table->unsignedTinyInteger('semester')->nullable();
            }
        });
    }

    public function down(): void {}
};