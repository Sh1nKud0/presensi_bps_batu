<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
           Schema::create('mahasiswas', function (Blueprint $table) {
        $table->id();

        $table->string('nama');
        $table->string('nim')->unique();
        $table->string('email')->unique();
        $table->string('no_telepon')->nullable();

        $table->string('perguruan_tinggi');
        $table->string('program_studi');
        $table->string('semester')->nullable();
        $table->string('tahun_angkatan')->nullable();

        $table->text('alamat')->nullable();
        $table->string('kota')->nullable();

        $table->timestamps();
    });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('mahasiswas');
    }
};
