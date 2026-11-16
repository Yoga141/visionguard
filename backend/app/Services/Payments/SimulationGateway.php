<?php

namespace App\Services\Payments;

use App\Models\CreditPackage;
use App\Models\Order;
use App\Models\User;
use Illuminate\Support\Str;

/**
 * Pembayaran tiruan untuk demo & test (PAYMENT_MODE=simulation, atau server key
 * Midtrans kosong). Halaman bayar tiruan mengirim notifikasi berformat Midtrans
 * dengan signature valid, lalu diproses oleh logika yang sama
 * ({@see PaymentNotificationService}). Ditolak saat APP_ENV=production.
 */
class SimulationGateway implements PaymentGateway
{
    public function name(): string
    {
        return PaymentManager::MODE_SIMULATION;
    }

    /** Kunci tanda tangan diturunkan dari APP_KEY (rahasia server, bukan key Midtrans). */
    public function signingKey(): string
    {
        return hash_hmac('sha256', 'visionguard-payment-simulation', (string) config('app.key'));
    }

    public function createCheckout(Order $order, User $user, CreditPackage $package): array
    {
        $this->ensureAllowed();

        return [
            'snap_token' => 'SIM-'.Str::upper(Str::random(24)),
            'redirect_url' => route('payments.simulate', $order->order_code),
        ];
    }

    public function fetchStatus(Order $order): ?array
    {
        return null;
    }

    /**
     * Notifikasi tiruan berformat Midtrans dengan signature valid.
     *
     * @return array<string, string>
     */
    public function buildNotification(Order $order, string $transactionStatus): array
    {
        $statusCode = match ($transactionStatus) {
            'settlement', 'capture' => '200',
            'pending' => '201',
            'deny' => '202',
            default => '407', // expire / cancel
        };
        $gross = number_format($order->amount_idr, 2, '.', '');

        return [
            'order_id' => $order->order_code,
            'status_code' => $statusCode,
            'gross_amount' => $gross,
            'transaction_status' => $transactionStatus,
            'fraud_status' => 'accept',
            'payment_type' => 'simulation',
            'transaction_time' => now('Asia/Jakarta')->format('Y-m-d H:i:s'),
            'settlement_time' => now('Asia/Jakarta')->format('Y-m-d H:i:s'),
            'signature_key' => PaymentNotificationService::signature(
                $order->order_code, $statusCode, $gross, $this->signingKey(),
            ),
        ];
    }

    public function ensureAllowed(): void
    {
        if (app()->isProduction()) {
            throw new PaymentGatewayException('Mode simulasi pembayaran tidak boleh dipakai di produksi.');
        }
    }
}
