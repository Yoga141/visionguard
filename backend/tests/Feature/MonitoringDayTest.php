<?php

namespace Tests\Feature;

use App\Models\CreditLedger;
use App\Models\Device;
use App\Models\MonitoringDay;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** PMT-01 — algoritma aktivasi Hari Pemantauan AI (DOCS_SPEC §8.2). */
class MonitoringDayTest extends TestCase
{
    use RefreshDatabase;

    private function travelToLocal(string $localDateTime, string $tz = 'Asia/Jakarta'): void
    {
        $this->travelTo(CarbonImmutable::parse($localDateTime, $tz));
    }

    private function activate(?Device $device = null)
    {
        return $this->postJson('/api/monitoring-days/activate', $device ? ['device_id' => $device->id] : []);
    }

    public function test_first_activation_uses_free_quota(): void
    {
        $this->travelToLocal('2026-11-10 09:00');
        [$user, $device] = $this->loginUser();

        $this->activate($device)->assertOk()
            ->assertJsonPath('source', 'free')
            ->assertJsonPath('already_active', false)
            ->assertJsonPath('today', '2026-11-10')
            ->assertJsonPath('today_active', true)
            ->assertJsonPath('free_quota_remaining', 1)
            ->assertJsonPath('credit_balance', 0);

        $this->assertDatabaseHas('monitoring_days', [
            'user_id' => $user->id, 'day' => '2026-11-10', 'source' => 'free', 'device_id' => $device->id,
        ]);
        $this->assertDatabaseCount('credit_ledger', 0);
    }

    public function test_same_day_activation_is_not_charged_twice(): void
    {
        $this->travelToLocal('2026-11-10 09:00');
        [$user] = $this->loginUser();

        $this->activate()->assertOk()->assertJsonPath('already_active', false);
        $this->travelToLocal('2026-11-10 23:59');
        $this->activate()->assertOk()
            ->assertJsonPath('already_active', true)
            ->assertJsonPath('source', 'free')
            ->assertJsonPath('free_quota_remaining', 1);

        $this->assertSame(1, MonitoringDay::where('user_id', $user->id)->count());
    }

    public function test_after_free_quota_one_credit_is_deducted_with_monitoring_day_id(): void
    {
        [$user] = $this->loginUser();
        $this->giveCredits($user, 3);

        $this->travelToLocal('2026-11-01 08:00');
        $this->activate()->assertOk()->assertJsonPath('source', 'free');
        $this->travelToLocal('2026-11-02 08:00');
        $this->activate()->assertOk()->assertJsonPath('source', 'free')->assertJsonPath('free_quota_remaining', 0);

        $this->travelToLocal('2026-11-03 08:00');
        $this->activate()->assertOk()
            ->assertJsonPath('source', 'credit')
            ->assertJsonPath('free_quota_remaining', 0)
            ->assertJsonPath('credit_balance', 2);

        $day = MonitoringDay::where('user_id', $user->id)->where('day', '2026-11-03')->firstOrFail();
        $this->assertSame('credit', $day->source);
        $this->assertDatabaseHas('credit_ledger', [
            'user_id' => $user->id, 'delta' => -1, 'reason' => 'usage', 'monitoring_day_id' => $day->id,
        ]);

        // Hari yang sama lagi → tidak memotong kredit.
        $this->activate()->assertOk()->assertJsonPath('already_active', true)->assertJsonPath('credit_balance', 2);
        $this->assertSame(1, CreditLedger::where('reason', 'usage')->count());
    }

    public function test_returns_402_when_quota_and_credits_are_exhausted(): void
    {
        [$user] = $this->loginUser();
        MonitoringDay::create(['user_id' => $user->id, 'day' => '2026-11-01', 'source' => 'free', 'activated_at' => now()]);
        MonitoringDay::create(['user_id' => $user->id, 'day' => '2026-11-02', 'source' => 'free', 'activated_at' => now()]);

        $this->travelToLocal('2026-11-05 10:00');
        $this->activate()->assertStatus(402)
            ->assertJsonPath('today_active', false)
            ->assertJsonPath('free_quota_remaining', 0)
            ->assertJsonPath('credit_balance', 0)
            ->assertJsonStructure(['message']);

        $this->assertSame(2, MonitoringDay::where('user_id', $user->id)->count());
        $this->assertDatabaseCount('credit_ledger', 0);
    }

    public function test_free_quota_resets_when_month_changes(): void
    {
        [$user] = $this->loginUser();

        $this->travelToLocal('2026-11-29 08:00');
        $this->activate()->assertOk()->assertJsonPath('source', 'free');
        $this->travelToLocal('2026-11-30 08:00');
        $this->activate()->assertOk()->assertJsonPath('source', 'free')->assertJsonPath('free_quota_remaining', 0);

        $this->travelToLocal('2026-12-01 08:00');
        $this->activate()->assertOk()
            ->assertJsonPath('source', 'free')
            ->assertJsonPath('today', '2026-12-01')
            ->assertJsonPath('free_quota_remaining', 1);
    }

    public function test_account_timezone_determines_the_day_and_month(): void
    {
        // 30 Nov 18:00 UTC = 1 Des 01:00 WIB (Asia/Jakarta, UTC+7).
        $this->travelTo(CarbonImmutable::parse('2026-11-30 18:00', 'UTC'));

        [$jakarta] = $this->loginUser(['timezone' => 'Asia/Jakarta']);
        MonitoringDay::create(['user_id' => $jakarta->id, 'day' => '2026-11-01', 'source' => 'free', 'activated_at' => now()]);
        MonitoringDay::create(['user_id' => $jakarta->id, 'day' => '2026-11-02', 'source' => 'free', 'activated_at' => now()]);

        // Sudah bulan Desember bagi akun WIB → kuota November tidak dihitung.
        $this->activate()->assertOk()->assertJsonPath('today', '2026-12-01')->assertJsonPath('source', 'free');

        $this->resetAuth();
        [$london] = $this->loginUser(['timezone' => 'Europe/London']);
        MonitoringDay::create(['user_id' => $london->id, 'day' => '2026-11-01', 'source' => 'free', 'activated_at' => now()]);
        MonitoringDay::create(['user_id' => $london->id, 'day' => '2026-11-02', 'source' => 'free', 'activated_at' => now()]);

        // Masih 30 November bagi akun London → kuota habis.
        $this->activate()->assertStatus(402)->assertJsonPath('today', '2026-11-30');
    }

    public function test_device_of_another_user_is_rejected(): void
    {
        $other = User::factory()->create();
        $foreign = Device::create(['user_id' => $other->id, 'platform' => 'ios', 'device_name' => 'iPhone']);
        $this->loginUser();

        $this->activate($foreign)->assertStatus(422)->assertJsonValidationErrors(['device_id']);
    }

    public function test_requires_token(): void
    {
        $this->postJson('/api/monitoring-days/activate')->assertUnauthorized();
    }
}
