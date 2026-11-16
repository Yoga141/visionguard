<?php

namespace Tests\Feature\Payments;

use App\Models\CreditLedger;
use App\Models\User;
use App\Services\Payments\MidtransGateway;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Mockery;

/**
 * Model access key baru Midtrans (DOCS_SPEC §8.4, §16 #30):
 * signature_key = SHA512(order_id + status_code + gross_amount + SIGNATURE_SECRET_KEY);
 * Server Key tetap untuk otorisasi API. Secret kosong → fallback Server Key + peringatan.
 */
class SignatureSecretKeyTest extends PaymentTestCase
{
    private const URL = '/api/payments/midtrans/notification';

    public function test_notification_signed_with_signature_secret_is_accepted(): void
    {
        $this->useMidtransWithSignatureSecret();
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->postJson(self::URL, $this->notification($order, key: self::DUMMY_SIGNATURE_SECRET))->assertOk();

        $this->assertSame('settlement', $order->fresh()->status);
        $this->assertSame(5, $user->creditBalance());
    }

    public function test_server_key_signature_is_rejected_when_secret_is_set(): void
    {
        Log::spy();
        $this->useMidtransWithSignatureSecret();
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->postJson(self::URL, $this->notification($order, key: self::DUMMY_SERVER_KEY))->assertForbidden();

        $this->assertSame('pending', $order->fresh()->status);
        $this->assertDatabaseCount('credit_ledger', 0);
        Log::shouldNotHaveReceived('warning', [Mockery::on(fn ($m) => str_contains((string) $m, 'SIGNATURE_SECRET_KEY kosong')), Mockery::any()]);
    }

    public function test_duplicate_notifications_with_secret_are_idempotent(): void
    {
        $this->useMidtransWithSignatureSecret();
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);
        $payload = $this->notification($order, key: self::DUMMY_SIGNATURE_SECRET);

        $this->postJson(self::URL, $payload)->assertOk();
        $this->postJson(self::URL, $payload)->assertOk();
        $this->postJson(self::URL, $this->notification($order, ['transaction_status' => 'capture'], self::DUMMY_SIGNATURE_SECRET))
            ->assertOk();

        $this->assertSame(1, CreditLedger::where('order_id', $order->id)->count());
        $this->assertSame(5, $user->creditBalance());
    }

    public function test_empty_secret_falls_back_to_server_key_and_logs_warning_once(): void
    {
        Log::spy();
        $this->useMidtrans(); // secret kosong
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);
        $payload = $this->notification($order, key: self::DUMMY_SERVER_KEY);

        $this->postJson(self::URL, $payload)->assertOk();
        $this->postJson(self::URL, $payload)->assertOk(); // ganda → tetap sekali

        $this->assertSame(5, $user->creditBalance());
        Log::shouldHaveReceived('warning')
            ->with(Mockery::on(fn ($m) => str_starts_with((string) $m, 'MIDTRANS_SIGNATURE_SECRET_KEY kosong; verifikasi notifikasi memakai Server Key')))
            ->once();
    }

    public function test_api_calls_still_authorize_with_server_key_when_secret_is_set(): void
    {
        $this->useMidtransWithSignatureSecret();
        [$user] = $this->loginUser();
        $order = $this->pendingOrder($user);
        Http::fake([
            MidtransGateway::SNAP_SANDBOX => Http::response(['token' => 't', 'redirect_url' => 'https://x'], 201),
            'api.sandbox.midtrans.com/*' => Http::response(
                $this->notification($order, key: self::DUMMY_SIGNATURE_SECRET),
            ),
        ]);

        $this->postJson('/api/orders', ['package_id' => $order->package_id])->assertCreated();
        // Status API (cadangan notifikasi) diverifikasi dengan secret yang sama.
        $this->getJson('/api/orders/'.$order->order_code)->assertOk()->assertJsonPath('order.status', 'settlement');

        $basic = 'Basic '.base64_encode(self::DUMMY_SERVER_KEY.':');
        Http::assertSent(fn (Request $r) => $r->hasHeader('Authorization', $basic));
        Http::assertNotSent(fn (Request $r) => $r->hasHeader('Authorization', 'Basic '.base64_encode(self::DUMMY_SIGNATURE_SECRET.':')));
    }
}
