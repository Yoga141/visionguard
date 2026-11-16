<?php

namespace App\Services;

use App\Models\CreditPackage;
use App\Models\Order;
use App\Models\User;
use App\Services\Payments\PaymentGatewayException;
use App\Services\Payments\PaymentManager;
use App\Services\Payments\PaymentNotificationService;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

/** Pembuatan order & sinkron status (DOCS_SPEC §8.4, DFD 5.3). */
class OrderService
{
    public function __construct(
        private readonly PaymentManager $payments,
        private readonly PaymentNotificationService $notifications,
    ) {}

    /**
     * Order `pending` dengan harga dari server, lalu transaksi Snap/simulasi.
     * Bila gerbang gagal, order dihapus lagi (belum pernah terlihat pengguna).
     *
     * @return array{order: Order, snap_token: string, redirect_url: string, payment_mode: string}
     *
     * @throws PaymentGatewayException
     */
    public function create(User $user, CreditPackage $package): array
    {
        $gateway = $this->payments->gateway();

        $order = Order::create([
            'user_id' => $user->id,
            'package_id' => $package->id,
            'order_code' => $this->newOrderCode(),
            'amount_idr' => $package->price_idr,
            'status' => Order::STATUS_PENDING,
        ]);

        try {
            $checkout = $gateway->createCheckout($order, $user, $package);
        } catch (PaymentGatewayException $e) {
            $order->delete();

            throw $e;
        }

        return [
            'order' => $order->load('package'),
            'snap_token' => $checkout['snap_token'],
            'redirect_url' => $checkout['redirect_url'],
            'payment_mode' => $gateway->name(),
        ];
    }

    /**
     * Cadangan bila notifikasi terlambat: order pending dicek ke Status API
     * Midtrans dan diproses dengan logika notifikasi yang sama (tetap idempoten).
     */
    public function refresh(Order $order): Order
    {
        if ($order->status !== Order::STATUS_PENDING || $this->payments->isSimulation()) {
            return $order;
        }

        $gateway = $this->payments->gateway();
        $status = $gateway->fetchStatus($order);

        if ($status !== null) {
            $result = $this->notifications->handle($status, $gateway);
            if ($result['http_status'] !== 200) {
                Log::warning('Status API Midtrans tidak dapat diproses.', [
                    'order_code' => $order->order_code,
                    'result' => $result['result'],
                ]);
            }
        }

        return $order->fresh('package');
    }

    private function newOrderCode(): string
    {
        do {
            $code = config('visionguard.order_code_prefix').'-'.now()->format('ymdHis').'-'.Str::upper(Str::random(6));
        } while (Order::where('order_code', $code)->exists());

        return $code;
    }
}
