<?php

namespace App\Models;

use App\Services\Payments\PaymentNotificationService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

/** D8 Order — DOCS_SPEC §12.2 `orders`, §8.4. */
class Order extends Model
{
    public const STATUS_PENDING = 'pending';

    public const STATUS_SETTLEMENT = 'settlement';

    public const STATUSES = ['pending', 'settlement', 'expire', 'cancel', 'deny'];

    public const UPDATED_AT = null;

    protected $fillable = [
        'user_id', 'package_id', 'order_code', 'amount_idr', 'status', 'payment_type', 'paid_at',
    ];

    protected function casts(): array
    {
        return [
            'amount_idr' => 'integer',
            'paid_at' => 'datetime',
            'created_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function package(): BelongsTo
    {
        return $this->belongsTo(CreditPackage::class, 'package_id');
    }

    public function ledgerEntry(): HasOne
    {
        return $this->hasOne(CreditLedger::class);
    }

    /**
     * Tandai order lunas (§8.4 langkah 4). Penambahan kredit ke ledger dilakukan
     * oleh {@see PaymentNotificationService} dalam transaksi yang sama.
     */
    public function markSettled(?string $paymentType = null, ?\DateTimeInterface $paidAt = null): void
    {
        $this->forceFill([
            'status' => self::STATUS_SETTLEMENT,
            'payment_type' => $paymentType,
            'paid_at' => $paidAt ?? now(),
        ])->save();
    }
}
