<?php

namespace Tests\Feature;

use App\Models\Device;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

/** UC-01, UC-02, UC-04, KMN-02 — DOCS_SPEC §8.7. */
class AuthTest extends TestCase
{
    use RefreshDatabase;

    private function registerPayload(array $overrides = []): array
    {
        return array_merge([
            'name' => 'Budi',
            'email' => 'Budi@Contoh.id',
            'password' => 'rahasia123',
            'platform' => 'android',
            'device_name' => 'Pixel 7',
        ], $overrides);
    }

    private function loginPayload(string $password = 'password123', array $overrides = []): array
    {
        return array_merge([
            'email' => 'demo@visionguard.id',
            'password' => $password,
            'platform' => 'windows',
            'device_name' => 'Laptop',
        ], $overrides);
    }

    public function test_register_returns_201_with_token_and_records_device(): void
    {
        $res = $this->postJson('/api/auth/register', $this->registerPayload());

        $res->assertCreated()
            ->assertJsonStructure(['token', 'token_type', 'device_id', 'user' => ['id', 'name', 'email', 'role', 'timezone']])
            ->assertJsonPath('user.email', 'budi@contoh.id')
            ->assertJsonPath('user.role', 'user')
            ->assertJsonPath('user.timezone', 'Asia/Jakarta')
            ->assertJsonMissingPath('user.password_hash');

        $user = User::where('email', 'budi@contoh.id')->firstOrFail();
        $this->assertTrue(Hash::check('rahasia123', $user->password_hash));
        $this->assertNotSame('rahasia123', $user->password_hash);
        $this->assertDatabaseHas('devices', [
            'id' => $res->json('device_id'), 'user_id' => $user->id, 'platform' => 'android', 'device_name' => 'Pixel 7',
        ]);
    }

    public function test_register_with_taken_email_returns_422(): void
    {
        User::factory()->create(['email' => 'budi@contoh.id']);

        $this->postJson('/api/auth/register', $this->registerPayload())
            ->assertStatus(422)
            ->assertJsonValidationErrors(['email'])
            ->assertJsonPath('errors.email.0', 'Email sudah terdaftar. Silakan login atau reset kata sandi.');
    }

    public function test_register_validates_fields(): void
    {
        $this->postJson('/api/auth/register', $this->registerPayload([
            'email' => 'bukan-email', 'password' => '123', 'platform' => 'linux', 'timezone' => 'Mars/Olympus',
        ]))->assertStatus(422)->assertJsonValidationErrors(['email', 'password', 'platform', 'timezone']);
    }

    public function test_login_returns_200_with_token_and_updates_device(): void
    {
        $user = User::factory()->create(['email' => 'demo@visionguard.id']);

        $first = $this->postJson('/api/auth/login', $this->loginPayload())->assertOk()
            ->assertJsonStructure(['token', 'device_id', 'user'])
            ->assertJsonPath('user.email', 'demo@visionguard.id');

        $this->travel(1)->hours();
        $second = $this->postJson('/api/auth/login', $this->loginPayload())->assertOk();

        // Perangkat yang sama tidak diduplikasi; last_seen_at diperbarui.
        $this->assertSame($first->json('device_id'), $second->json('device_id'));
        $this->assertSame(1, Device::where('user_id', $user->id)->count());
        $this->assertTrue(Device::find($second->json('device_id'))->last_seen_at->greaterThan(now()->subMinute()));
    }

    public function test_login_with_wrong_password_returns_401(): void
    {
        User::factory()->create(['email' => 'demo@visionguard.id']);

        $this->postJson('/api/auth/login', $this->loginPayload('salah'))
            ->assertUnauthorized()
            ->assertJsonPath('message', 'Email atau kata sandi salah.');

        $this->postJson('/api/auth/login', $this->loginPayload('password123', ['email' => 'tidakada@contoh.id']))
            ->assertUnauthorized();
    }

    public function test_five_failed_logins_lock_account_for_five_minutes(): void
    {
        User::factory()->create(['email' => 'demo@visionguard.id']);

        for ($i = 0; $i < 5; $i++) {
            $this->postJson('/api/auth/login', $this->loginPayload('salah'))->assertUnauthorized();
        }

        // Percobaan ke-6, walau sandi benar, ditahan.
        $this->postJson('/api/auth/login', $this->loginPayload())
            ->assertStatus(429)
            ->assertHeader('Retry-After')
            ->assertJsonStructure(['message', 'retry_after']);

        $this->travel(4)->minutes();
        $this->postJson('/api/auth/login', $this->loginPayload())->assertStatus(429);

        $this->travel(61)->seconds();
        $this->postJson('/api/auth/login', $this->loginPayload())->assertOk();
    }

    public function test_successful_login_resets_failure_counter(): void
    {
        User::factory()->create(['email' => 'demo@visionguard.id']);

        for ($i = 0; $i < 4; $i++) {
            $this->postJson('/api/auth/login', $this->loginPayload('salah'))->assertUnauthorized();
        }
        $this->postJson('/api/auth/login', $this->loginPayload())->assertOk();

        for ($i = 0; $i < 4; $i++) {
            $this->postJson('/api/auth/login', $this->loginPayload('salah'))->assertUnauthorized();
        }
        $this->postJson('/api/auth/login', $this->loginPayload())->assertOk();
    }

    public function test_logout_revokes_current_token(): void
    {
        User::factory()->create(['email' => 'demo@visionguard.id']);
        $token = $this->postJson('/api/auth/login', $this->loginPayload())->json('token');

        $this->withToken($token)->getJson('/api/me')->assertOk();
        $this->withToken($token)->postJson('/api/auth/logout')->assertOk();

        $this->resetAuth();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
        $this->assertDatabaseCount('personal_access_tokens', 0);
    }

    public function test_me_requires_token_and_returns_profile(): void
    {
        $this->getJson('/api/me')->assertUnauthorized()->assertJsonPath('message', 'Unauthenticated.');
        // Tanpa header Accept tetap JSON.
        $this->get('/api/me')->assertUnauthorized()->assertHeader('Content-Type', 'application/json');

        [$user] = $this->loginUser(['role' => 'admin']);
        $this->getJson('/api/me')->assertOk()
            ->assertJsonPath('user.id', $user->id)
            ->assertJsonPath('user.role', 'admin');
    }
}
