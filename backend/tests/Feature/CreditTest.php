<?php

namespace Tests\Feature;

use App\Models\CreditLedger;
use App\Models\CreditPackage;
use App\Models\MonitoringDay;
use App\Models\Order;
use Carbon\CarbonImmutable;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use LogicException;
use Tests\TestCase;

/** KRD-01, KRD-04, §8.3 ledger append-only, §8.6 paket aktif. */
class CreditTest extends TestCase
{
    use RefreshDatabase;

    public function test_status_returns_quota_balance_and_today(): void
    {
        $this->travelTo(CarbonImmutable::parse('2026-11-16 10:00', 'Asia/Jakarta'));
        [$user] = $this->loginUser();
        $this->giveCredits($user, 5);
        $this->giveCredits($user, -2);

        $this->getJson('/api/credits/status')->assertOk()->assertExactJson([
            'today' => '2026-11-16',
            'timezone' => 'Asia/Jakarta',
            'today_active' => false,
            'today_source' => null,
            'free_quota_remaining' => 2,
            'free_quota_per_month' => 2,
            'credit_balance' => 3,
            'updated_at' => now()->toIso8601String(),
        ]);

        MonitoringDay::create(['user_id' => $user->id, 'day' => '2026-11-16', 'source' => 'free', 'activated_at' => now()]);
        $this->getJson('/api/credits/status')->assertOk()
            ->assertJsonPath('today_active', true)
            ->assertJsonPath('today_source', 'free')
            ->assertJsonPath('free_quota_remaining', 1);
    }

    public function test_balance_is_sum_of_ledger(): void
    {
        [$user] = $this->loginUser();
        $this->giveCredits($user, 10);
        $this->giveCredits($user, -3);

        $this->assertSame(7, $user->creditBalance());
    }

    public function test_packages_lists_only_active_packages(): void
    {
        $this->loginUser();
        CreditPackage::create(['name' => 'Paket Hemat', 'credits' => 5, 'price_idr' => 15000]);
        CreditPackage::create(['name' => 'Paket Lama', 'credits' => 3, 'price_idr' => 12000, 'is_active' => false]);

        $this->getJson('/api/credit-packages')->assertOk()
            ->assertJsonCount(1, 'packages')
            ->assertJsonPath('packages.0.name', 'Paket Hemat')
            ->assertJsonPath('packages.0.price_idr', 15000)
            ->assertJsonPath('packages.0.is_active', true);
    }

    public function test_history_returns_orders_and_ledger(): void
    {
        [$user] = $this->loginUser();
        $package = CreditPackage::create(['name' => 'Paket Hemat', 'credits' => 5, 'price_idr' => 15000]);
        $order = Order::create([
            'user_id' => $user->id, 'package_id' => $package->id, 'order_code' => 'VG-TEST-1',
            'amount_idr' => 15000, 'status' => 'settlement', 'payment_type' => 'qris', 'paid_at' => now(),
        ]);
        CreditLedger::create(['user_id' => $user->id, 'delta' => 5, 'reason' => 'purchase', 'order_id' => $order->id]);
        $day = MonitoringDay::create(['user_id' => $user->id, 'day' => '2026-11-16', 'source' => 'credit', 'activated_at' => now()]);
        CreditLedger::create(['user_id' => $user->id, 'delta' => -1, 'reason' => 'usage', 'monitoring_day_id' => $day->id]);

        $this->getJson('/api/credits/history')->assertOk()
            ->assertJsonPath('credit_balance', 4)
            ->assertJsonCount(1, 'orders')
            ->assertJsonPath('orders.0.order_code', 'VG-TEST-1')
            ->assertJsonPath('orders.0.package_name', 'Paket Hemat')
            ->assertJsonPath('orders.0.credits', 5)
            ->assertJsonPath('orders.0.status', 'settlement')
            ->assertJsonCount(2, 'ledger')
            ->assertJsonPath('ledger.0.reason', 'usage')
            ->assertJsonPath('ledger.0.day', '2026-11-16')
            ->assertJsonPath('ledger.1.reason', 'purchase')
            ->assertJsonPath('ledger.1.order_id', $order->id);
    }

    public function test_ledger_is_append_only(): void
    {
        [$user] = $this->loginUser();
        $this->giveCredits($user, 5);
        $entry = CreditLedger::firstOrFail();

        try {
            $entry->update(['delta' => 500]);
            $this->fail('Update ledger seharusnya ditolak.');
        } catch (LogicException) {
        }

        try {
            $entry->delete();
            $this->fail('Delete ledger seharusnya ditolak.');
        } catch (LogicException) {
        }

        $this->assertSame(5, CreditLedger::firstOrFail()->delta);
    }

    public function test_purchase_ledger_order_id_is_unique(): void
    {
        [$user] = $this->loginUser();
        $package = CreditPackage::create(['name' => 'Paket Hemat', 'credits' => 5, 'price_idr' => 15000]);
        $order = Order::create([
            'user_id' => $user->id, 'package_id' => $package->id, 'order_code' => 'VG-TEST-2', 'amount_idr' => 15000,
        ]);
        CreditLedger::create(['user_id' => $user->id, 'delta' => 5, 'reason' => 'purchase', 'order_id' => $order->id]);

        $this->expectException(UniqueConstraintViolationException::class);
        CreditLedger::create(['user_id' => $user->id, 'delta' => 5, 'reason' => 'purchase', 'order_id' => $order->id]);
    }
}
