<?php

namespace Tests\Feature\Payments;

use App\Models\Order;
use App\Models\User;
use App\Services\Payments\PaymentManager;
use App\Services\Payments\SimulationGateway;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Mockery;

/** PAYMENT_MODE midtrans/simulation dan fallback saat server key kosong (§16 #25). */
class PaymentModeTest extends PaymentTestCase
{
    public function test_midtrans_mode_with_empty_key_falls_back_to_simulation_and_logs_warning(): void
    {
        Log::spy();
        Http::fake();
        config(['visionguard.payment_mode' => 'midtrans', 'services.midtrans.server_key' => '']);
        $this->loginUser();

        $res = $this->postJson('/api/orders', ['package_id' => $this->package()->id])->assertCreated()
            ->assertJsonPath('payment_mode', 'simulation');

        $code = $res->json('order_code');
        $this->assertSame(route('payments.simulate', $code), $res->json('redirect_url'));
        $this->assertStringStartsWith('SIM-', $res->json('snap_token'));
        Http::assertNothingSent();
        Log::shouldHaveReceived('warning')
            ->with(Mockery::on(fn ($m) => str_starts_with($m, 'PAYMENT_MODE=midtrans tetapi MIDTRANS_SERVER_KEY kosong; memakai mode simulation.')))
            ->once();
    }

    public function test_mode_resolution(): void
    {
        $manager = new PaymentManager;

        config(['visionguard.payment_mode' => 'simulation', 'services.midtrans.server_key' => self::DUMMY_SERVER_KEY]);
        $this->assertSame('simulation', $manager->mode());

        config(['visionguard.payment_mode' => 'midtrans', 'services.midtrans.server_key' => self::DUMMY_SERVER_KEY]);
        $this->assertSame('midtrans', $manager->mode());

        config(['services.midtrans.server_key' => null]);
        $this->assertSame('simulation', $manager->mode());
    }

    public function test_simulation_page_pays_order_with_valid_signed_notification(): void
    {
        config(['visionguard.payment_mode' => 'simulation']);
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->get(route('payments.simulate', $order->order_code))->assertOk()
            ->assertSee($order->order_code)
            ->assertSee('Bayar (berhasil)');

        $this->post(route('payments.simulate.pay', $order->order_code), ['status' => 'settlement'])
            ->assertRedirect(route('payments.finish', ['order_id' => $order->order_code, 'transaction_status' => 'settlement']));

        $this->assertSame('settlement', $order->fresh()->status);
        $this->assertSame('simulation', $order->fresh()->payment_type);
        $this->assertSame(5, $user->creditBalance());

        // Klik dua kali → tetap sekali.
        $this->post(route('payments.simulate.pay', $order->order_code), ['status' => 'settlement']);
        $this->assertSame(5, $user->creditBalance());
    }

    public function test_simulation_expire_gives_no_credit(): void
    {
        config(['visionguard.payment_mode' => 'simulation']);
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->post(route('payments.simulate.pay', $order->order_code), ['status' => 'expire'])
            ->assertRedirect(route('payments.unfinish', ['order_id' => $order->order_code, 'transaction_status' => 'expire']));

        $this->assertSame('expire', $order->fresh()->status);
        $this->assertSame(0, $user->creditBalance());
    }

    public function test_notification_endpoint_in_simulation_mode_accepts_only_simulation_signature(): void
    {
        config(['visionguard.payment_mode' => 'simulation', 'services.midtrans.server_key' => '']);
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        // Ditandatangani dengan key kosong → ditolak.
        $this->postJson('/api/payments/midtrans/notification', $this->notification($order, key: ''))->assertForbidden();

        $payload = app(SimulationGateway::class)->buildNotification($order, 'settlement');
        $this->postJson('/api/payments/midtrans/notification', $payload)->assertOk();
        $this->assertSame(5, $user->creditBalance());
    }

    public function test_simulation_page_is_unavailable_in_midtrans_mode(): void
    {
        $this->useMidtrans();
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->get(route('payments.simulate', $order->order_code))->assertNotFound();
        $this->post(route('payments.simulate.pay', $order->order_code), ['status' => 'settlement'])->assertNotFound();
        $this->assertSame('pending', $order->fresh()->status);
    }

    public function test_simulation_is_refused_in_production(): void
    {
        config(['visionguard.payment_mode' => 'simulation']);
        $this->app['env'] = 'production';
        [$user] = $this->loginUser();
        $order = $this->pendingOrder($user, code: 'VG-PROD');

        $this->postJson('/api/orders', ['package_id' => $order->package_id])->assertStatus(503);
        $this->get(route('payments.simulate', $order->order_code))->assertNotFound();
        $this->assertSame(1, Order::count());
    }

    public function test_result_pages_tell_user_to_return_to_app(): void
    {
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        foreach (['payments.finish', 'payments.unfinish', 'payments.error'] as $route) {
            $this->get(route($route, ['order_id' => $order->order_code, 'transaction_status' => 'settlement']))
                ->assertOk()
                ->assertSee('Kembali ke aplikasi VisionGuard');
        }

        // Status di query string tidak dipercaya: order tetap pending.
        $this->get(route('payments.finish', ['order_id' => $order->order_code]))->assertSee('Menunggu pembayaran');
        $this->assertSame('pending', $order->fresh()->status);

        $this->get(route('payments.finish'))->assertOk();
    }
}
