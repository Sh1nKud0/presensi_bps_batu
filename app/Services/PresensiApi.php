<?php

namespace App\Services;

use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use InvalidArgumentException;

class PresensiApi
{
    public function origin(): string
    {
        $url = rtrim((string) config('presensi.api_url'), '/');
        $parts = parse_url($url);

        if (! $parts || ! in_array($parts['scheme'] ?? '', ['http', 'https'], true)
            || empty($parts['host']) || isset($parts['user']) || isset($parts['pass'])
            || ! empty($parts['path']) || isset($parts['query']) || isset($parts['fragment'])) {
            throw new InvalidArgumentException('PRESENSI_API_URL harus berupa origin HTTP/HTTPS tanpa path.');
        }

        return $url;
    }

    public function send(string $method, string $path, array $query = [], ?string $token = null,
        ?string $body = null, string $contentType = 'application/json'): Response
    {
        $client = Http::acceptJson()
            ->connectTimeout(config('presensi.connect_timeout'))
            ->timeout(config('presensi.timeout'))
            ->withoutRedirecting();

        if ($token !== null) {
            $client = $client->withToken($token);
        }

        if ($body !== null) {
            $client = $client->withBody($body, $contentType);
        }

        // No automatic retry: a timed-out attendance/decision may already be committed.
        return $client->send($method, $this->origin().$path, ['query' => $query]);
    }
}
