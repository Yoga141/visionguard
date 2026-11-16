<?php

namespace Tests\Feature;

use App\Models\DailyStat;
use App\Models\Device;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** STK-03 sinkron ringkasan harian, UC-17 tren 7/30 hari. */
class StatsTest extends TestCase
{
    use RefreshDatabase;

    private function summary(string $day, array $overrides = []): array
    {
        return array_merge([
            'day' => $day,
            'screen_minutes' => 120,
            'avg_blink_rate' => 14.5,
            'avg_distance_cm' => 55.0,
            'avg_fatigue_score' => 32.0,
            'alerts_count' => 4,
            'breaks_taken' => 3,
        ], $overrides);
    }

    public function test_daily_upsert_twice_keeps_one_row(): void
    {
        [$user, $device] = $this->loginUser();

        $this->postJson('/api/stats/daily', ['device_id' => $device->id, 'summaries' => [$this->summary('2026-11-15')]])
            ->assertOk()->assertJsonPath('synced_days', ['2026-11-15']);

        $this->postJson('/api/stats/daily', ['device_id' => $device->id, 'summaries' => [
            $this->summary('2026-11-15', ['screen_minutes' => 200, 'alerts_count' => 6, 'avg_distance_cm' => null]),
            $this->summary('2026-11-16'),
        ]])->assertOk()->assertJsonPath('synced_days', ['2026-11-15', '2026-11-16']);

        $this->assertSame(2, DailyStat::where('user_id', $user->id)->count());
        $row = DailyStat::where('day', '2026-11-15')->firstOrFail();
        $this->assertSame(200, $row->screen_minutes);
        $this->assertSame(6, $row->alerts_count);
        $this->assertNull($row->avg_distance_cm);
    }

    public function test_daily_upsert_validates_payload(): void
    {
        $other = User::factory()->create();
        $foreign = Device::create(['user_id' => $other->id, 'platform' => 'ios', 'device_name' => 'iPhone']);
        [, $device] = $this->loginUser();

        $this->postJson('/api/stats/daily', ['device_id' => $foreign->id, 'summaries' => [$this->summary('2026-11-15')]])
            ->assertStatus(422)->assertJsonValidationErrors(['device_id']);

        $this->postJson('/api/stats/daily', ['device_id' => $device->id, 'summaries' => [
            $this->summary('15-11-2026', ['screen_minutes' => -1, 'avg_fatigue_score' => 140]),
        ]])->assertStatus(422)->assertJsonValidationErrors([
            'summaries.0.day', 'summaries.0.screen_minutes', 'summaries.0.avg_fatigue_score',
        ]);

        $this->postJson('/api/stats/daily', ['device_id' => $device->id, 'summaries' => []])
            ->assertStatus(422)->assertJsonValidationErrors(['summaries']);
    }

    public function test_range_returns_days_within_window(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-11-16 10:00', 'Asia/Jakarta'));
        [$user, $device] = $this->loginUser();

        foreach (['2026-11-01', '2026-11-09', '2026-11-10', '2026-11-16'] as $day) {
            DailyStat::create(['user_id' => $user->id, 'device_id' => $device->id] + $this->summary($day));
        }

        $this->getJson('/api/stats?range=7')->assertOk()
            ->assertJsonPath('range', 7)
            ->assertJsonPath('from', '2026-11-10')
            ->assertJsonPath('to', '2026-11-16')
            ->assertJsonCount(2, 'days')
            ->assertJsonPath('days.0.day', '2026-11-10')
            ->assertJsonPath('days.1.day', '2026-11-16');

        $this->getJson('/api/stats?range=30')->assertOk()->assertJsonCount(4, 'days');
        $this->getJson('/api/stats')->assertOk()->assertJsonPath('range', 7);
        $this->getJson('/api/stats?range=14')->assertStatus(422)->assertJsonValidationErrors(['range']);
    }

    public function test_range_merges_devices_and_hides_other_users(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-11-16 10:00', 'Asia/Jakarta'));
        [$user, $pc] = $this->loginUser();
        $phone = Device::create(['user_id' => $user->id, 'platform' => 'android', 'device_name' => 'HP']);

        DailyStat::create(['user_id' => $user->id, 'device_id' => $pc->id] + $this->summary('2026-11-16', [
            'screen_minutes' => 90, 'avg_blink_rate' => 10.0, 'alerts_count' => 2, 'breaks_taken' => 1,
        ]));
        DailyStat::create(['user_id' => $user->id, 'device_id' => $phone->id] + $this->summary('2026-11-16', [
            'screen_minutes' => 30, 'avg_blink_rate' => 18.0, 'alerts_count' => 1, 'breaks_taken' => 1, 'avg_distance_cm' => null,
        ]));

        $other = User::factory()->create();
        $otherDevice = Device::create(['user_id' => $other->id, 'platform' => 'ios', 'device_name' => 'X']);
        DailyStat::create(['user_id' => $other->id, 'device_id' => $otherDevice->id] + $this->summary('2026-11-16'));

        $this->getJson('/api/stats?range=7')->assertOk()
            ->assertJsonCount(1, 'days')
            ->assertJsonPath('days.0.screen_minutes', 120)
            ->assertJsonPath('days.0.avg_blink_rate', 12) // (10·90 + 18·30) / 120
            ->assertJsonPath('days.0.avg_distance_cm', 55)
            ->assertJsonPath('days.0.alerts_count', 3)
            ->assertJsonPath('days.0.breaks_taken', 2)
            ->assertJsonPath('days.0.devices', 2);
    }
}
