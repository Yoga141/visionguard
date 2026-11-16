<?php

namespace App\Console\Commands;

use App\Services\Payments\MidtransGateway;
use App\Services\Payments\PaymentManager;
use Illuminate\Console\Command;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Http;

/**
 * Diagnosis konfigurasi pembayaran tanpa membuka rahasia: hanya mode dan
 * status ADA/KOSONG untuk key. `--ping` memverifikasi server key ke Status API
 * Midtrans memakai order fiktif (tidak membuat transaksi apa pun).
 */
class PaymentsCheck extends Command
{
    protected $signature = 'payments:check {--ping : Verifikasi server key ke Midtrans (tanpa membuat transaksi)}';

    protected $description = 'Periksa mode pembayaran & status key Midtrans (nilai key tidak pernah ditampilkan)';

    public function handle(PaymentManager $payments): int
    {
        $state = fn ($v) => ((string) $v === '') ? '<fg=red>KOSONG</>' : '<fg=green>ADA</>';
        $production = (bool) config('services.midtrans.is_production');

        $this->line('PAYMENT_MODE (terbaca)   : '.config('visionguard.payment_mode'));
        $this->line('MIDTRANS_SERVER_KEY      : '.$state(config('services.midtrans.server_key')));
        $this->line('MIDTRANS_CLIENT_KEY      : '.$state(config('services.midtrans.client_key')));
        $this->line('MIDTRANS_SIGNATURE_SECRET_KEY : '.$state(config('services.midtrans.signature_secret_key')));
        // Merchant ID hanya identitas akun (opsional): kosong bukan masalah.
        $this->line('MIDTRANS_MERCHANT_ID     : '.((string) config('services.midtrans.merchant_id') === ''
            ? 'tidak diisi (opsional)' : 'ADA'));
        $this->line('MIDTRANS_IS_PRODUCTION   : '.($production ? 'true (Production)' : 'false (Sandbox)'));
        $this->line('Config cache             : '.(app()->configurationIsCached() ? 'AKTIF (jalankan php artisan config:clear setelah mengubah .env)' : 'tidak ada'));

        $this->formatReport($production);

        $mode = $payments->mode();
        $this->line('Mode efektif             : <options=bold>'.$mode.'</>');

        if ($mode === PaymentManager::MODE_SIMULATION && config('visionguard.payment_mode') === PaymentManager::MODE_MIDTRANS) {
            $this->warn('Server key kosong → memakai simulasi. Isi MIDTRANS_SERVER_KEY di '.base_path('.env')
                .', simpan file, lalu jalankan php artisan config:clear dan restart php artisan serve.');
        }

        if ($mode === PaymentManager::MODE_MIDTRANS) {
            $this->line('Verifikasi signature     : '.((string) config('services.midtrans.signature_secret_key') !== ''
                ? 'Signature Secret Key'
                : '<fg=yellow>Server Key (fallback format lama)</>'));
            if ((string) config('services.midtrans.signature_secret_key') === '') {
                $this->warn('MIDTRANS_SIGNATURE_SECRET_KEY kosong: notifikasi diverifikasi dengan Server Key (format lama). '
                    .'Isi Signature Secret Key dari Dashboard Midtrans → Settings → Access Keys.');
            }
        }

        if (! $this->option('ping') || $mode !== PaymentManager::MODE_MIDTRANS) {
            return self::SUCCESS;
        }

        return $this->ping($production);
    }

    /**
     * Pemeriksaan format TANPA menampilkan nilai: awalan, panjang, dan
     * server/client tertukar. Key model baru Midtrans boleh berisi `~` dan `.`,
     * jadi isi karakter tidak dinilai.
     */
    private function formatReport(bool $production): void
    {
        $env = $production ? '' : 'SB-';
        $server = (string) config('services.midtrans.server_key');
        $client = (string) config('services.midtrans.client_key');
        $yn = fn (bool $b) => $b ? 'ya' : 'tidak';

        foreach (['server' => $server, 'client' => $client] as $type => $value) {
            if ($value === '') {
                continue;
            }
            $prefix = "{$env}Mid-{$type}-";
            $this->line(sprintf(
                'Format %s key        : awalan %s: %s | panjang %d',
                $type, $prefix, $yn(str_starts_with($value, $prefix)), strlen($value),
            ));
        }

        if ($server !== '' && str_starts_with($server, $env.'Mid-client-')) {
            $this->warn('Server key berawalan client key — kemungkinan tertukar.');
        }
    }

    private function ping(bool $production): int
    {
        $base = $production ? MidtransGateway::API_PRODUCTION : MidtransGateway::API_SANDBOX;
        $probe = 'VG-PING-'.now()->format('YmdHis');

        try {
            $response = Http::withBasicAuth((string) config('services.midtrans.server_key'), '')
                ->acceptJson()
                ->timeout((int) config('services.midtrans.timeout'))
                ->get($base.'/'.$probe.'/status');
        } catch (ConnectionException) {
            $this->error('Midtrans tidak dapat dihubungi (periksa koneksi internet).');

            return self::FAILURE;
        }

        // Key valid → "transaksi tidak ada" (status_code 404 di body). Key salah → 401.
        $bodyStatus = (string) $response->json('status_code');
        if ($response->status() === 401 || $bodyStatus === '401') {
            $this->error('Server key DITOLAK Midtrans (401).');
            $this->line('Saran: di Dashboard Midtrans ('.($production ? 'Production' : 'Sandbox').') → Settings → Access Keys, '
                .'buat Server Key baru dengan izin "Snap Checkout: Write" dan "Core API: Read", '
                .'salin nilainya langsung dari pop-up yang muncul (hanya ditampilkan sekali), tempel ke MIDTRANS_SERVER_KEY '
                .'di backend/.env, lalu php artisan config:clear dan restart server.');

            return self::FAILURE;
        }
        if ($bodyStatus === '404') {
            $this->info('Server key DITERIMA Midtrans ('.($production ? 'Production' : 'Sandbox').').');

            return self::SUCCESS;
        }

        $this->warn('Respons Midtrans tidak terduga: HTTP '.$response->status().', status_code '.($bodyStatus ?: '-'));

        return self::FAILURE;
    }
}
