<?php

namespace App\Services\Payments;

use App\Models\CreditPackage;
use App\Models\Order;
use App\Models\User;

/** Gerbang pembayaran untuk pembelian kredit (DOCS_SPEC §8.4, UC-19). */
interface PaymentGateway
{
    /** `midtrans` | `simulation`. */
    public function name(): string;

    /**
     * Buat transaksi pembayaran untuk order pending.
     *
     * @return array{snap_token: string, redirect_url: string}
     *
     * @throws PaymentGatewayException
     */
    public function createCheckout(Order $order, User $user, CreditPackage $package): array;

    /**
     * Status transaksi terbaru dari penyedia, berformat sama dengan notifikasi
     * Midtrans (termasuk `signature_key`), atau null bila belum ada/tidak tersedia.
     *
     * @return array<string, mixed>|null
     */
    public function fetchStatus(Order $order): ?array;

    /** Kunci untuk memverifikasi `signature_key` notifikasi. Tidak pernah ditampilkan/di-log. */
    public function signingKey(): string;
}
