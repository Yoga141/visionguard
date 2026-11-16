<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** D2 Perangkat — DOCS_SPEC §12.2 `devices`. */
class Device extends Model
{
    public const PLATFORMS = ['windows', 'macos', 'android', 'ios'];

    public $timestamps = false;

    protected $fillable = ['user_id', 'platform', 'device_name', 'last_seen_at'];

    protected function casts(): array
    {
        return ['last_seen_at' => 'datetime'];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function monitoringDays(): HasMany
    {
        return $this->hasMany(MonitoringDay::class);
    }

    public function dailyStats(): HasMany
    {
        return $this->hasMany(DailyStat::class);
    }
}
