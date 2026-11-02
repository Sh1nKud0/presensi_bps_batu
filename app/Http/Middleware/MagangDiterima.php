<?php

namespace App\Http\Middleware;

use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class MagangDiterima
{
    /**
     * Handle an incoming request.
     *
     * @param  Closure(Request): (Response)  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
    if (auth()->user()->statusMagang() !== 'diterima') {
            return redirect('/mahasiswa/dashboard')
                ->with('terkunci', 'Fitur ini terbuka setelah kamu dinyatakan lolos magang di BPS.');
        }    
        return $next($request);
    }
}
