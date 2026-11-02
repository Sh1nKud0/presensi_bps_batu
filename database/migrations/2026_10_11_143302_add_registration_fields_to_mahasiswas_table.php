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
        Schema::table('mahasiswas', function (Blueprint $table) {
            $table->foreignId('user_id')->nullable()->unique()->after('id')
                  ->constrained()->cascadeOnDelete();
            $table->string('no_wa', 20)->nullable()->after('no_telepon');
            $table->string('kelurahan_kampus')->nullable()->after('alamat');
            $table->string('kecamatan_kampus')->nullable()->after('kelurahan_kampus');
            $table->string('dosen_pembimbing')->nullable();
            $table->string('no_telp_dosen', 20)->nullable();
            $table->string('no_wa_dosen', 20)->nullable();
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::table('mahasiswas', function (Blueprint $table) {
            $table->dropConstrainedForeignId('user_id');
            $table->dropColumn(['no_wa', 'kelurahan_kampus', 'kecamatan_kampus',
                                'dosen_pembimbing', 'no_telp_dosen', 'no_wa_dosen']);
        });
    }
};
