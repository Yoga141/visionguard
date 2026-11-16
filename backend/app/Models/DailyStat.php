<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/** D11 Statistik Harian — DOCS_SPEC §12.2 `daily_stats` (hanya angka, §4.3). */
class DailyStat extends Model
{
    public $timestamps = false;

    protected $fillable = [
        'user_id', 'device_id', 'day', 'screen_minutes', 'avg_blink_rate',
        'avg_distance_cm', 'avg_fatigue_score', 'alerts_count', 'breaks_taken',
    ];

    /** `day` disimpan & dibaca sebagai string `Y-m-d` (tanpa cast, agar perbandingan rentang konsisten). */
    protected function casts(): array
    {
        return [
            'screen_minutes' => 'integer',
            'avg_blink_rate' => 'float',
            'avg_distance_cm' => 'float',
            'avg_fatigue_score' => 'float',
            'alerts_count' => 'integer',
            'breaks_taken' => 'integer',
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
}
