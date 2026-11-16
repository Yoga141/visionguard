<?php

namespace App\Services\Payments;

use App\Models\CreditPackage;
use App\Models\Order;
use App\Models\User;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\PendingRequest;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/**
 * Midtrans Snap lewat HTTP client (DOCS_SPEC §8.4).
 * Sandbox bila `MIDTRANS_IS_PRODUCTION=false`. Server key hanya dibaca dari
 * `config('services.midtrans.server_key')` dan tidak pernah di-log.
 */
class MidtransGateway implements PaymentGateway
{
    public const SNAP_SANDBOX = 'https://app.sandbox.midtrans.com/snap/v1/transactions';

    public const SNAP_PRODUCTION = 'https://app.midtrans.com/snap/v1/transactions';

    public const API_SANDBOX = 'https://api.sandbox.midtrans.com/v2';

    public const API_PRODUCTION = 'https://api.midtrans.com/v2';

    public function name(): string
    {
        return PaymentManager::MODE_MIDTRANS;
    }

    /** Peringatan fallback cukup sekali per proses. */
    private static bool $warnedFallback = false;

    /**
     * Kunci verifikasi `signature_key` (notifikasi & Status API):
     * SHA512(order_id + status_code + gross_amount + KUNCI).
     * - Model access key baru: `MIDTRANS_SIGNATURE_SECRET_KEY`.
     * - Kosong → Server Key (format lama) + peringatan di log.
     * Server Key tetap dipakai untuk otorisasi API (Basic auth).
     */
    public function signingKey(): string
    {
        $secret = (string) config('services.midtrans.signature_secret_key');
        if ($secret !== '') {
            return $secret;
        }

        if (! self::$warnedFallback) {
            Log::warning('MIDTRANS_SIGNATURE_SECRET_KEY kosong; verifikasi notifikasi memakai Server Key (format lama). '
                .'Isi Signature Secret Key dari Dashboard Midtrans → Settings → Access Keys.');
            self::$warnedFallback = true;
        }

        return $this->serverKey();
    }

    /** Hanya untuk test: izinkan peringatan fallback muncul lagi. */
    public static function resetFallbackWarning(): void
    {
        self::$warnedFallback = false;
    }

    private function serverKey(): string
    {
        return (string) config('services.midtrans.server_key');
    }

    public function createCheckout(Order $order, User $user, CreditPackage $package): array
    {
        $payload = [
            'transaction_details' => [
                'order_id' => $order->order_code,
                'gross_amount' => $order->amount_idr,
            ],
            'item_details' => [[
                'id' => 'PKG-'.$package->id,
                'price' => $order->amount_idr,
                'quantity' => 1,
                'name' => Str::limit($package->name.' ('.$package->credits.' kredit)', 50, ''),
            ]],
            'customer_details' => [
                'first_name' => Str::limit($user->name, 50, ''),
                'email' => $user->email,
            ],
            'callbacks' => [
                'finish' => route('payments.finish'),
            ],
        ];

        try {
            $response = $this->client()->post($this->snapUrl(), $payload);
        } catch (ConnectionException) {
            throw new PaymentGatewayException('Midtrans tidak dapat dihubungi.');
        }

        $token = $response->json('token');
        $redirect = $response->json('redirect_url');

        if (! $response->successful() || ! is_string($token) || ! is_string($redirect)) {
            Log::error('Midtrans Snap gagal membuat transaksi', [
                'order_code' => $order->order_code,
                'http_status' => $response->status(),
            ]);

            throw new PaymentGatewayException('Gagal membuat transaksi pembayaran.');
        }

        return ['snap_token' => $token, 'redirect_url' => $redirect];
    }

    public function fetchStatus(Order $order): ?array
    {
        try {
            $response = $this->client()->get($this->apiUrl().'/'.rawurlencode($order->order_code).'/status');
        } catch (ConnectionException) {
            return null;
        }

        $data = $response->json();

        // Belum ada transaksi di Midtrans (pengguna belum memilih metode bayar) → status_code 404.
        if (! $response->successful() || ! is_array($data) || ! isset($data['signature_key'])) {
            return null;
        }

        return $data;
    }

    private function client(): PendingRequest
    {
        return Http::withBasicAuth($this->serverKey(), '')
            ->acceptJson()
            ->asJson()
            ->timeout((int) config('services.midtrans.timeout'));
    }

    private function snapUrl(): string
    {
        return config('services.midtrans.is_production') ? self::SNAP_PRODUCTION : self::SNAP_SANDBOX;
    }

    private function apiUrl(): string
    {
        return config('services.midtrans.is_production') ? self::API_PRODUCTION : self::API_SANDBOX;
    }
}
