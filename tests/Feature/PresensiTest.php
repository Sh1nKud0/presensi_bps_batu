<?php

namespace Tests\Feature;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request as ClientRequest;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class PresensiTest extends TestCase
{
    private const ORIGIN = 'https://presensi.example.test';

    private const ID = '12345678-1234-1234-1234-123456789abc';

    protected function setUp(): void
    {
        parent::setUp();
        config(['presensi.api_url' => self::ORIGIN]);
        Http::preventStrayRequests();
    }

    private function presensiSession(): array
    {
        return ['presensi' => ['token' => Crypt::encryptString('android-api-token'), 'origin' => hash('sha256', self::ORIGIN)],
            'simasta_marker' => 'existing-session'];
    }

    public function test_presensi_is_separate_from_simasta_navigation_and_login(): void
    {
        $this->get('/')->assertOk()->assertViewIs('home')->assertDontSee('>Presensi</a>', false);
        $this->get('/login')->assertOk();
        $this->get('/presensi')->assertOk()->assertSee('Presensi Magang | BPS Kota Batu')->assertSee('csrf-token')
            ->assertSee('Lanjutkan dengan Google')->assertSee('google-official-button')->assertDontSee('Masuk SIMASTA');
        Http::assertNothingSent();
    }

    public function test_presensi_subdomain_opens_its_own_login_and_registration_pages(): void
    {
        $origin = 'https://'.config('presensi.domain');
        $this->get($origin.'/')->assertOk()->assertViewIs('presensi.index')->assertSee('href="/" class="brand"', false);
        $this->get($origin.'/login')->assertOk()->assertViewIs('presensi.index')->assertSee('data-auth-mode="login"', false);
        $this->get($origin.'/register')->assertOk()->assertViewIs('presensi.index')->assertSee('data-auth-mode="register"', false);
        Http::assertNothingSent();
    }

    public function test_local_google_page_uses_localhost_without_redirecting_simasta_or_api_requests(): void
    {
        $this->app->instance('env', 'local');
        config(['presensi.google_client_id' => '12345-web.apps.googleusercontent.com']);

        $this->get('http://127.0.0.1:8000/presensi?mode=login')
            ->assertRedirect('http://localhost:8000/presensi?mode=login');
        $this->get('http://localhost:8000/presensi')->assertOk()->assertViewIs('presensi.index');
        $this->get('http://127.0.0.1:8000/')->assertOk()->assertViewIs('home');
        $this->withSession(['_token' => 'local-csrf-token'])
            ->postJson('http://127.0.0.1:8000/presensi/api/auth/google', ['credential' => str_repeat('jwt', 20)], ['X-CSRF-TOKEN' => 'local-csrf-token'])
            ->assertUnauthorized()->assertJsonPath('code', 'google_challenge_expired');
        Http::assertNothingSent();
    }

    public function test_ip_origin_is_preserved_without_google_or_outside_local_development(): void
    {
        $this->app->instance('env', 'local');
        config(['presensi.google_client_id' => '']);
        $this->get('http://127.0.0.1:8000/presensi')->assertOk()->assertViewIs('presensi.index');

        $this->app->instance('env', 'production');
        config(['presensi.google_client_id' => '12345-web.apps.googleusercontent.com']);
        $this->get('http://127.0.0.1:8000/presensi')->assertOk()->assertViewIs('presensi.index');
        Http::assertNothingSent();
    }

    public function test_private_endpoints_require_a_separate_presensi_session(): void
    {
        $this->getJson('/presensi/api/me')->assertUnauthorized();
        $this->postJson('/presensi/api/attendance/check-in', [])->assertUnauthorized();
        $this->getJson('/presensi/api/files/'.self::ID)->assertUnauthorized();
        Http::assertNothingSent();
    }

    public function test_google_challenge_is_bound_to_the_session_and_nonce_is_never_trusted_from_browser_input(): void
    {
        config(['presensi.google_client_id' => '12345-web.apps.googleusercontent.com']);
        $nonce = str_repeat('a', 43);
        Http::fake([
            self::ORIGIN.'/api/auth/google/challenge' => Http::response(['nonce' => $nonce, 'expires_at' => now()->addMinutes(5)->toIso8601String()]),
            self::ORIGIN.'/api/auth/google' => Http::response(['access_token' => 'google-api-token', 'user' => ['id' => self::ID, 'role' => 'peserta', 'has_password' => false]]),
        ]);
        $this->withSession(['simasta_marker' => 'existing-session'])
            ->call('POST', '/presensi/api/auth/google/challenge', [], [], [], ['CONTENT_TYPE' => 'application/json'], '{}')
            ->assertOk()->assertJsonPath('client_id', '12345-web.apps.googleusercontent.com')->assertSessionHas('presensi_google.nonce', $nonce);
        $this->postJson('/presensi/api/auth/google', ['credential' => str_repeat('jwt', 20), 'nonce' => 'attacker-nonce'])->assertStatus(400);
        $this->postJson('/presensi/api/auth/google', ['credential' => str_repeat('jwt', 20)])
            ->assertOk()->assertJsonMissingPath('access_token')->assertJsonPath('user.has_password', false)
            ->assertSessionMissing('presensi_google')->assertSessionHas('simasta_marker', 'existing-session');
        $this->assertSame('google-api-token', Crypt::decryptString(session('presensi.token')));
        Http::assertSent(fn (ClientRequest $request) => $request->url() === self::ORIGIN.'/api/auth/google' && $request['nonce'] === $nonce);
        Http::assertSentCount(2);
    }

    public function test_google_login_requires_fresh_challenge_and_propagates_account_linking_errors(): void
    {
        config(['presensi.google_client_id' => '12345-web.apps.googleusercontent.com']);
        $this->postJson('/presensi/api/auth/google', ['credential' => str_repeat('jwt', 20)])->assertUnauthorized()->assertJsonPath('code', 'google_challenge_expired');
        Http::assertNothingSent();
        Http::fake([self::ORIGIN.'/api/auth/google' => Http::response(['error' => 'Konfirmasi kata sandi presensi.', 'code' => 'google_link_required'], 409)]);
        $this->withSession(['presensi_google' => ['nonce' => str_repeat('a', 43), 'expires' => time() + 200,
            'origin' => hash('sha256', self::ORIGIN)]])->postJson('/presensi/api/auth/google', ['credential' => str_repeat('jwt', 20)])
            ->assertStatus(409)->assertJsonPath('code', 'google_link_required')->assertSessionHas('presensi_google');
    }

    public function test_google_remains_unavailable_until_the_hosted_api_is_updated(): void
    {
        config(['presensi.google_client_id' => '']);
        $this->postJson('/presensi/api/auth/google/challenge', ['x' => 1])->assertStatus(503)->assertJsonPath('code', 'google_unavailable');
        Http::assertNothingSent();
        config(['presensi.google_client_id' => '12345-web.apps.googleusercontent.com']);
        Http::fake([self::ORIGIN.'/*' => Http::response(['error' => 'Endpoint tidak ditemukan.'], 404)]);
        $this->call('POST', '/presensi/api/auth/google/challenge', [], [], [], ['CONTENT_TYPE' => 'application/json'], '{}')
            ->assertStatus(503)->assertJsonPath('code', 'google_unavailable');
    }

    public function test_login_uses_android_credentials_hides_token_and_keeps_simasta_session(): void
    {
        Http::fake([self::ORIGIN.'/api/auth/login' => Http::response([
            'access_token' => 'new-secret-token', 'expires_at' => '2026-11-01T00:00:00Z',
            'user' => ['id' => self::ID, 'role' => 'peserta', 'nama_lengkap' => 'Peserta'],
        ])]);

        $response = $this->withSession(['simasta_marker' => 'existing-session'])->postJson('/presensi/api/auth/login', [
            'email' => 'peserta@example.test', 'password' => ' password with spaces ',
        ])->assertOk()->assertJsonPath('user.role', 'peserta')->assertJsonMissingPath('access_token')
            ->assertJsonStructure(['csrf_token'])->assertSessionHas('simasta_marker', 'existing-session');

        $encrypted = session('presensi.token');
        $this->assertNotSame('new-secret-token', $encrypted);
        $this->assertSame('new-secret-token', Crypt::decryptString($encrypted));
        $this->assertSame(csrf_token(), $response->json('csrf_token'));
        Http::assertSent(fn (ClientRequest $request) => $request['password'] === ' password with spaces '
            && ! $request->hasHeader('Authorization'));
    }

    public function test_login_failure_does_not_create_a_presensi_session(): void
    {
        Http::fake([self::ORIGIN.'/*' => Http::response(['error' => 'Email atau password salah.'], 401)]);
        $this->postJson('/presensi/api/auth/login', ['email' => 'wrong@example.test', 'password' => 'wrong'])
            ->assertUnauthorized()->assertJsonPath('error', 'Email atau password salah.')->assertSessionMissing('presensi');
    }

    public function test_profile_uses_server_session_token_and_preserves_remote_user_identity(): void
    {
        Http::fake([self::ORIGIN.'/api/me' => Http::response(['user' => ['id' => self::ID, 'role' => 'peserta']])]);
        $this->withSession($this->presensiSession())->withHeader('Authorization', 'Bearer attacker-token')
            ->getJson('/presensi/api/me')->assertOk()->assertJsonPath('user.id', self::ID);
        Http::assertSent(fn (ClientRequest $request) => $request->hasHeader('Authorization', 'Bearer android-api-token'));
    }

    public function test_token_is_never_forwarded_after_changing_the_api_origin(): void
    {
        $session = $this->presensiSession();
        config(['presensi.api_url' => 'https://different.example.test']);
        $this->withSession($session)->getJson('/presensi/api/me')->assertUnauthorized()->assertSessionMissing('presensi');
        Http::assertNothingSent();
    }

    public function test_unknown_paths_and_methods_cannot_be_used_as_an_open_proxy(): void
    {
        $this->withSession($this->presensiSession())->getJson('/presensi/api/admin/arbitrary')->assertNotFound();
        $this->postJson('/presensi/api/me')->assertNotFound();
        $this->getJson('/presensi/api/https://other.example.test')->assertNotFound();
        Http::assertNothingSent();
    }

    public function test_all_supported_domain_actions_reach_the_same_api_with_the_original_payload(): void
    {
        Http::fake([self::ORIGIN.'/*' => Http::response(['ok' => true])]);
        $this->withSession($this->presensiSession());
        $routes = [
            ['GET', 'me/statistics'], ['GET', 'attendance/today'], ['GET', 'attendance/history'],
            ['POST', 'attendance/check-in'], ['POST', 'attendance/check-out'],
            ['GET', 'admin/users'], ['GET', 'admin/participants'], ['GET', 'admin/attendance'],
            ['GET', 'notifications'], ['PATCH', 'notifications/read'], ['GET', 'files'],
            ['GET', 'holidays'], ['POST', 'admin/holidays'], ['DELETE', 'admin/holidays/'.self::ID],
            ['PATCH', 'me'], ['GET', 'admin/rekap'],
        ];
        foreach (['izin', 'susulan', 'pembatalan'] as $kind) {
            $routes[] = ['GET', 'requests/'.$kind];
            $routes[] = ['POST', 'requests/'.$kind];
            $routes[] = ['GET', 'admin/requests/'.$kind];
            $routes[] = ['POST', 'admin/requests/'.$kind.'/'.self::ID.'/decision'];
        }
        foreach ($routes as [$method, $path]) {
            $this->call($method, '/presensi/api/'.$path, [], [], [],
                ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'], '{}')->assertOk();
        }
        Http::assertSentCount(count($routes));
        Http::assertSent(fn (ClientRequest $request) => $request->url() === self::ORIGIN.'/api/admin/requests/susulan/'.self::ID.'/decision');
    }

    public function test_pagination_filters_and_admin_denial_are_preserved(): void
    {
        Http::fake([self::ORIGIN.'/*' => Http::response(['error' => 'Akses hanya untuk admin.'], 403)]);
        $this->withSession($this->presensiSession())->getJson('/presensi/api/admin/attendance?from=2026-10-01&to=2026-10-27&limit=25&offset=25')
            ->assertForbidden()->assertJsonPath('error', 'Akses hanya untuk admin.');
        Http::assertSent(function (ClientRequest $request) {
            parse_str(parse_url($request->url(), PHP_URL_QUERY), $query);

            return $query === ['from' => '2026-10-01', 'to' => '2026-10-27', 'limit' => '25', 'offset' => '25'];
        });
    }

    public function test_registration_does_not_create_a_local_or_automatic_session(): void
    {
        Http::fake([self::ORIGIN.'/*' => Http::response(['user' => ['id' => self::ID, 'role' => 'peserta']], 201)]);
        $this->postJson('/presensi/api/auth/register', ['nama_lengkap' => 'Peserta', 'email' => 'peserta@example.test', 'password' => 'password123'])
            ->assertCreated()->assertSessionMissing('presensi');
    }

    public function test_expired_session_is_removed_without_logging_out_simasta(): void
    {
        Http::fake([self::ORIGIN.'/*' => Http::response(['error' => 'Sesi berakhir.'], 401)]);
        $this->withSession($this->presensiSession())->getJson('/presensi/api/me')->assertUnauthorized()
            ->assertSessionMissing('presensi')->assertSessionHas('simasta_marker', 'existing-session');
    }

    public function test_logout_revokes_remote_token_and_rotates_csrf_without_destroying_simasta_session(): void
    {
        Http::fake([self::ORIGIN.'/*' => Http::response(['message' => 'Logout berhasil.'])]);
        $this->withSession($this->presensiSession())->call('POST', '/presensi/api/auth/logout', [], [], [],
            ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'], '{}')->assertOk()
            ->assertSessionMissing('presensi')->assertSessionHas('simasta_marker', 'existing-session')->assertJsonStructure(['csrf_token']);
        Http::assertSent(fn (ClientRequest $request) => $request->url() === self::ORIGIN.'/api/auth/logout'
            && $request->hasHeader('Authorization', 'Bearer android-api-token'));
    }

    public function test_password_change_keeps_spaces_and_clears_only_presensi_session(): void
    {
        Http::fake([self::ORIGIN.'/*' => Http::response(['message' => 'Password diubah.'])]);
        $this->withSession($this->presensiSession())->postJson('/presensi/api/auth/password', [
            'current_password' => ' old password ', 'new_password' => ' new password ',
        ])->assertOk()->assertSessionMissing('presensi')->assertSessionHas('simasta_marker', 'existing-session');
        Http::assertSent(fn (ClientRequest $request) => $request['new_password'] === ' new password '
            && $request['current_password'] === ' old password ');
    }

    public function test_upload_download_and_excel_keep_private_content_out_of_public_storage(): void
    {
        $bytes = "\x89PNG\r\n\x1a\nimage-bytes";
        Http::fake([
            self::ORIGIN.'/api/files' => Http::response(['file' => ['id' => self::ID]], 201),
            self::ORIGIN.'/api/files/'.self::ID => Http::response($bytes, 200, ['Content-Type' => 'image/png']),
            self::ORIGIN.'/api/admin/rekap.xlsx*' => Http::response('excel-bytes', 200, ['Content-Type' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']),
        ]);
        $this->withSession($this->presensiSession())->call('POST', '/presensi/api/files', [], [], [], ['CONTENT_TYPE' => 'image/png'], $bytes)
            ->assertCreated()->assertJsonPath('file.id', self::ID);
        Http::assertSent(fn (ClientRequest $request) => $request->body() === $bytes && $request->hasHeader('Content-Type', 'image/png'));
        $this->get('/presensi/api/files/'.self::ID)->assertOk()->assertContent($bytes)->assertHeader('X-Content-Type-Options', 'nosniff');
        $this->get('/presensi/api/admin/rekap.xlsx?month=10&year=2026')->assertOk()->assertContent('excel-bytes');
    }

    public function test_upload_limits_and_json_validation_prevent_forwarding_invalid_requests(): void
    {
        $this->withSession($this->presensiSession())->call('POST', '/presensi/api/files', [], [], [], ['CONTENT_TYPE' => 'image/png'], str_repeat('x', 5 * 1024 * 1024 + 1))->assertStatus(413);
        $this->call('POST', '/presensi/api/files', [], [], [], ['CONTENT_TYPE' => 'image/svg+xml'], '<svg/>')->assertStatus(415);
        $this->call('POST', '/presensi/api/requests/izin', [], [], [], ['CONTENT_TYPE' => 'application/json'], '[]')->assertStatus(400);
        Http::assertNothingSent();
    }

    public function test_connection_failures_do_not_retry_writes_or_expose_configuration(): void
    {
        $calls = 0;
        Http::fake(function () use (&$calls) {
            $calls++;
            throw new ConnectionException('private internal details');
        });
        $this->withSession($this->presensiSession())->postJson('/presensi/api/attendance/check-in', ['latitude' => -7.8668])->assertStatus(503)
            ->assertDontSee('private internal details')->assertDontSee(self::ORIGIN);
        $this->assertSame(1, $calls);
    }

    public function test_readiness_is_public_and_redirects_are_not_followed(): void
    {
        Http::fake([self::ORIGIN.'/ready' => Http::response(['status' => 'ok', 'database' => 'connected'])]);
        $this->getJson('/presensi/api/ready')->assertOk()->assertJsonPath('database', 'connected');
        Http::assertSent(fn (ClientRequest $request) => ! $request->hasHeader('Authorization'));

        Http::fake([self::ORIGIN.'/*' => Http::response('', 302, ['Location' => 'https://other.example.test'])]);
        $this->withSession($this->presensiSession())->getJson('/presensi/api/me')->assertStatus(502);
    }
}
