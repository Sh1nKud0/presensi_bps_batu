<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class Pengajuan extends Model
{
    protected $fillable = [
    'user_id', 'instansi', 'bidang_diminati', 'periode_mulai', 'periode_selesai',
    'motivasi', 'file_surat', 'file_cv', 'bidang', 'pembimbing',
    'status', 'catatan_admin',
];

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
