<?php

namespace App\Services;

use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Str;

/**
 * KMN-02 / UC-02 alur alternatif 2: setelah 5 kali login gagal berturut-turut
 * (per email + IP), login ditahan 5 menit. Login sukses mereset hitungan.
 */
class LoginThrottle
{
    /** Hitungan gagal dilupakan bila tidak ada percobaan selama 1 jam. */
    private const COUNTER_TTL_SECONDS = 3600;

    public function key(string $email, ?string $ip): string
    {
        return 'login:'.sha1(Str::lower(trim($email)).'|'.$ip);
    }

    /** Sisa detik penahanan, atau 0 bila tidak ditahan. */
    public function lockedFor(string $key): int
    {
        $until = Cache::get($key.':locked_until');

        return $until ? max(0, $until - now()->getTimestamp()) : 0;
    }

    public function recordFailure(string $key): void
    {
        $failures = (int) Cache::get($key.':failures', 0) + 1;

        if ($failures >= (int) config('visionguard.login.max_attempts')) {
            $seconds = (int) config('visionguard.login.lockout_seconds');
            Cache::put($key.':locked_until', now()->getTimestamp() + $seconds, $seconds);
            Cache::forget($key.':failures');

            return;
        }

        Cache::put($key.':failures', $failures, self::COUNTER_TTL_SECONDS);
    }

    public function clear(string $key): void
    {
        Cache::forget($key.':failures');
        Cache::forget($key.':locked_until');
    }
}
