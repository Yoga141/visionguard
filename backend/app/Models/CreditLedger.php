<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use LogicException;

/**
 * D7 Ledger Kredit — DOCS_SPEC §12.2 `credit_ledger`, §8.3.
 *
 * **Append-only**: baris yang sudah tersimpan tidak boleh diubah atau dihapus
 * lewat model. Satu-satunya perubahan pada baris lama adalah `user_id → NULL`
 * oleh foreign key `ON DELETE SET NULL` saat akun dihapus (anonimisasi, §8.7).
 */
class CreditLedger extends Model
{
    public const REASON_PURCHASE = 'purchase';

    public const REASON_USAGE = 'usage';

    public const REASON_ADJUSTMENT = 'adjustment';

    protected $table = 'credit_ledger';

    public const UPDATED_AT = null;

    protected $fillable = ['user_id', 'delta', 'reason', 'order_id', 'monitoring_day_id', 'note'];

    protected function casts(): array
    {
        return [
            'delta' => 'integer',
            'created_at' => 'datetime',
        ];
    }

    protected static function booted(): void
    {
        static::updating(function () {
            throw new LogicException('credit_ledger bersifat append-only: baris tidak boleh diubah.');
        });

        static::deleting(function () {
            throw new LogicException('credit_ledger bersifat append-only: baris tidak boleh dihapus.');
        });
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    public function monitoringDay(): BelongsTo
    {
        return $this->belongsTo(MonitoringDay::class);
    }
}
