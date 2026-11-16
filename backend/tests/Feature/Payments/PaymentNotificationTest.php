<?php

namespace Tests\Feature\Payments;

use App\Models\CreditLedger;
use App\Models\User;
use Illuminate\Support\Facades\Log;

/** POST /payments/midtrans/notification — DOCS_SPEC §8.4 langkah 4, KMN-03. */
class PaymentNotificationTest extends PaymentTestCase
{
    private const URL = '/api/payments/midtrans/notification';

    protected function setUp(): void
    {
        parent::setUp();
        $this->useMidtrans();
    }

    public function test_invalid_signature_is_rejected_with_403_and_logged(): void
    {
        Log::spy();
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->postJson(self::URL, $this->notification($order, key: 'kunci-salah'))->assertForbidden();
        $this->postJson(self::URL, $this->notification($order, ['signature_key' => str_repeat('a', 128)]))->assertForbidden();
        $this->postJson(self::URL, ['order_id' => $order->order_code, 'transaction_status' => 'settlement'])->assertForbidden();

        // Payload diubah setelah ditandatangani (nominal) → signature tidak cocok.
        $tampered = $this->notification($order);
        $tampered['gross_amount'] = '1.00';
        $this->postJson(self::URL, $tampered)->assertForbidden();

        Log::shouldHaveReceived('warning')->with('Notifikasi pembayaran ditolak: signature tidak valid.', \Mockery::any())->times(4);
        $this->assertSame('pending', $order->fresh()->status);
        $this->assertDatabaseCount('credit_ledger', 0);
    }

    public function test_settlement_adds_package_credits_once(): void
    {
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->postJson(self::URL, $this->notification($order))->assertOk();

        $fresh = $order->fresh();
        $this->assertSame('settlement', $fresh->status);
        $this->assertSame('qris', $fresh->payment_type);
        $this->assertSame('2026-11-16 03:00:00', $fresh->paid_at->utc()->format('Y-m-d H:i:s')); // 10:00 WIB
        $this->assertDatabaseHas('credit_ledger', [
            'user_id' => $user->id, 'delta' => 5, 'reason' => 'purchase', 'order_id' => $order->id,
        ]);
        $this->assertSame(5, $user->creditBalance());
    }

    public function test_duplicate_settlement_notifications_are_idempotent(): void
    {
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);
        $payload = $this->notification($order);

        $this->postJson(self::URL, $payload)->assertOk();
        $this->postJson(self::URL, $payload)->assertOk();
        $this->postJson(self::URL, $this->notification($order, ['transaction_status' => 'capture']))->assertOk();

        $this->assertSame(1, CreditLedger::where('order_id', $order->id)->count());
        $this->assertSame(5, $user->creditBalance());
    }

    public function test_capture_with_fraud_accept_adds_credits(): void
    {
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->postJson(self::URL, $this->notification($order, [
            'transaction_status' => 'capture', 'fraud_status' => 'accept', 'payment_type' => 'credit_card',
        ]))->assertOk();

        $this->assertSame('settlement', $order->fresh()->status);
        $this->assertSame(5, $user->creditBalance());
    }

    public function test_capture_with_fraud_challenge_keeps_order_pending(): void
    {
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->postJson(self::URL, $this->notification($order, [
            'transaction_status' => 'capture', 'fraud_status' => 'challenge',
        ]))->assertOk();

        $this->assertSame('pending', $order->fresh()->status);
        $this->assertSame(0, $user->creditBalance());
    }

    public function test_expire_cancel_deny_update_status_without_credit(): void
    {
        $user = User::factory()->create();
        $package = $this->package();

        foreach (['expire' => 'expire', 'cancel' => 'cancel', 'deny' => 'deny', 'failure' => 'deny'] as $midtrans => $expected) {
            $order = $this->pendingOrder($user, $package, 'VG-'.$midtrans);
            $this->postJson(self::URL, $this->notification($order, [
                'transaction_status' => $midtrans, 'status_code' => '407',
            ]))->assertOk();

            $this->assertSame($expected, $order->fresh()->status, $midtrans);
            $this->assertNull($order->fresh()->paid_at);
        }

        $this->assertDatabaseCount('credit_ledger', 0);
    }

    public function test_pending_notification_changes_nothing(): void
    {
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->postJson(self::URL, $this->notification($order, ['transaction_status' => 'pending', 'status_code' => '201']))
            ->assertOk();

        $this->assertSame('pending', $order->fresh()->status);
        $this->assertDatabaseCount('credit_ledger', 0);
    }

    public function test_settled_order_is_never_downgraded(): void
    {
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $this->postJson(self::URL, $this->notification($order))->assertOk();
        $this->postJson(self::URL, $this->notification($order, ['transaction_status' => 'expire', 'status_code' => '407']))
            ->assertOk();

        $this->assertSame('settlement', $order->fresh()->status);
        $this->assertSame(5, $user->creditBalance());
    }

    public function test_unknown_order_and_amount_mismatch_are_rejected(): void
    {
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        $ghost = $this->notification($order, ['order_id' => 'VG-TIDAK-ADA']);
        $this->postJson(self::URL, $ghost)->assertNotFound();

        // Signature valid tetapi nominal berbeda dari harga order.
        $this->postJson(self::URL, $this->notification($order, ['gross_amount' => '1000.00']))->assertStatus(422);

        $this->assertSame('pending', $order->fresh()->status);
        $this->assertDatabaseCount('credit_ledger', 0);
    }

    public function test_endpoint_needs_no_token_or_csrf(): void
    {
        $user = User::factory()->create();
        $order = $this->pendingOrder($user);

        // Midtrans mengirim JSON tanpa header Accept/Authorization/CSRF.
        $this->call('POST', self::URL, [], [], [], ['CONTENT_TYPE' => 'application/json'], json_encode($this->notification($order)))
            ->assertOk();

        $this->assertSame('settlement', $order->fresh()->status);
    }
}
