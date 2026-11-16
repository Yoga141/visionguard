<?php

namespace Tests;

use App\Models\CreditLedger;
use App\Models\Device;
use App\Models\User;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Laravel\Sanctum\Sanctum;

abstract class TestCase extends BaseTestCase
{
    /** Pengguna + perangkat, sudah login lewat Sanctum. */
    protected function loginUser(array $attributes = []): array
    {
        $user = User::factory()->create($attributes);
        $device = Device::create([
            'user_id' => $user->id,
            'platform' => 'windows',
            'device_name' => 'PC Uji',
            'last_seen_at' => now(),
        ]);
        Sanctum::actingAs($user);

        return [$user, $device];
    }

    /** Tambah kredit lewat ledger (seperti penyesuaian admin). */
    protected function giveCredits(User $user, int $delta): void
    {
        CreditLedger::create([
            'user_id' => $user->id,
            'delta' => $delta,
            'reason' => CreditLedger::REASON_ADJUSTMENT,
            'note' => 'Kredit uji',
        ]);
    }

    /** Lupakan user yang di-cache guard antar-request dalam satu test. */
    protected function resetAuth(): void
    {
        $this->app['auth']->forgetGuards();
    }
}
