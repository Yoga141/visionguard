<?php

namespace App\Services\Payments;

use Illuminate\Support\Facades\Log;

/**
 * Memilih gerbang pembayaran dari `PAYMENT_MODE` (DOCS_SPEC §16 #25):
 * - `midtrans` + server key terisi → {@see MidtransGateway}
 * - `midtrans` + server key kosong → {@see SimulationGateway} + peringatan di log
 * - `simulation` → {@see SimulationGateway}
 */
class PaymentManager
{
    public const MODE_MIDTRANS = 'midtrans';

    public const MODE_SIMULATION = 'simulation';

    private bool $warned = false;

    public function mode(): string
    {
        $configured = strtolower((string) config('visionguard.payment_mode'));

        if ($configured === self::MODE_SIMULATION) {
            return self::MODE_SIMULATION;
        }

        if ((string) config('services.midtrans.server_key') === '') {
            if (! $this->warned) {
                Log::warning('PAYMENT_MODE=midtrans tetapi MIDTRANS_SERVER_KEY kosong; memakai mode simulation.');
                $this->warned = true;
            }

            return self::MODE_SIMULATION;
        }

        return self::MODE_MIDTRANS;
    }

    public function gateway(): PaymentGateway
    {
        return $this->mode() === self::MODE_MIDTRANS
            ? app(MidtransGateway::class)
            : app(SimulationGateway::class);
    }

    public function isSimulation(): bool
    {
        return $this->mode() === self::MODE_SIMULATION;
    }
}
