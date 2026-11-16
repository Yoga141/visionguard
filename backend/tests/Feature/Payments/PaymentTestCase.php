<?php

namespace Tests\Feature\Payments;

use App\Models\CreditPackage;
use App\Models\Order;
use App\Models\User;
use App\Services\Payments\MidtransGateway;
use App\Services\Payments\PaymentNotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/** Dasar test pembayaran. Key di sini DUMMY, bukan key Midtrans asli. */
abstract class PaymentTestCase extends TestCase
{
    use RefreshDatabase;

    protected const DUMMY_SERVER_KEY = 'dummy-server-key-for-tests';

    /** Model access key baru boleh berisi ~ dan . — sengaja dipakai di dummy. */
    protected const DUMMY_SIGNATURE_SECRET = 'dummy~signature.secret-for-tests';

    protected function setUp(): void
    {
        parent::setUp();
        MidtransGateway::resetFallbackWarning();
    }

    /** Midtrans tanpa Signature Secret Key (fallback format lama: server key). */
    protected function useMidtrans(): void
    {
        config([
            'visionguard.payment_mode' => 'midtrans',
            'services.midtrans.server_key' => self::DUMMY_SERVER_KEY,
            'services.midtrans.signature_secret_key' => '',
            'services.midtrans.is_production' => false,
        ]);
    }

    /** Midtrans dengan Signature Secret Key (model access key baru). */
    protected function useMidtransWithSignatureSecret(): void
    {
        $this->useMidtrans();
        config(['services.midtrans.signature_secret_key' => self::DUMMY_SIGNATURE_SECRET]);
    }

    protected function package(array $attributes = []): CreditPackage
    {
        return CreditPackage::create($attributes + ['name' => 'Paket Hemat', 'credits' => 5, 'price_idr' => 15000]);
    }

    protected function pendingOrder(User $user, ?CreditPackage $package = null, string $code = 'VG-TEST-0001'): Order
    {
        $package ??= $this->package();

        return Order::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'order_code' => $code,
            'amount_idr' => $package->price_idr,
            'status' => 'pending',
        ]);
    }

    /** Notifikasi berformat Midtrans, ditandatangani dengan [key]. */
    protected function notification(Order $order, array $overrides = [], ?string $key = self::DUMMY_SERVER_KEY): array
    {
        $payload = array_merge([
            'order_id' => $order->order_code,
            'status_code' => '200',
            'gross_amount' => number_format($order->amount_idr, 2, '.', ''),
            'transaction_status' => 'settlement',
            'fraud_status' => 'accept',
            'payment_type' => 'qris',
            'transaction_time' => '2026-11-16 09:58:00',
            'settlement_time' => '2026-11-16 10:00:00',
        ], $overrides);

        $payload['signature_key'] ??= PaymentNotificationService::signature(
            $payload['order_id'], $payload['status_code'], $payload['gross_amount'], (string) $key,
        );

        return $payload;
    }
}
