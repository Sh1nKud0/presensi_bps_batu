<?php

use App\Http\Controllers\PresensiController;
use Illuminate\Support\Facades\Route;

Route::get('/presensi', [PresensiController::class, 'index'])->name('presensi.index');
Route::match(['GET', 'POST', 'PATCH', 'DELETE'], '/presensi/api/{path}', [PresensiController::class, 'proxy'])
    ->where('path', '[a-zA-Z0-9./-]+')
    ->name('presensi.api');

$standalonePages = function () {
    Route::get('/', [PresensiController::class, 'index'])->name('presensi.home');
    Route::get('/login', [PresensiController::class, 'index'])->name('presensi.login');
    Route::get('/register', [PresensiController::class, 'index'])->defaults('auth_mode', 'register')->name('presensi.register');
};

if (config('presensi.standalone')) {
    $standalonePages();
} elseif (config('presensi.domain')) {
    Route::domain(config('presensi.domain'))->group($standalonePages);
}
