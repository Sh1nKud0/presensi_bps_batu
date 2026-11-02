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
    Schema::create('pengajuans', function (Blueprint $table) {
        $table->id();
        $table->foreignId('user_id')->constrained()->cascadeOnDelete();
        $table->string('instansi')->nullable();
        $table->date('periode_mulai')->nullable();
        $table->date('periode_selesai')->nullable();
        $table->enum('status', [
            'diproses',      // baru mendaftar
            'diverifikasi',  // berkas sudah dicek admin
            'diterima',
            'ditolak',
        ])->default('diproses');
        $table->text('catatan_admin')->nullable();
        $table->timestamps();
    });
}
    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('pengajuans');
    }
};
