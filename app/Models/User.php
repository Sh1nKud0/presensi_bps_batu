<?php

namespace App\Models;

// use Illuminate\Contracts\Auth\MustVerifyEmail;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;

#[Fillable(['name', 'email', 'password', 'role'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory, Notifiable;

    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function isMahasiswa()
    {
        return $this->role === 'mahasiswa';
    }

    public function isAdmin()
    {
        return $this->role === 'admin';
    }

    public function isPembimbing()
    {
        return $this->role === 'pembimbing';
    }

    // Relasi: 1 mahasiswa punya 1 pengajuan magang
    public function pengajuan(): HasOne
    {
        return $this->hasOne(Pengajuan::class);
    }

    // Relasi: 1 akun punya 1 data mahasiswa (diisi saat daftar)
    public function mahasiswa(): HasOne
    {
        return $this->hasOne(Mahasiswa::class);
    }

    // Relasi: 1 akun bisa punya OTP (dipakai verifikasi email)
    public function otps(): HasMany
    {
        return $this->hasMany(EmailOtp::class);
    }

    // belum_diajukan | diproses | diverifikasi | diterima | ditolak
    public function statusMagang(): string
    {
        // mode preview, hanya aktif di APP_ENV=local
        if (app()->environment('local') && session()->has('preview_status')) {
            return session('preview_status');
        }

        return $this->pengajuan->status ?? 'belum_diajukan';
    }

    // Halaman tujuan setelah login, sesuai role
    public function dashboardUrl(): string
    {
        return match ($this->role) {
            'admin'      => route('admin.dashboard'),
            default      => route('mahasiswa.dashboard'),
        };
    }
}