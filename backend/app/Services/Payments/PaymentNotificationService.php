<?php

namespace App\Services\Payments;

use App\Models\CreditLedger;
use App\Models\Order;
use Carbon\CarbonImmutable;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/**
 * Memproses notifikasi pembayaran Midtrans (DOCS_SPEC §8.4 langkah 4, DFD 5.4–5.5).
 * Dipakai oleh endpoint notifikasi, pengecekan Status API, dan halaman simulasi.
 *
 * - Signature: SHA512(order_id + status_code + gross_amount + server_key); salah → 403 + log.
 * - settlement, atau capture dengan fraud_status=accept → order lunas + ledger `purchase`
 *   (+kredit paket), dalam satu transaksi DB, idempoten (`credit_ledger.order_id` UNIQUE).
 * - pending / capture challenge → tidak berubah.
 * - expire / cancel / deny / failure → status order diperbarui, tanpa kredit
 *   (hanya bila order masih pending; order lunas tidak pernah diturunkan).
 */
class PaymentNotificationService
{
    public const RESULT_INVALID_SIGNATURE = 'invalid_signature';

    public const RESULT_UNKNOWN_ORDER = 'unknown_order';

    public const RESULT_AMOUNT_MISMATCH = 'amount_mismatch';

    public const RESULT_SETTLED = 'settled';

    public const RESULT_ALREADY_SETTLED = 'already_settled';

    public const RESULT_STATUS_UPDATED = 'status_updated';

    public const RESULT_IGNORED = 'ignored';

    /** Status Midtrans yang berakhir tanpa kredit → status order (§12.2). */
    private const FINAL_FAILED = [
        'expire' => 'expire',
        'cancel' => 'cancel',
        'deny' => 'deny',
        'failure' => 'deny',
    ];

    public function __construct(private readonly PaymentManager $payments) {}

    public static function signature(string $orderId, string $statusCode, string $grossAmount, string $key): string
    {
        return hash('sha512', $orderId.$statusCode.$grossAmount.$key);
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array{result: string, http_status: int, message: string}
     */
    public function handle(array $payload, ?PaymentGateway $gateway = null): array
    {
        $gateway ??= $this->payments->gateway();

        if (! $this->hasValidSignature($payload, $gateway->signingKey())) {
            Log::warning('Notifikasi pembayaran ditolak: signature tidak valid.', [
                'order_id' => is_scalar($payload['order_id'] ?? null) ? (string) $payload['order_id'] : null,
                'gateway' => $gateway->name(),
                'ip' => request()?->ip(),
            ]);

            return $this->result(self::RESULT_INVALID_SIGNATURE, 403, 'Signature tidak valid.');
        }

        $order = Order::where('order_code', (string) $payload['order_id'])->first();
        if (! $order) {
            Log::warning('Notifikasi pembayaran untuk order tidak dikenal.', ['order_id' => (string) $payload['order_id']]);

            return $this->result(self::RESULT_UNKNOWN_ORDER, 404, 'Order tidak ditemukan.');
        }

        if ((int) round((float) $payload['gross_amount']) !== $order->amount_idr) {
            Log::error('Notifikasi pembayaran: nominal tidak cocok dengan order.', ['order_id' => $order->order_code]);

            return $this->result(self::RESULT_AMOUNT_MISMATCH, 422, 'Nominal tidak cocok.');
        }

        $status = (string) ($payload['transaction_status'] ?? '');
        $fraud = (string) ($payload['fraud_status'] ?? 'accept');

        if ($status === 'settlement' || ($status === 'capture' && $fraud === 'accept')) {
            return $this->settle($order, $payload);
        }

        if (isset(self::FINAL_FAILED[$status]) || ($status === 'capture' && $fraud === 'deny')) {
            return $this->markFailed($order, self::FINAL_FAILED[$status] ?? 'deny');
        }

        // pending, capture challenge, refund, dll. → tidak mengubah apa pun.
        return $this->result(self::RESULT_IGNORED, 200, 'Status dicatat tanpa perubahan.');
    }

    /** @param array<string, mixed> $payload */
    private function hasValidSignature(array $payload, string $key): bool
    {
        foreach (['order_id', 'status_code', 'gross_amount', 'signature_key'] as $field) {
            if (! isset($payload[$field]) || ! is_scalar($payload[$field])) {
                return false;
            }
        }

        if ($key === '') {
            return false;
        }

        $expected = self::signature(
            (string) $payload['order_id'],
            (string) $payload['status_code'],
            (string) $payload['gross_amount'],
            $key,
        );

        return hash_equals($expected, strtolower((string) $payload['signature_key']));
    }

    /** @param array<string, mixed> $payload */
    private function settle(Order $order, array $payload): array
    {
        try {
            return DB::transaction(function () use ($order, $payload) {
                $locked = Order::query()->whereKey($order->id)->lockForUpdate()->with('package')->firstOrFail();

                if ($locked->status === Order::STATUS_SETTLEMENT || $locked->ledgerEntry()->exists()) {
                    return $this->result(self::RESULT_ALREADY_SETTLED, 200, 'Order sudah diproses.');
                }

                $locked->markSettled(
                    is_string($payload['payment_type'] ?? null) ? $payload['payment_type'] : null,
                    $this->paidAt($payload),
                );

                CreditLedger::create([
                    'user_id' => $locked->user_id,
                    'delta' => $locked->package->credits,
                    'reason' => CreditLedger::REASON_PURCHASE,
                    'order_id' => $locked->id,
                ]);

                return $this->result(self::RESULT_SETTLED, 200, 'Pembayaran berhasil, kredit ditambahkan.');
            });
        } catch (UniqueConstraintViolationException) {
            // Notifikasi ganda yang datang bersamaan: ledger sudah tercatat oleh proses lain.
            return $this->result(self::RESULT_ALREADY_SETTLED, 200, 'Order sudah diproses.');
        }
    }

    private function markFailed(Order $order, string $status): array
    {
        return DB::transaction(function () use ($order, $status) {
            $locked = Order::query()->whereKey($order->id)->lockForUpdate()->firstOrFail();

            if ($locked->status !== Order::STATUS_PENDING) {
                return $this->result(self::RESULT_IGNORED, 200, 'Order sudah final.');
            }

            $locked->forceFill(['status' => $status])->save();

            return $this->result(self::RESULT_STATUS_UPDATED, 200, 'Status order diperbarui.');
        });
    }

    /** `settlement_time` Midtrans memakai WIB (Asia/Jakarta). */
    private function paidAt(array $payload): CarbonImmutable
    {
        $time = $payload['settlement_time'] ?? $payload['transaction_time'] ?? null;

        if (is_string($time) && $time !== '') {
            try {
                return CarbonImmutable::parse($time, 'Asia/Jakarta')->utc();
            } catch (Throwable) {
                // format tak dikenal → pakai waktu server
            }
        }

        return CarbonImmutable::now();
    }

    /** @return array{result: string, http_status: int, message: string} */
    private function result(string $result, int $status, string $message): array
    {
        return ['result' => $result, 'http_status' => $status, 'message' => $message];
    }
}
