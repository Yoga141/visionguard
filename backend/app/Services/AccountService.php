<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Hapus akun — DOCS_SPEC §8.7, UC-05, Seq 4.28 (UU PDP).
 *
 * - Dihapus: akun (`users`), `devices`, `daily_stats`, semua token Sanctum.
 * - Dianonimkan (`user_id = NULL`, via FK `ON DELETE SET NULL`): `orders`,
 *   `credit_ledger`, `monitoring_days` (§16 #19). Baris ledger tetap ada
 *   sebagai jejak audit; sisa kredit hilang bersama akun.
 */
class AccountService
{
    public function delete(User $user): void
    {
        DB::transaction(function () use ($user) {
            $user->tokens()->delete();
            $user->dailyStats()->delete();
            $user->devices()->delete(); // monitoring_days.device_id → NULL
            $user->delete();             // orders/ledger/monitoring_days.user_id → NULL
        });
    }
}
