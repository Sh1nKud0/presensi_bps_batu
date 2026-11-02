<?php

namespace App\Http\Controllers\Auth;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Services\OtpService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

class OtpController extends Controller
{
    // User yang sedang menunggu verifikasi (diingat lewat session)
    private function pendingUser(): ?User
    {
        return User::find(session('otp_user_id'));
    }

    public function show()
    {
        $user = $this->pendingUser();
        if (!$user) {
            return redirect('/login');
        }

        return view('auth.otp', ['email' => $user->email]);
    }

    public function verify(Request $r)
    {
        $r->validate(['code' => 'required|digits:6']);

        $user = $this->pendingUser();
        if (!$user) {
            return redirect('/login');
        }

        if (!OtpService::verify($user, $r->code)) {
            return back()->withErrors(['code' => 'Kode salah atau sudah kedaluwarsa.']);
        }

        session()->forget('otp_user_id');
        Auth::login($user);
        $r->session()->regenerate();

        return redirect($user->dashboardUrl())
            ->with('success', 'Akun berhasil diverifikasi!');
    }

    public function resend()
    {
        $user = $this->pendingUser();
        if (!$user) {
            return redirect('/login');
        }

        OtpService::send($user);

        return back()->with('success', 'Kode OTP baru sudah dikirim.');
    }
}