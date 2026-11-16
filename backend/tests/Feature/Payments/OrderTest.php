<?php

namespace Tests\Feature\Payments;

use App\Models\Order;
use App\Models\User;
use App\Services\Payments\MidtransGateway;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;

/** POST /orders, GET /orders/{order_code} dengan Midtrans Snap (Http::fake, key dummy). */
class OrderTest extends PaymentTestCase
{
    protected function setUp(): void
    {
        parent::setUp();
        $this->useMidtrans();
    }

    private function fakeSnap(): void
    {
        Http::fake([
            'app.sandbox.midtrans.com/snap/v1/transactions' => Http::response([
                'token' => 'snap-token-123',
                'redirect_url' => 'https://app.sandbox.midtrans.com/snap/v4/redirection/snap-token-123',
            ], 201),
        ]);
    }

    public function test_create_order_requests_snap_and_returns_token(): void
    {
        $this->fakeSnap();
        [$user] = $this->loginUser(['name' => 'Budi', 'email' => 'budi@contoh.id']);
        $package = $this->package(['name' => 'Paket Reguler', 'credits' => 12, 'price_idr' => 30000]);

        $res = $this->postJson('/api/orders', ['package_id' => $package->id])->assertCreated()
            ->assertJsonPath('snap_token', 'snap-token-123')
            ->assertJsonPath('redirect_url', 'https://app.sandbox.midtrans.com/snap/v4/redirection/snap-token-123')
            ->assertJsonPath('payment_mode', 'midtrans')
            ->assertJsonPath('order.status', 'pending')
            ->assertJsonPath('order.amount_idr', 30000)
            ->assertJsonPath('order.credits', 12);

        $code = $res->json('order_code');
        $this->assertMatchesRegularExpression('/^VG-\d{12}-[A-Z0-9]{6}$/', $code);
        $this->assertDatabaseHas('orders', [
            'order_code' => $code, 'user_id' => $user->id, 'package_id' => $package->id, 'amount_idr' => 30000, 'status' => 'pending',
        ]);

        Http::assertSent(function (Request $request) use ($code) {
            $data = $request->data();

            return $request->url() === MidtransGateway::SNAP_SANDBOX
                && $request->hasHeader('Authorization', 'Basic '.base64_encode(self::DUMMY_SERVER_KEY.':'))
                && $data['transaction_details'] === ['order_id' => $code, 'gross_amount' => 30000]
                && $data['item_details'][0]['price'] === 30000
                && $data['item_details'][0]['quantity'] === 1
                && str_contains($data['item_details'][0]['name'], 'Paket Reguler')
                && $data['customer_details'] === ['first_name' => 'Budi', 'email' => 'budi@contoh.id']
                && $data['callbacks']['finish'] === route('payments.finish');
        });
    }

    public function test_production_flag_uses_production_snap_url(): void
    {
        config(['services.midtrans.is_production' => true]);
        Http::fake([MidtransGateway::SNAP_PRODUCTION => Http::response(['token' => 't', 'redirect_url' => 'https://x'], 201)]);
        $this->loginUser();

        $this->postJson('/api/orders', ['package_id' => $this->package()->id])->assertCreated();
        Http::assertSent(fn (Request $r) => $r->url() === MidtransGateway::SNAP_PRODUCTION);
    }

    public function test_inactive_or_missing_package_returns_422(): void
    {
        $this->fakeSnap();
        $this->loginUser();
        $inactive = $this->package(['name' => 'Paket Lama', 'is_active' => false]);

        $this->postJson('/api/orders', ['package_id' => $inactive->id])->assertStatus(422)->assertJsonValidationErrors(['package_id']);
        $this->postJson('/api/orders', ['package_id' => 999])->assertStatus(422);
        $this->postJson('/api/orders', [])->assertStatus(422);

        Http::assertNothingSent();
        $this->assertDatabaseCount('orders', 0);
    }

    public function test_snap_failure_returns_503_and_leaves_no_order(): void
    {
        Http::fake(['app.sandbox.midtrans.com/*' => Http::response(['error_messages' => ['Access denied']], 401)]);
        $this->loginUser();

        $this->postJson('/api/orders', ['package_id' => $this->package()->id])
            ->assertStatus(503)
            ->assertJsonStructure(['message']);

        $this->assertDatabaseCount('orders', 0);
    }

    public function test_create_order_requires_token(): void
    {
        $this->postJson('/api/orders', ['package_id' => $this->package()->id])->assertUnauthorized();
    }

    public function test_show_returns_own_order_only(): void
    {
        Http::fake(); // Status API tidak terpanggil untuk order non-pending
        [$user] = $this->loginUser();
        $order = $this->pendingOrder($user);
        $order->forceFill(['status' => 'expire'])->save();

        $this->getJson('/api/orders/'.$order->order_code)->assertOk()
            ->assertJsonPath('order.order_code', $order->order_code)
            ->assertJsonPath('order.status', 'expire')
            ->assertJsonPath('credit_balance', 0);

        $other = User::factory()->create();
        $foreign = $this->pendingOrder($other, code: 'VG-ORANG-LAIN');
        $this->getJson('/api/orders/'.$foreign->order_code)->assertNotFound();
        $this->getJson('/api/orders/VG-TIDAK-ADA')->assertNotFound();

        Http::assertNothingSent();
    }

    public function test_show_pending_order_checks_status_api_and_credits_once(): void
    {
        [$user] = $this->loginUser();
        $order = $this->pendingOrder($user);
        $statusUrl = MidtransGateway::API_SANDBOX.'/'.$order->order_code.'/status';
        Http::fake([$statusUrl => Http::response($this->notification($order, ['payment_type' => 'gopay']))]);

        $this->getJson('/api/orders/'.$order->order_code)->assertOk()
            ->assertJsonPath('order.status', 'settlement')
            ->assertJsonPath('order.payment_type', 'gopay')
            ->assertJsonPath('credit_balance', 5);

        // Notifikasi yang datang belakangan tidak menambah kredit lagi.
        $this->postJson('/api/payments/midtrans/notification', $this->notification($order))->assertOk();
        $this->getJson('/api/orders/'.$order->order_code)->assertOk()->assertJsonPath('credit_balance', 5);

        Http::assertSentCount(1);
        Http::assertSent(fn (Request $r) => $r->url() === $statusUrl && $r->method() === 'GET');
    }

    public function test_show_pending_order_stays_pending_when_midtrans_has_no_transaction(): void
    {
        [$user] = $this->loginUser();
        $order = $this->pendingOrder($user);
        Http::fake(['api.sandbox.midtrans.com/*' => Http::response([
            'status_code' => '404', 'status_message' => "Transaction doesn't exist.",
        ])]);

        $this->getJson('/api/orders/'.$order->order_code)->assertOk()->assertJsonPath('order.status', 'pending');
        $this->assertSame('pending', Order::first()->status);
    }

    public function test_status_api_with_forged_signature_is_ignored(): void
    {
        [$user] = $this->loginUser();
        $order = $this->pendingOrder($user);
        Http::fake(['api.sandbox.midtrans.com/*' => Http::response($this->notification($order, key: 'palsu'))]);

        $this->getJson('/api/orders/'.$order->order_code)->assertOk()->assertJsonPath('order.status', 'pending');
        $this->assertDatabaseCount('credit_ledger', 0);
    }

    public function test_history_shows_new_order(): void
    {
        $this->fakeSnap();
        $this->loginUser();
        $code = $this->postJson('/api/orders', ['package_id' => $this->package()->id])->json('order_code');

        $this->getJson('/api/credits/history')->assertOk()
            ->assertJsonPath('orders.0.order_code', $code)
            ->assertJsonPath('orders.0.status', 'pending');
    }
}
