<?php

namespace Tests\Feature;

use App\Models\User;
use App\Notifications\ResetPasswordNotification;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Notification;
use Illuminate\Support\Facades\Password;
use Tests\TestCase;

/** UC-03 Reset kata sandi — DOCS_SPEC §8.7 (token 60 menit, 404, 422). */
class PasswordResetTest extends TestCase
{
    use RefreshDatabase;

    private function user(): User
    {
        return User::factory()->create(['email' => 'budi@contoh.id', 'name' => 'Budi']);
    }

    public function test_forgot_password_for_unknown_email_returns_404(): void
    {
        Notification::fake();

        $this->postJson('/api/auth/forgot-password', ['email' => 'tidakada@contoh.id'])
            ->assertNotFound()
            ->assertJsonPath('message', 'Email tidak terdaftar.');

        Notification::assertNothingSent();
    }

    public function test_forgot_password_sends_reset_link(): void
    {
        Notification::fake();
        $user = $this->user();

        $this->postJson('/api/auth/forgot-password', ['email' => 'Budi@Contoh.id'])->assertOk()->assertJsonStructure(['message']);

        Notification::assertSentTo($user, ResetPasswordNotification::class, function (ResetPasswordNotification $n) use ($user) {
            $mail = $n->toMail($user);

            return str_contains($mail->actionUrl, '/reset-password/'.$n->token)
                && str_contains($mail->actionUrl, 'email=budi%40contoh.id')
                && $mail->subject === 'Reset kata sandi VisionGuard';
        });
        $this->assertDatabaseHas('password_reset_tokens', ['email' => 'budi@contoh.id']);
    }

    public function test_forgot_password_is_throttled(): void
    {
        Notification::fake();
        $this->user();

        $this->postJson('/api/auth/forgot-password', ['email' => 'budi@contoh.id'])->assertOk();
        $this->postJson('/api/auth/forgot-password', ['email' => 'budi@contoh.id'])->assertStatus(429);
    }

    public function test_reset_with_valid_token_changes_password_and_revokes_tokens(): void
    {
        $user = $this->user();
        $user->createToken('android:HP');
        $token = Password::broker()->createToken($user);

        $this->postJson('/api/auth/reset-password', [
            'email' => 'budi@contoh.id',
            'token' => $token,
            'password' => 'sandiBaru123',
            'password_confirmation' => 'sandiBaru123',
        ])->assertOk()->assertJsonPath('message', 'Kata sandi berhasil diganti. Silakan login.');

        $this->assertTrue(Hash::check('sandiBaru123', $user->fresh()->password_hash));
        $this->assertDatabaseCount('personal_access_tokens', 0);
        $this->assertDatabaseMissing('password_reset_tokens', ['email' => 'budi@contoh.id']);

        $this->postJson('/api/auth/login', [
            'email' => 'budi@contoh.id', 'password' => 'sandiBaru123', 'platform' => 'android', 'device_name' => 'HP',
        ])->assertOk();

        // Token yang sama tidak bisa dipakai dua kali.
        $this->postJson('/api/auth/reset-password', [
            'email' => 'budi@contoh.id', 'token' => $token, 'password' => 'lainLagi123', 'password_confirmation' => 'lainLagi123',
        ])->assertStatus(422);
    }

    public function test_reset_with_invalid_token_returns_422(): void
    {
        $this->user();

        $this->postJson('/api/auth/reset-password', [
            'email' => 'budi@contoh.id',
            'token' => 'token-palsu',
            'password' => 'sandiBaru123',
            'password_confirmation' => 'sandiBaru123',
        ])->assertStatus(422)->assertJsonValidationErrors(['token']);

        $this->assertTrue(Hash::check('password123', User::first()->password_hash));
    }

    public function test_reset_token_expires_after_60_minutes(): void
    {
        $user = $this->user();
        $token = Password::broker()->createToken($user);

        $this->travel(61)->minutes();

        $this->postJson('/api/auth/reset-password', [
            'email' => 'budi@contoh.id', 'token' => $token, 'password' => 'sandiBaru123', 'password_confirmation' => 'sandiBaru123',
        ])->assertStatus(422)->assertJsonValidationErrors(['token']);
    }

    public function test_reset_requires_matching_confirmation(): void
    {
        $user = $this->user();
        $token = Password::broker()->createToken($user);

        $this->postJson('/api/auth/reset-password', [
            'email' => 'budi@contoh.id', 'token' => $token, 'password' => 'sandiBaru123', 'password_confirmation' => 'beda12345',
        ])->assertStatus(422)->assertJsonValidationErrors(['password']);
    }

    public function test_web_reset_form(): void
    {
        $user = $this->user();
        $token = Password::broker()->createToken($user);

        $this->get(route('password.reset', ['token' => $token, 'email' => 'budi@contoh.id']))
            ->assertOk()
            ->assertSee('Buat kata sandi baru')
            ->assertSee('budi@contoh.id');

        // Token salah → kembali ke form dengan pesan.
        $this->from(route('password.reset', ['token' => 'x']))
            ->post(route('password.update'), [
                'email' => 'budi@contoh.id', 'token' => 'x', 'password' => 'sandiBaru123', 'password_confirmation' => 'sandiBaru123',
            ])->assertRedirect(route('password.reset', ['token' => 'x']))->assertSessionHasErrors('token');

        $this->post(route('password.update'), [
            'email' => 'budi@contoh.id', 'token' => $token, 'password' => 'sandiBaru123', 'password_confirmation' => 'sandiBaru123',
        ])->assertOk()->assertSee('Kata sandi berhasil diganti');

        $this->assertTrue(Hash::check('sandiBaru123', $user->fresh()->password_hash));
    }
}
