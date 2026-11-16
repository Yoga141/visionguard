<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

/** D6 Hari Pemantauan — DOCS_SPEC §12.2 `monitoring_days`, §8.1–8.2. */
class MonitoringDay extends Model
{
    public const SOURCE_FREE = 'free';

    public const SOURCE_CREDIT = 'credit';

    public $timestamps = false;

    protected $fillable = ['user_id', 'day', 'source', 'device_id', 'activated_at'];

    /** `day` disimpan & dibaca sebagai string `Y-m-d` (tanpa cast, agar perbandingan rentang konsisten). */
    protected function casts(): array
    {
        return [
            'activated_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function device(): BelongsTo
    {
        return $this->belongsTo(Device::class);
    }

    /** Baris ledger `usage` (−1) bila hari ini dibayar dengan kredit. */
    public function ledgerEntry(): HasOne
    {
        return $this->hasOne(CreditLedger::class);
    }
}
