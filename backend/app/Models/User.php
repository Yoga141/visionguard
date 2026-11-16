<?php

namespace App\Models;

use Carbon\CarbonImmutable;
use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

/**
 * D1 Pengguna — DOCS_SPEC §12.2 `users`, §13.2.
 *
 * Kolom sandi bernama `password_hash` sesuai SDD (bukan `password` bawaan Laravel).
 *
 * @property int $id
 * @property string $name
 * @property string $email
 * @property string $password_hash
 * @property string $role
 * @property string $timezone
 */
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasApiTokens, HasFactory;

    public const ROLE_USER = 'user';

    public const ROLE_ADMIN = 'admin';

    /** Tabel hanya punya `created_at` (§12.2). */
    public const UPDATED_AT = null;

    /** Nama kolom sandi untuk guard/Hash bawaan Laravel. */
    protected $authPasswordName = 'password_hash';

    protected $fillable = ['name', 'email', 'password_hash', 'role', 'timezone'];

    protected $hidden = ['password_hash'];

    protected function casts(): array
    {
        return [
            'password_hash' => 'hashed',
            'created_at' => 'datetime',
        ];
    }

    public function devices(): HasMany
    {
        return $this->hasMany(Device::class);
    }

    public function orders(): HasMany
    {
        return $this->hasMany(Order::class);
    }

    public function creditLedger(): HasMany
    {
        return $this->hasMany(CreditLedger::class);
    }

    public function monitoringDays(): HasMany
    {
        return $this->hasMany(MonitoringDay::class);
    }

    public function dailyStats(): HasMany
    {
        return $this->hasMany(DailyStat::class);
    }

    public function isAdmin(): bool
    {
        return $this->role === self::ROLE_ADMIN;
    }

    /** Saldo kredit = SUM(delta) seluruh ledger milik pengguna (§8.3, KMN-03). */
    public function creditBalance(): int
    {
        return (int) $this->creditLedger()->sum('delta');
    }

    /** Waktu sekarang menurut zona waktu akun (§8.1: hari kalender akun). */
    public function localNow(): CarbonImmutable
    {
        return CarbonImmutable::now($this->timezone);
    }

    /** Tanggal hari ini (`Y-m-d`) menurut zona waktu akun (§8.2 langkah 5.2.1). */
    public function today(): string
    {
        return $this->localNow()->toDateString();
    }

    /**
     * Sisa kuota gratis bulan berjalan = kuota − jumlah hari `source='free'`
     * pada bulan kalender saat ini menurut `users.timezone` (§8.1, §8.2 5.2.3).
     */
    public function freeQuotaRemaining(): int
    {
        $now = $this->localNow();

        $used = $this->monitoringDays()
            ->where('source', MonitoringDay::SOURCE_FREE)
            ->whereBetween('day', [
                $now->startOfMonth()->toDateString(),
                $now->endOfMonth()->toDateString(),
            ])
            ->count();

        return max(0, (int) config('visionguard.free_days_per_month') - $used);
    }
}
