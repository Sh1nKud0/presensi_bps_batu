<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\OtpService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

class AuthController extends Controller
{
    public function register(Request $r)
    {
        $data = $r->validate([
            'nama_lengkap'     => 'required|string|max:150',
            'no_telp'          => 'required|string|max:20',
            'no_wa'            => 'nullable|string|max:20',
            'perguruan_tinggi' => 'required|string|max:200',
            'program_studi'    => 'required|string|max:150',
            'nim'              => 'required|string|max:30|unique:mahasiswas,nim',
            'alamat_kampus'    => 'required|string|max:255',
            'kelurahan_kampus' => 'required|string|max:100',
            'kecamatan_kampus' => 'required|string|max:100',
            'dosen_pembimbing' => 'required|string|max:150',
            'no_telp_dosen'    => 'nullable|string|max:20',
            'no_wa_dosen'      => 'required|string|max:20',
            'email'            => 'required|email|unique:users,email|unique:mahasiswas,email',
            'password'         => 'required|min:8|confirmed',
        ]);

        // Simpan ke 2 tabel sekaligus. Kalau salah satu gagal, keduanya dibatalkan.
        $user = DB::transaction(function () use ($data) {
            $user = User::create([
                'name'     => $data['nama_lengkap'],
                'email'    => $data['email'],
                'password' => $data['password'], // di-hash otomatis oleh casts()
                'role'     => 'mahasiswa',
            ]);

            $user->mahasiswa()->create([
                'nama'             => $data['nama_lengkap'],
                'email'            => $data['email'],
                'no_telepon'       => $data['no_telp'],
                'no_wa'            => $data['no_wa'] ?? null,
                'perguruan_tinggi' => $data['perguruan_tinggi'],
                'program_studi'    => $data['program_studi'],
                'nim'              => $data['nim'],
                'alamat'           => $data['alamat_kampus'],
                'kelurahan_kampus' => $data['kelurahan_kampus'],
                'kecamatan_kampus' => $data['kecamatan_kampus'],
                'dosen_pembimbing' => $data['dosen_pembimbing'],
                'no_telp_dosen'    => $data['no_telp_dosen'] ?? null,
                'no_wa_dosen'      => $data['no_wa_dosen'],
            ]);

            return $user;
        });

        OtpService::send($user);
        session(['otp_user_id' => $user->id]);

        return redirect()->route('otp.show')
            ->with('success', 'Kode OTP sudah dikirim ke email kamu.');
    }

    public function login(Request $r)
    {
        $cred = $r->validate([
            'email'    => 'required|email',
            'password' => 'required',
        ]);

        if (!Auth::attempt($cred)) {
            return back()->withErrors([
                'email' => 'Email atau password salah.',
            ])->onlyInput('email');
        }

        $user = Auth::user();

        // OTP hanya untuk mahasiswa yang emailnya belum terverifikasi
        if ($user->role === 'mahasiswa' && !$user->email_verified_at) {
            Auth::logout();
            OtpService::send($user);
            session(['otp_user_id' => $user->id]);

            return redirect()->route('otp.show')
                ->with('success', 'Email belum diverifikasi. Kode OTP baru sudah dikirim.');
        }

        $r->session()->regenerate();

        return redirect()->intended($user->dashboardUrl());
    }

    public function logout(Request $r)
    {
        Auth::logout();
        $r->session()->invalidate();
        $r->session()->regenerateToken();

        return redirect('/login')->with('success', 'Anda berhasil logout.');
    }
}