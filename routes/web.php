<?php

use App\Http\Controllers\Admin\MahasiswaController;
use App\Http\Controllers\Admin\PengajuanController as AdminPengajuanController;
use App\Http\Controllers\Auth\AuthController;
use App\Http\Controllers\Auth\OtpController;
use App\Http\Controllers\GoogleController;
use App\Http\Controllers\PengajuanController;
use App\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

require __DIR__.'/presensi.php';

if (config('presensi.standalone')) {
    return;
}
/*
|--------------------------------------------------------------------------
| PUBLIC
|--------------------------------------------------------------------------
*/

Route::get('/', fn () => view('home'));

/*
|--------------------------------------------------------------------------
| AUTH (hanya untuk yang belum login)
|--------------------------------------------------------------------------
*/

Route::middleware('guest')->group(function () {

    Route::get('/login', fn () => view('auth.index'))->name('login');
    Route::post('/login', [AuthController::class, 'login'])->middleware('throttle:10,1');

    Route::get('/register', fn () => view('auth.index'));
    Route::post('/register', [AuthController::class, 'register'])->middleware('throttle:10,1');

    // Login dengan Google
    Route::get('/auth/google/redirect', [GoogleController::class, 'redirect']);
    Route::get('/auth/google/callback', [GoogleController::class, 'callback']);
    Route::get('/auth/google/confirm', [GoogleController::class, 'confirm'])->name('google.confirm');
    Route::post('/auth/google/confirm', [GoogleController::class, 'link'])->middleware('throttle:5,1');

});

/*
|--------------------------------------------------------------------------
| VERIFIKASI OTP
|--------------------------------------------------------------------------
*/

Route::get('/verifikasi-otp', [OtpController::class, 'show'])->name('otp.show');
Route::post('/verifikasi-otp', [OtpController::class, 'verify'])
    ->middleware('throttle:10,1')->name('otp.verify');
Route::post('/verifikasi-otp/kirim-ulang', [OtpController::class, 'resend'])
    ->middleware('throttle:3,1')->name('otp.resend');

/*
|--------------------------------------------------------------------------
| LOGOUT
|--------------------------------------------------------------------------
*/

Route::post('/logout', [AuthController::class, 'logout'])->middleware('auth');

/*
|--------------------------------------------------------------------------
| MAHASISWA
|--------------------------------------------------------------------------
*/

Route::middleware(['auth', 'role:mahasiswa'])
    ->prefix('mahasiswa')
    ->name('mahasiswa.')
    ->group(function () {

        // ===== Selalu bisa diakses =====
        Route::get('/dashboard',  fn () => view('mahasiswa.dashboard'))->name('dashboard');
        Route::get('/dokumen',    fn () => view('mahasiswa.dokumen'))->name('dokumen');
        Route::get('/surat',      fn () => view('mahasiswa.surat'))->name('surat');
        Route::get('/bantuan',    fn () => view('mahasiswa.bantuan'))->name('bantuan');
        Route::get('/pengumuman', fn () => view('mahasiswa.pengumuman'))->name('pengumuman');

        // Profil (tampil + simpan). Posisi Magang ada di tab profil.
        Route::get('/profil',  [ProfileController::class, 'show'])->name('profil');
        Route::post('/profil', [ProfileController::class, 'update'])->name('profil.simpan');
        Route::get('/penempatan', fn () => redirect('/mahasiswa/profil#posisi'))->name('penempatan');

        // Pengajuan magang
        Route::get('/pengajuan',  [PengajuanController::class, 'index'])->name('pengajuan');
        Route::post('/pengajuan', [PengajuanController::class, 'store'])->name('pengajuan.simpan');

        // ===== Terkunci: hanya untuk yang sudah DITERIMA =====
        Route::middleware('magang.diterima')->group(function () {
            Route::get('/presensi',  fn () => view('mahasiswa.presensi'))->name('presensi');
            Route::get('/logbook',   fn () => view('mahasiswa.logbook'))->name('logbook');
            Route::get('/penilaian', fn () => view('mahasiswa.penilaian'))->name('penilaian');
        });
    });

/*
|--------------------------------------------------------------------------
| ADMIN
|--------------------------------------------------------------------------
*/

Route::middleware(['auth', 'role:admin'])
    ->prefix('admin')
    ->name('admin.')
    ->group(function () {
        Route::get('/dashboard', fn () => view('admin.dashboard'))->name('dashboard');

        // nama route jadi admin.mahasiswa.index, admin.mahasiswa.create, dst.
        Route::resource('mahasiswa', MahasiswaController::class);

        // Pengajuan magang: daftar, detail, dan keputusan
        Route::get('/pengajuan', [AdminPengajuanController::class, 'index'])->name('pengajuan.index');
        Route::get('/pengajuan/{pengajuan}', [AdminPengajuanController::class, 'show'])->name('pengajuan.show');
        Route::post('/pengajuan/{pengajuan}/verifikasi', [AdminPengajuanController::class, 'verifikasi'])->name('pengajuan.verifikasi');
        Route::post('/pengajuan/{pengajuan}/terima', [AdminPengajuanController::class, 'terima'])->name('pengajuan.terima');
        Route::post('/pengajuan/{pengajuan}/tolak', [AdminPengajuanController::class, 'tolak'])->name('pengajuan.tolak');

        Route::get('/pembimbing', fn () => view('admin.pembimbing.index'))->name('pembimbing.index');
        Route::get('/penempatan', fn () => view('admin.penempatan.index'))->name('penempatan.index');
        Route::get('/logbook', fn () => view('admin.logbook.index'))->name('logbook.index');
        Route::get('/penilaian', fn () => view('admin.penilaian.index'))->name('penilaian.index');
        Route::get('/laporan', fn () => view('admin.laporan.index'))->name('laporan.index');
    });

/*
|--------------------------------------------------------------------------
| PREVIEW STATUS (hanya di local, untuk tes tampilan)
|--------------------------------------------------------------------------
*/

if (app()->environment('local')) {
    Route::get('/preview/{status}', function ($status) {
        $status === 'reset'
            ? session()->forget('preview_status')
            : session(['preview_status' => $status]);

        return redirect('/mahasiswa/dashboard');
    })->middleware('auth');
}