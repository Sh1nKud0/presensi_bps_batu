<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {

        // Alias middleware untuk pembatasan akses per role
        $middleware->alias([
            'role'            => \App\Http\Middleware\RoleMiddleware::class,
            'magang.diterima' => \App\Http\Middleware\MagangDiterima::class,
        ]);

        // Kalau user yang sudah login membuka /login atau /register,
        // arahkan ke dashboard sesuai role-nya
        $middleware->redirectUsersTo(function (Request $request) {
            return match ($request->user()->role) {
                'admin' => '/admin/dashboard',
                'pembimbing' => '/pembimbing/dashboard',
                default => '/mahasiswa/dashboard',
            };
        });
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );
    })->create();