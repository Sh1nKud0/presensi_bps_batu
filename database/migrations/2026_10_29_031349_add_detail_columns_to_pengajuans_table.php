<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('pengajuans', function (Blueprint $table) {
            $table->string('bidang_diminati')->nullable()->after('instansi');
            $table->text('motivasi')->nullable()->after('periode_selesai');
            $table->string('file_surat')->nullable()->after('motivasi');
            $table->string('file_cv')->nullable()->after('file_surat');
            // diisi admin saat menerima
            $table->string('bidang')->nullable()->after('file_cv');
            $table->string('pembimbing')->nullable()->after('bidang');
        });
    }

    public function down(): void
    {
        Schema::table('pengajuans', function (Blueprint $table) {
            $table->dropColumn(['bidang_diminati', 'motivasi', 'file_surat', 'file_cv', 'bidang', 'pembimbing']);
        });
    }
};