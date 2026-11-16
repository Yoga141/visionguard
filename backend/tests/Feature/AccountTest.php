<?php

namespace Tests\Feature;

use App\Models\CreditLedger;
use App\Models\CreditPackage;
use App\Models\DailyStat;
use App\Models\Device;
use App\Models\MonitoringDay;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** UC-05 Hapus akun — DOCS_SPEC §8.7, Seq 4.28, PRV-02. */
class AccountTest extends TestCase
{
    use RefreshDatabase;

    /** @return array{User, string, Order, MonitoringDay} */
    private function userWithData(): array
    {
        $user = User::factory()->create();
        $device = Device::create(['user_id' => $user->id, 'platform' => 'android', 'device_name' => 'HP']);
        $token = $user->createToken('android:HP')->plainTextToken;
        $user->createToken('windows:PC');

        $package = CreditPackage::create(['name' => 'Paket Hemat', 'credits' => 5, 'price_idr' => 15000]);
        $order = Order::create([
            'user_id' => $user->id, 'package_id' => $package->id, 'order_code' => 'VG-DEL-1',
            'amount_idr' => 15000, 'status' => 'settlement', 'paid_at' => now(),
        ]);
        CreditLedger::create(['user_id' => $user->id, 'delta' => 5, 'reason' => 'purchase', 'order_id' => $order->id]);
        $day = MonitoringDay::create([
            'user_id' => $user->id, 'day' => '2026-11-16', 'source' => 'credit', 'device_id' => $device->id, 'activated_at' => now(),
        ]);
        CreditLedger::create(['user_id' => $user->id, 'delta' => -1, 'reason' => 'usage', 'monitoring_day_id' => $day->id]);
        DailyStat::create([
            'user_id' => $user->id, 'device_id' => $device->id, 'day' => '2026-11-16',
            'screen_minutes' => 60, 'alerts_count' => 1, 'breaks_taken' => 1,
        ]);

        return [$user, $token, $order, $day];
    }

    public function test_wrong_password_returns_403_and_deletes_nothing(): void
    {
        [$user, $token] = $this->userWithData();

        $this->withToken($token)->deleteJson('/api/me', ['password' => 'salah'])
            ->assertForbidden()
            ->assertJsonStructure(['message']);

        $this->assertDatabaseHas('users', ['id' => $user->id]);
        $this->assertSame(1, Device::count());
        $this->assertSame(1, DailyStat::count());
        $this->assertDatabaseCount('personal_access_tokens', 2);
    }

    public function test_password_is_required(): void
    {
        [, $token] = $this->userWithData();

        $this->withToken($token)->deleteJson('/api/me')->assertStatus(422)->assertJsonValidationErrors(['password']);
    }

    public function test_delete_removes_personal_data_and_anonymizes_transactions(): void
    {
        [$user, $token, $order, $day] = $this->userWithData();
        $other = User::factory()->create();
        $other->createToken('lain');

        $this->withToken($token)->deleteJson('/api/me', ['password' => 'password123'])->assertOk();

        // Dihapus
        $this->assertDatabaseMissing('users', ['id' => $user->id]);
        $this->assertSame(0, Device::count());
        $this->assertSame(0, DailyStat::count());
        $this->assertDatabaseMissing('personal_access_tokens', ['tokenable_id' => $user->id]);
        $this->assertDatabaseCount('personal_access_tokens', 1); // token pengguna lain tetap

        // Dianonimkan (baris tetap ada untuk audit)
        $this->assertNull($order->fresh()->user_id);
        $this->assertSame(2, CreditLedger::whereNull('user_id')->count());
        $fresh = $day->fresh();
        $this->assertNull($fresh->user_id);
        $this->assertNull($fresh->device_id);

        // Token tidak berlaku lagi
        $this->resetAuth();
        $this->withToken($token)->getJson('/api/me')->assertUnauthorized();
    }
}
