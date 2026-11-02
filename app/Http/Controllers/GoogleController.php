<?php

namespace App\Http\Controllers;

use App\Models\User;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Socialite\Facades\Socialite;

class GoogleController extends Controller
{
    public function redirect(Request $request)
    {
        $request->session()->forget('google_link');

        return Socialite::driver('google')->redirect();
    }

    public function callback(Request $request)
    {
        $request->session()->forget('google_link');
        try {
            // Socialite memeriksa state, menukar authorization code dan mengambil
            // identitas langsung dari endpoint userinfo Google melalui HTTPS.
            $google = Socialite::driver('google')->user();
        } catch (\Throwable $e) {
            return redirect('/login')->withErrors(['email' => 'Login Google gagal atau dibatalkan. Silakan coba lagi.']);
        }

        $id = $google->getId();
        $email = $google->getEmail();
        if (! is_string($id) || $id === '' || strlen($id) > 255 || ! is_string($email) || strlen($email) > 255 || ! filter_var($email, FILTER_VALIDATE_EMAIL) || ($google->user['email_verified'] ?? false) !== true) {
            return redirect('/login')->withErrors(['email' => 'Akun Google harus memiliki email yang sudah diverifikasi.']);
        }

        $user = User::where('google_id', $id)->first();
        if ($user) {
            return $this->loginUser($request, $user);
        }

        $user = User::where('email', $email)->first();
        if ($user) {
            if ($user->google_id) {
                return redirect('/login')->withErrors(['email' => 'Akun SIMASTA ini sudah terhubung dengan akun Google lain.']);
            }
            $request->session()->put('google_link', ['user_id' => $user->id, 'google_id' => $id, 'expires_at' => now()->addMinutes(10)->timestamp]);

            return redirect()->route('google.confirm');
        }

        $user = DB::transaction(function () use ($google, $email, $id) {
            $user = User::create([
                'name' => Str::limit($google->getName() ?: $email, 255, ''),
                'email' => $email,
                'password' => Str::random(64),
                'role' => 'mahasiswa',
            ]);
            $user->forceFill(['google_id' => $id, 'email_verified_at' => now()])->save();

            return $user;
        });

        return $this->loginUser($request, $user);
    }

    public function confirm(Request $request)
    {
        $pending = $request->session()->get('google_link');
        $user = $pending && ($pending['expires_at'] ?? 0) >= now()->timestamp ? User::find($pending['user_id']) : null;
        if (! $user || $user->google_id) {
            $request->session()->forget('google_link');
            return redirect('/login')->withErrors(['email' => 'Konfirmasi kedaluwarsa. Silakan mulai login Google lagi.']);
        }

        return view('auth.google-confirm', ['email' => $user->email]);
    }

    public function link(Request $request)
    {
        $request->validate(['password' => 'required|string']);
        $pending = $request->session()->get('google_link');
        $user = $pending && ($pending['expires_at'] ?? 0) >= now()->timestamp ? User::find($pending['user_id']) : null;
        if (! $user || $user->google_id) {
            $request->session()->forget('google_link');
            return redirect('/login')->withErrors(['email' => 'Konfirmasi kedaluwarsa. Silakan mulai login Google lagi.']);
        }
        if (! Hash::check($request->password, $user->password)) {
            return back()->withErrors(['password' => 'Kata sandi SIMASTA salah.']);
        }
        if (User::where('google_id', $pending['google_id'])->exists()) {
            $request->session()->forget('google_link');
            return redirect('/login')->withErrors(['email' => 'Akun Google sudah terhubung dengan akun lain.']);
        }
        $user->forceFill(['google_id' => $pending['google_id']])->save();
        $request->session()->forget('google_link');

        return $this->loginUser($request, $user);
    }

    private function loginUser(Request $request, User $user)
    {
        Auth::login($user);
        $request->session()->regenerate();

        return redirect()->intended($user->dashboardUrl());
    }
}
