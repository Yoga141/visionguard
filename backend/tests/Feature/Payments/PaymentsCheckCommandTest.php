<?php

namespace Tests\Feature\Payments;

use App\Services\Payments\MidtransGateway;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

/** php artisan payments:check — diagnosis tanpa menampilkan nilai key. */
class PaymentsCheckCommandTest extends PaymentTestCase
{
    public function test_empty_key_reports_simulation_without_leaking_values(): void
    {
        Http::fake();
        config(['visionguard.payment_mode' => 'midtrans', 'services.midtrans.server_key' => '']);

        $this->artisan('payments:check', ['--ping' => true])
            ->expectsOutputToContain('MIDTRANS_SERVER_KEY      : KOSONG')
            ->expectsOutputToContain('Mode efektif             : simulation')
            ->expectsOutputToContain('Server key kosong')
            ->assertSuccessful();

        Http::assertNothingSent(); // tanpa key, ping tidak dikirim
    }

    public function test_ping_accepts_valid_key_and_never_prints_it(): void
    {
        $this->useMidtrans();
        Http::fake([
            'api.sandbox.midtrans.com/*' => Http::response(['status_code' => '404', 'status_message' => "Transaction doesn't exist."]),
        ]);

        $this->artisan('payments:check', ['--ping' => true])
            ->expectsOutputToContain('MIDTRANS_SERVER_KEY      : ADA')
            ->expectsOutputToContain('Mode efektif             : midtrans')
            ->expectsOutputToContain('Server key DITERIMA Midtrans (Sandbox).')
            ->doesntExpectOutputToContain(self::DUMMY_SERVER_KEY)
            ->assertSuccessful();

        // Hanya Status API (GET) dengan order fiktif — tidak membuat transaksi Snap.
        Http::assertSent(fn (Request $r) => $r->method() === 'GET'
            && str_starts_with($r->url(), MidtransGateway::API_SANDBOX.'/VG-PING-')
            && str_ends_with($r->url(), '/status'));
        Http::assertNotSent(fn (Request $r) => str_contains($r->url(), 'snap'));
    }

    public function test_format_report_accepts_new_key_characters_and_never_prints_values(): void
    {
        Http::fake();
        $server = 'SB-Mid-server-abc~DEF.ghi123456789012'; // model baru: ~ dan . sah
        $client = 'SB-Mid-client-'.str_repeat('a', 24);
        $secret = 'secret~value.for-tests';
        config([
            'visionguard.payment_mode' => 'midtrans',
            'services.midtrans.server_key' => $server,
            'services.midtrans.client_key' => $client,
            'services.midtrans.signature_secret_key' => $secret,
            'services.midtrans.merchant_id' => 'X123456789',
        ]);

        $this->artisan('payments:check')
            ->expectsOutputToContain('Format server key        : awalan SB-Mid-server-: ya | panjang '.strlen($server))
            ->expectsOutputToContain('Format client key        : awalan SB-Mid-client-: ya | panjang 38')
            ->expectsOutputToContain('MIDTRANS_SIGNATURE_SECRET_KEY : ADA')
            ->expectsOutputToContain('Verifikasi signature     : Signature Secret Key')
            ->expectsOutputToContain('MIDTRANS_MERCHANT_ID     : ADA')
            ->doesntExpectOutputToContain('tidak lazim')
            ->doesntExpectOutputToContain('[A-Za-z0-9-_]')
            ->doesntExpectOutputToContain('berbentuk G')
            ->doesntExpectOutputToContain($server)
            ->doesntExpectOutputToContain($client)
            ->doesntExpectOutputToContain($secret)
            ->doesntExpectOutputToContain('X123456789')
            ->assertSuccessful();
    }

    public function test_empty_merchant_id_is_optional_and_empty_secret_warns_fallback(): void
    {
        Http::fake();
        $this->useMidtrans(); // secret kosong
        config(['services.midtrans.merchant_id' => '']);

        $this->artisan('payments:check')
            ->expectsOutputToContain('MIDTRANS_MERCHANT_ID     : tidak diisi (opsional)')
            ->expectsOutputToContain('MIDTRANS_SIGNATURE_SECRET_KEY : KOSONG')
            ->expectsOutputToContain('Verifikasi signature     : Server Key (fallback format lama)')
            ->expectsOutputToContain('MIDTRANS_SIGNATURE_SECRET_KEY kosong: notifikasi diverifikasi dengan Server Key')
            ->assertSuccessful();
    }

    public function test_swapped_keys_are_detected(): void
    {
        Http::fake();
        config([
            'visionguard.payment_mode' => 'midtrans',
            'services.midtrans.server_key' => 'SB-Mid-client-'.str_repeat('b', 24),
        ]);

        $this->artisan('payments:check')
            ->expectsOutputToContain('kemungkinan tertukar')
            ->assertSuccessful();
    }

    public function test_config_trims_whitespace_and_invisible_characters(): void
    {
        putenv("MIDTRANS_SERVER_KEY=  SB-Mid-server-abc\u{200B}def\u{00A0} ");
        $_ENV['MIDTRANS_SERVER_KEY'] = $_SERVER['MIDTRANS_SERVER_KEY'] = "  SB-Mid-server-abc\u{200B}def\u{00A0} ";
        try {
            $config = require base_path('config/services.php');
            $this->assertSame('SB-Mid-server-abcdef', $config['midtrans']['server_key']);
        } finally {
            putenv('MIDTRANS_SERVER_KEY=');
            $_ENV['MIDTRANS_SERVER_KEY'] = $_SERVER['MIDTRANS_SERVER_KEY'] = '';
        }
    }

    public function test_ping_reports_rejected_key(): void
    {
        $this->useMidtrans();
        Http::fake([
            'api.sandbox.midtrans.com/*' => Http::response(['status_code' => '401', 'status_message' => 'Unauthorized'], 401),
        ]);

        $this->artisan('payments:check', ['--ping' => true])
            ->expectsOutputToContain('Server key DITOLAK Midtrans (401)')
            ->expectsOutputToContain('"Snap Checkout: Write" dan "Core API: Read", salin nilainya langsung dari pop-up')
            ->doesntExpectOutputToContain(self::DUMMY_SERVER_KEY)
            ->assertFailed();
    }
}
