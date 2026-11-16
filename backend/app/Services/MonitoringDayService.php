<?php

namespace App\Services;

use App\Models\CreditLedger;
use App\Models\Device;
use App\Models\MonitoringDay;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Status kredit & aktivasi Hari Pemantauan AI — DOCS_SPEC §8.1–8.3,
 * DFD L3 5.2, Activity 4.7, Seq 4.21.
 */
class MonitoringDayService
{
    public const RESULT_ACTIVE = 'active';

    public const RESULT_INSUFFICIENT = 'insufficient';

    /**
     * Algoritma §8.2, dalam satu transaksi DB. Baris user dikunci
     * (`lockForUpdate`) agar dua aktivasi bersamaan tidak memotong dua kali.
     *
     * @return array{result: string, already_active: bool, source: ?string, status: array<string, mixed>}
     */
    public function activateToday(User $user, ?Device $device = null): array
    {
        return DB::transaction(function () use ($user, $device) {
            User::query()->whereKey($user->id)->lockForUpdate()->first();

            // 5.2.1 Tanggal hari ini menurut zona waktu akun.
            $today = $user->today();

            // 5.2.2 Sudah aktif → kembalikan status, tidak memotong apa pun.
            $existing = $this->dayRecord($user, $today);
            if ($existing) {
                return $this->activeResult($user, $existing, alreadyActive: true);
            }

            // 5.2.3 Kuota gratis bulan berjalan.
            if ($user->freeQuotaRemaining() > 0) {
                $day = $this->createDay($user, $today, MonitoringDay::SOURCE_FREE, $device);

                return $this->activeResult($user, $day, alreadyActive: false);
            }

            // 5.2.4 Saldo kredit ≥ 1.
            $cost = (int) config('visionguard.credits_per_day');
            if ($user->creditBalance() >= $cost) {
                $day = $this->createDay($user, $today, MonitoringDay::SOURCE_CREDIT, $device);
                CreditLedger::create([
                    'user_id' => $user->id,
                    'delta' => -$cost,
                    'reason' => CreditLedger::REASON_USAGE,
                    'monitoring_day_id' => $day->id,
                ]);

                return $this->activeResult($user, $day, alreadyActive: false);
            }

            // Tidak cukup → 402.
            return [
                'result' => self::RESULT_INSUFFICIENT,
                'already_active' => false,
                'source' => null,
                'status' => $this->status($user),
            ];
        });
    }

    /**
     * Respons `GET /credits/status` (KRD-01, UC-18).
     *
     * @return array<string, mixed>
     */
    public function status(User $user): array
    {
        $today = $user->today();
        $day = $this->dayRecord($user, $today);

        return [
            'today' => $today,
            'timezone' => $user->timezone,
            'today_active' => $day !== null,
            'today_source' => $day?->source,
            'free_quota_remaining' => $user->freeQuotaRemaining(),
            'free_quota_per_month' => (int) config('visionguard.free_days_per_month'),
            'credit_balance' => $user->creditBalance(),
            'updated_at' => now()->toIso8601String(),
        ];
    }

    private function dayRecord(User $user, string $day): ?MonitoringDay
    {
        return $user->monitoringDays()->where('day', $day)->first();
    }

    private function createDay(User $user, string $day, string $source, ?Device $device): MonitoringDay
    {
        return MonitoringDay::create([
            'user_id' => $user->id,
            'day' => $day,
            'source' => $source,
            'device_id' => $device?->id,
            'activated_at' => now(),
        ]);
    }

    /** @return array{result: string, already_active: bool, source: ?string, status: array<string, mixed>} */
    private function activeResult(User $user, MonitoringDay $day, bool $alreadyActive): array
    {
        return [
            'result' => self::RESULT_ACTIVE,
            'already_active' => $alreadyActive,
            'source' => $day->source,
            'status' => $this->status($user),
        ];
    }
}
