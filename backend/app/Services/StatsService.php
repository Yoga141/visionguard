<?php

namespace App\Services;

use App\Models\DailyStat;
use App\Models\Device;
use App\Models\User;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/** Statistik harian — DOCS_SPEC §10.3 Seq 4.26, STK-03, UC-17. */
class StatsService
{
    /**
     * Upsert ringkasan harian per (user, device, day). Mengirim hari yang sama
     * dua kali menimpa baris lama, tidak menambah baris baru.
     *
     * @param  list<array<string, mixed>>  $summaries
     * @return list<string> hari yang tersimpan
     */
    public function upsert(User $user, Device $device, array $summaries): array
    {
        return DB::transaction(function () use ($user, $device, $summaries) {
            $days = [];
            foreach ($summaries as $s) {
                $stat = DailyStat::query()
                    ->where('user_id', $user->id)
                    ->where('device_id', $device->id)
                    ->where('day', $s['day'])
                    ->first() ?? new DailyStat([
                        'user_id' => $user->id,
                        'device_id' => $device->id,
                        'day' => $s['day'],
                    ]);

                $stat->fill([
                    'screen_minutes' => $s['screen_minutes'],
                    'avg_blink_rate' => $s['avg_blink_rate'] ?? null,
                    'avg_distance_cm' => $s['avg_distance_cm'] ?? null,
                    'avg_fatigue_score' => $s['avg_fatigue_score'] ?? null,
                    'alerts_count' => $s['alerts_count'],
                    'breaks_taken' => $s['breaks_taken'],
                ])->save();

                $days[] = $s['day'];
            }

            return $days;
        });
    }

    /**
     * Tren [rangeDays] hari terakhir (termasuk hari ini menurut zona waktu akun).
     * Bila ada beberapa perangkat pada hari yang sama, durasi/pengingat/istirahat
     * dijumlahkan dan rata-rata ditimbang dengan `screen_minutes` (§16 #20).
     *
     * @return array{range: int, from: string, to: string, days: list<array<string, mixed>>}
     */
    public function range(User $user, int $rangeDays): array
    {
        $to = $user->localNow();
        $from = $to->subDays($rangeDays - 1);

        $rows = $user->dailyStats()
            ->whereBetween('day', [$from->toDateString(), $to->toDateString()])
            ->orderBy('day')
            ->get()
            ->groupBy(fn (DailyStat $s) => substr((string) $s->day, 0, 10));

        $days = $rows->map(fn (Collection $group, string $day) => [
            'day' => $day,
            'screen_minutes' => (int) $group->sum('screen_minutes'),
            'avg_blink_rate' => $this->weightedAverage($group, 'avg_blink_rate'),
            'avg_distance_cm' => $this->weightedAverage($group, 'avg_distance_cm'),
            'avg_fatigue_score' => $this->weightedAverage($group, 'avg_fatigue_score'),
            'alerts_count' => (int) $group->sum('alerts_count'),
            'breaks_taken' => (int) $group->sum('breaks_taken'),
            'devices' => $group->count(),
        ])->values()->all();

        return [
            'range' => $rangeDays,
            'from' => $from->toDateString(),
            'to' => $to->toDateString(),
            'days' => $days,
        ];
    }

    private function weightedAverage(Collection $group, string $field): ?float
    {
        $withValue = $group->filter(fn (DailyStat $s) => $s->{$field} !== null);
        if ($withValue->isEmpty()) {
            return null;
        }

        $weight = $withValue->sum('screen_minutes');
        if ($weight <= 0) {
            return round($withValue->avg($field), 2);
        }

        $total = $withValue->sum(fn (DailyStat $s) => $s->{$field} * $s->screen_minutes);

        return round($total / $weight, 2);
    }
}
