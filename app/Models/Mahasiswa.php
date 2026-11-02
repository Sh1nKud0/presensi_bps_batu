<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Mahasiswa extends Model
{
    use HasFactory;

    protected $fillable = [
        'user_id',
        'nama',
        'nim',
        'email',
        'no_telepon',
        'no_wa',
        'perguruan_tinggi',
        'program_studi',
        'semester',
        'tahun_angkatan',
        'alamat',
        'kelurahan_kampus',
        'kecamatan_kampus',
        'kota',
        'dosen_pembimbing',
        'no_telp_dosen',
        'no_wa_dosen',
        // tambahan untuk halaman profil
        'nik',
        'jenis_kelamin',
        'alamat_ktp',
        'provinsi',
        'kecamatan',
        'kelurahan',
        'alamat_kampus',
    ];

    public function user()
    {
        return $this->belongsTo(User::class);
    }
}