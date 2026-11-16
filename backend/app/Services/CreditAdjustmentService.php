<?php

namespace App\Services;

use App\Models\CreditLedger;
use App\Models\User;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Penyesuaian kredit manual oleh admin — DOCS_SPEC §8.5, UC-24, Seq 4.30
 * (`CreditAdjustmentController` di SDD; dipakai aksi Filament A-03).
 * Admin hanya bisa mengubah kredit lewat entri ledger `adjustment`.
 */
class CreditAdjustmentService
{
    /**
     * @return int saldo terbaru
     *
     * @throws ValidationException alasan kosong, delta 0, atau saldo akhir negatif
     */
    public function adjust(User $user, int $delta, ?string $note): int
    {
        $note = trim((string) $note);

        if ($note === '') {
            throw ValidationException::withMessages(['note' => 'Alasan penyesuaian wajib diisi.']);
        }
        if (mb_strlen($note) > 255) {
            throw ValidationException::withMessages(['note' => 'Alasan maksimal 255 karakter.']);
        }
        if ($delta === 0) {
            throw ValidationException::withMessages(['delta' => 'Jumlah kredit tidak boleh 0.']);
        }

        return DB::transaction(function () use ($user, $delta, $note) {
            User::query()->whereKey($user->id)->lockForUpdate()->first();

            $balance = $user->creditBalance();
            if ($balance + $delta < 0) {
                throw ValidationException::withMessages([
                    'delta' => "Saldo akhir tidak boleh negatif (saldo saat ini {$balance}).",
                ]);
            }

            CreditLedger::create([
                'user_id' => $user->id,
                'delta' => $delta,
                'reason' => CreditLedger::REASON_ADJUSTMENT,
                'note' => $note,
            ]);

            return $balance + $delta;
        });
    }
}
