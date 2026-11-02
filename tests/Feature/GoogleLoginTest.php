<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Socialite\Facades\Socialite;
use Laravel\Socialite\Two\User as GoogleUser;
use Mockery;
use Tests\TestCase;

class GoogleLoginTest extends TestCase
{
    use RefreshDatabase;

    private function google(string $id, string $email, bool $verified = true): void
    {
        $google = (new GoogleUser)->setRaw(['email_verified' => $verified])->map(['id' => $id, 'email' => $email, 'name' => 'Google User']);
        $provider = Mockery::mock();
        $provider->shouldReceive('user')->once()->andReturn($google);
        Socialite::shouldReceive('driver')->with('google')->once()->andReturn($provider);
    }

    public function test_new_google_user_is_created_and_can_sign_in_again(): void
    {
        $this->google('google-1', 'new@example.com');
        $this->get('/auth/google/callback')->assertRedirect('/mahasiswa/dashboard');
        $user = User::where('email', 'new@example.com')->firstOrFail();
        $this->assertSame('google-1', $user->google_id);
        $this->assertNotNull($user->email_verified_at);
        $this->assertAuthenticatedAs($user);
        $this->post('/logout');
        $this->google('google-1', 'changed@example.com');
        $this->get('/auth/google/callback')->assertRedirect('/mahasiswa/dashboard');
        $this->assertAuthenticatedAs($user);
    }

    public function test_existing_account_requires_its_password_and_keeps_role(): void
    {
        $user = User::factory()->create(['email' => 'admin@example.com', 'password' => 'password123', 'role' => 'admin']);
        $this->google('google-admin', $user->email);
        $this->get('/auth/google/callback')->assertRedirect('/auth/google/confirm');
        $this->assertGuest();
        $this->assertNull($user->fresh()->google_id);
        $this->get('/auth/google/confirm')->assertOk()->assertSee($user->email);
        $this->post('/auth/google/confirm', ['password' => 'wrong'])->assertSessionHasErrors('password');
        $this->assertNull($user->fresh()->google_id);
        $this->post('/auth/google/confirm', ['password' => 'password123'])->assertRedirect('/admin/dashboard');
        $this->assertSame('google-admin', $user->fresh()->google_id);
        $this->assertAuthenticatedAs($user);
    }

    public function test_unverified_email_and_different_linked_google_account_are_rejected(): void
    {
        $this->google('unverified', 'test@example.com', false);
        $this->get('/auth/google/callback')->assertRedirect('/login')->assertSessionHasErrors();
        $this->assertDatabaseMissing('users', ['email' => 'test@example.com']);
        $user = User::factory()->create(['email' => 'linked@example.com']);
        $user->forceFill(['google_id' => 'original'])->save();
        $this->google('other', $user->email);
        $this->get('/auth/google/callback')->assertRedirect('/login')->assertSessionHasErrors();
        $this->assertSame('original', $user->fresh()->google_id);
        $this->assertGuest();
    }

    public function test_confirmation_expires_and_password_login_still_works(): void
    {
        $user = User::factory()->create(['password' => 'password123', 'role' => 'pembimbing']);
        $this->withSession(['google_link' => ['user_id' => $user->id, 'google_id' => 'old', 'expires_at' => now()->subSecond()->timestamp]])
            ->post('/auth/google/confirm', ['password' => 'password123'])->assertRedirect('/login');
        $this->assertNull($user->fresh()->google_id);
        $this->post('/login', ['email' => $user->email, 'password' => 'password123'])->assertRedirect('/pembimbing/dashboard');
        $this->assertAuthenticatedAs($user);
    }
}
