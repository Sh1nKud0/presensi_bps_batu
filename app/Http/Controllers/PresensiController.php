<?php

namespace App\Http\Controllers;

use App\Services\PresensiApi;
use Illuminate\Contracts\Encryption\DecryptException;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use InvalidArgumentException;
use Symfony\Component\HttpFoundation\Response;

class PresensiController extends Controller
{
    private const UUID = '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}';

    public function index(Request $request): Response
    {
        if (app()->environment('local') && config('presensi.google_client_id') && $request->getHost() === '127.0.0.1') {
            // Match the localhost origin registered for the Google web client.
            $port = $request->getPort();
            $defaultPort = $request->isSecure() ? 443 : 80;
            $url = $request->getScheme().'://localhost'.($port === $defaultPort ? '' : ':'.$port).$request->getRequestUri();

            return redirect()->to($url)->header('Cache-Control', 'private, no-store');
        }

        $standalone = config('presensi.standalone') || $request->getHost() === config('presensi.domain');

        return response()->view('presensi.index', [
            'presensiHome' => $standalone ? '/' : '/presensi',
            'authMode' => $request->route('auth_mode', 'login'),
        ])->header('Cache-Control', 'private, no-store');
    }

    public function proxy(Request $request, PresensiApi $api, string $path): Response
    {
        $method = $request->method();
        if (! $this->allowed($method, $path)) {
            return $this->error('Halaman atau tindakan presensi tidak ditemukan.', 404);
        }

        try {
            $public = in_array($path, ['auth/login', 'auth/register', 'auth/google', 'auth/google/challenge', 'ready'], true);
            if (str_starts_with($path, 'auth/google') && ! config('presensi.google_client_id')) {
                return $this->error('Login Google belum diaktifkan.', 503, 'google_unavailable');
            }
            $session = $request->session()->get('presensi', []);
            $token = null;
            if (! $public) {
                if (empty($session['token']) || ($session['origin'] ?? '') !== hash('sha256', $api->origin())) {
                    $request->session()->forget('presensi');

                    return $this->error('Silakan masuk dengan akun presensi Android Anda.', 401);
                }
                $token = Crypt::decryptString($session['token']);
            }

            $body = null;
            $contentType = 'application/json';
            if (! in_array($method, ['GET', 'HEAD'], true)) {
                $body = $request->getContent();
                $contentType = strtolower(trim(explode(';', $request->header('Content-Type', ''))[0]));
                $upload = $method === 'POST' && $path === 'files';
                if (strlen($body) > ($upload ? 5 * 1024 * 1024 : 16384)) {
                    return $this->error($upload ? 'Bukti maksimal 5 MiB.' : 'Isi permintaan terlalu besar.', 413);
                }
                if ($upload ? ! in_array($contentType, ['image/jpeg', 'image/png', 'image/webp'], true)
                    : $contentType !== 'application/json') {
                    return $this->error($upload ? 'Gunakan gambar JPEG, PNG, atau WebP.' : 'Format permintaan harus JSON.', 415);
                }
                // Preserve the original password, including spaces. Laravel normally trims inputs.
                if (! $upload && (! is_object(json_decode($body)) || json_last_error() !== JSON_ERROR_NONE)) {
                    return $this->error('Isi permintaan harus objek JSON yang valid.', 400);
                }
                if ($path === 'auth/google') {
                    $challenge = $request->session()->get('presensi_google', []);
                    if (empty($challenge['nonce']) || ($challenge['expires'] ?? 0) <= time()
                        || ($challenge['origin'] ?? '') !== hash('sha256', $api->origin())) {
                        $request->session()->forget('presensi_google');

                        return $this->error('Sesi Google berakhir. Muat ulang tombol Google dan coba lagi.', 401, 'google_challenge_expired');
                    }
                    $data = json_decode($body, true);
                    if (array_diff(array_keys($data), ['credential', 'existing_password'])) {
                        return $this->error('Ada kolom Google yang tidak diizinkan.', 400);
                    }
                    $body = json_encode([...$data, 'nonce' => $challenge['nonce']], JSON_THROW_ON_ERROR);
                }
            }

            $upstream = $api->send($method, $path === 'ready' ? '/ready' : '/api/'.$path,
                $request->query(), $token, $body, $contentType);

            if ($upstream->status() === 401 && ! $public) {
                $request->session()->forget('presensi');
            }

            if (! $upstream->successful()) {
                $status = $upstream->status();
                if (str_starts_with($path, 'auth/google') && $status === 404) {
                    return $this->error('Login Google belum tersedia pada layanan presensi. Gunakan email dan kata sandi untuk sementara.', 503, 'google_unavailable');
                }
                $response = $this->error($upstream->json('error') ?: 'Layanan presensi belum dapat memproses permintaan.',
                    $status >= 400 && $status < 600 ? $status : 502, $upstream->json('code'));
                if ($status === 429) {
                    $response->headers->set('Retry-After', '60');
                }

                return $response;
            }

            if ($path === 'auth/google/challenge') {
                $nonce = $upstream->json('nonce');
                $expires = strtotime($upstream->json('expires_at') ?? '');
                if (! is_string($nonce) || ! preg_match('/^[A-Za-z0-9_-]{43}$/D', $nonce) || ! $expires || $expires <= time()) {
                    return $this->error('Respons persiapan Google tidak valid.', 502);
                }
                $request->session()->put('presensi_google', ['nonce' => $nonce, 'expires' => min($expires, time() + 300),
                    'origin' => hash('sha256', $api->origin())]);

                return response()->json(['nonce' => $nonce, 'expires_at' => $upstream->json('expires_at'),
                    'client_id' => config('presensi.google_client_id')])->header('Cache-Control', 'private, no-store');
            }

            if (in_array($path, ['auth/login', 'auth/google'], true)) {
                $data = $upstream->json();
                if (empty($data['access_token']) || empty($data['user']['id'])) {
                    return $this->error('Respons login presensi tidak valid.', 502);
                }
                $request->session()->regenerate();
                $request->session()->forget('presensi_google');
                $request->session()->put('presensi', [
                    'token' => Crypt::encryptString($data['access_token']),
                    'origin' => hash('sha256', $api->origin()),
                ]);

                return response()->json(['user' => $data['user'], 'expires_at' => $data['expires_at'] ?? null, 'csrf_token' => csrf_token()])
                    ->header('Cache-Control', 'private, no-store');
            }

            if (in_array($path, ['auth/logout', 'auth/password'], true)) {
                $request->session()->forget('presensi');
                $request->session()->regenerate();

                return response()->json(['message' => $upstream->json('message'), 'csrf_token' => csrf_token()])
                    ->header('Cache-Control', 'private, no-store');
            }

            if ($method === 'GET' && ($path === 'admin/rekap.xlsx' || preg_match('~^files/'.self::UUID.'$~D', $path))) {
                $mime = $upstream->header('Content-Type');
                $allowedMimes = ['image/jpeg', 'image/png', 'image/webp', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'];
                if (! in_array($mime, $allowedMimes, true)) {
                    return $this->error('Format berkas dari layanan presensi tidak valid.', 502);
                }
                $filename = $path === 'admin/rekap.xlsx' ? 'rekap-presensi.xlsx' : 'bukti-'.basename($path).'.'.explode('/', $mime)[1];

                return response($upstream->body(), 200, [
                    'Content-Type' => $mime,
                    'Content-Disposition' => 'attachment; filename="'.$filename.'"',
                    'Cache-Control' => 'private, no-store',
                    'X-Content-Type-Options' => 'nosniff',
                ]);
            }

            if (! is_array($upstream->json())) {
                return $this->error('Respons layanan presensi tidak valid.', 502);
            }

            return response()->json($upstream->json(), $upstream->status())->header('Cache-Control', 'private, no-store');
        } catch (DecryptException) {
            $request->session()->forget('presensi');

            return $this->error('Sesi presensi berakhir. Silakan masuk kembali.', 401);
        } catch (ConnectionException|InvalidArgumentException) {
            return $this->error('Layanan presensi belum dapat dihubungi. Silakan coba lagi setelah layanan tersedia. Jika baru mengirim data, periksa riwayat sebelum mengirim ulang.', 503);
        }
    }

    private function allowed(string $method, string $path): bool
    {
        $routes = [
            'GET' => ['ready', 'me', 'me/statistics', 'attendance/today', 'attendance/history', 'notifications', 'files',
                'holidays', 'admin/users', 'admin/participants', 'admin/attendance', 'admin/rekap', 'admin/rekap.xlsx'],
            'POST' => ['auth/login', 'auth/register', 'auth/google', 'auth/google/challenge', 'auth/logout', 'auth/password', 'attendance/check-in', 'attendance/check-out', 'files', 'admin/holidays'],
            'PATCH' => ['me', 'notifications/read'],
        ];
        if (in_array($path, $routes[$method] ?? [], true)) {
            return true;
        }

        return match ($method) {
            'GET' => (bool) preg_match('~^(?:(?:admin/)?requests/(?:izin|susulan|pembatalan)|files/'.self::UUID.')$~D', $path),
            'POST' => (bool) preg_match('~^(?:requests/(?:izin|susulan|pembatalan)|admin/requests/(?:izin|susulan|pembatalan)/'.self::UUID.'/decision)$~D', $path),
            'DELETE' => (bool) preg_match('~^admin/holidays/'.self::UUID.'$~D', $path),
            default => false,
        };
    }

    private function error(string $message, int $status, ?string $code = null): Response
    {
        return response()->json(['error' => $message, ...($code ? ['code' => $code] : [])], $status)->header('Cache-Control', 'private, no-store');
    }
}
