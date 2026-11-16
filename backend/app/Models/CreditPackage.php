<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

/** D9 Paket Kredit — DOCS_SPEC §12.2 `credit_packages`, §8.6. */
class CreditPackage extends Model
{
    public $timestamps = false;

    protected $fillable = ['name', 'credits', 'price_idr', 'is_active'];

    protected function casts(): array
    {
        return [
            'credits' => 'integer',
            'price_idr' => 'integer',
            'is_active' => 'boolean',
        ];
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class, 'package_id');
    }

    /** Hanya paket aktif yang tampil di aplikasi (§8.6). */
    public function scopeActive(Builder $query): Builder
    {
        return $query->where('is_active', true);
    }
}
