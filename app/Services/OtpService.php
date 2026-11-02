<?php

namespace App\Services;

use App\Mail\OtpMail;
use App\Models\User;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;

class OtpService
{
    public static function send(User $user): void
    {
        $user->otps()->delete(); // hapus OTP lama

        $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

        $user->otps()->create([
            'code_hash'  => Hash::make($code),
            'expires_at' => now()->addMinutes(10),
        ]);

        Mail::to($user->email)->send(new OtpMail($user->name, $code));
    }

    public static function verify(User $user, string $code): bool
    {
        $otp = $user->otps()->latest()->first();

        if (!$otp || $otp->expires_at->isPast() || $otp->attempts >= 5) {
            return false;
        }

        $otp->increment('attempts');

        if (!Hash::check($code, $otp->code_hash)) {
            return false;
        }

        $otp->delete();
        $user->forceFill(['email_verified_at' => now()])->save();

        return true;
    }
}