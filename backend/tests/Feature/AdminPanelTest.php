<?php

namespace Tests\Feature;

use App\Filament\Resources\CreditPackages\CreditPackageResource;
use App\Filament\Resources\Users\Pages\ListUsers;
use App\Models\CreditLedger;
use App\Models\CreditPackage;
use App\Models\Order;
use App\Models\User;
use App\Services\CreditAdjustmentService;
use Filament\Actions\Testing\TestAction;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Validation\ValidationException;
use Livewire\Livewire;
use LogicException;
use Tests\TestCase;

/** Panel admin Filament (A-01..A-03) dan penyesuaian kredit §8.5. */
class AdminPanelTest extends TestCase
{
    use RefreshDatabase;

    private function admin(): User
    {
        return User::factory()->admin()->create(['email' => 'admin@visionguard.id']);
    }

    private function seedData(): array
    {
        $user = User::factory()->create(['email' => 'budi@contoh.id']);
        $package = CreditPackage::create(['name' => 'Paket Hemat', 'credits' => 5, 'price_idr' => 15000]);
        $order = Order::create([
            'user_id' => $user->id, 'package_id' => $package->id, 'order_code' => 'VG-ADM-1',
            'amount_idr' => 15000, 'status' => 'settlement', 'payment_type' => 'qris', 'paid_at' => now(),
        ]);
        CreditLedger::create(['user_id' => $user->id, 'delta' => 5, 'reason' => 'purchase', 'order_id' => $order->id]);

        return [$user, $package, $order];
    }

    public function test_panel_requires_admin_role(): void
    {
        $this->get('/admin')->assertRedirect('/admin/login');

        $this->actingAs(User::factory()->create())->get('/admin')->assertForbidden();

        $this->actingAs($this->admin())->get('/admin')->assertOk();
    }

    public function test_admin_pages_render_with_data(): void
    {
        [$user, , $order] = $this->seedData();
        $this->actingAs($this->admin());

        $this->get('/admin/credit-packages')->assertOk()->assertSee('Paket Hemat');
        $this->get('/admin/orders')->assertOk()->assertSee($order->order_code)->assertSee('qris');
        $this->get('/admin/users')->assertOk()->assertSee($user->email);
        $this->get('/admin/credit-packages/create')->assertOk();
    }

    public function test_purchased_package_cannot_be_deleted(): void
    {
        [, $package] = $this->seedData();
        $unused = CreditPackage::create(['name' => 'Paket Baru', 'credits' => 1, 'price_idr' => 5000]);

        $this->assertFalse(CreditPackageResource::canDelete($package));
        $this->assertTrue(CreditPackageResource::canDelete($unused));

        try {
            $package->delete();
            $this->fail('Paket yang pernah dibeli seharusnya tidak bisa dihapus.');
        } catch (LogicException) {
        }
        $this->assertDatabaseHas('credit_packages', ['id' => $package->id]);

        // Menonaktifkan tetap boleh.
        $package->update(['is_active' => false]);
        $this->assertFalse($package->fresh()->is_active);

        $unused->delete();
        $this->assertDatabaseMissing('credit_packages', ['id' => $unused->id]);
    }

    public function test_adjustment_requires_reason(): void
    {
        [$user] = $this->seedData();
        $service = app(CreditAdjustmentService::class);

        foreach ([null, '', '   '] as $note) {
            try {
                $service->adjust($user, 3, $note);
                $this->fail('Alasan kosong seharusnya ditolak.');
            } catch (ValidationException $e) {
                $this->assertArrayHasKey('note', $e->errors());
            }
        }

        $this->assertSame(0, CreditLedger::where('reason', 'adjustment')->count());
    }

    public function test_adjustment_rejects_negative_final_balance_and_zero_delta(): void
    {
        [$user] = $this->seedData(); // saldo 5
        $service = app(CreditAdjustmentService::class);

        try {
            $service->adjust($user, -6, 'Koreksi');
            $this->fail('Saldo akhir negatif seharusnya ditolak.');
        } catch (ValidationException $e) {
            $this->assertArrayHasKey('delta', $e->errors());
        }

        try {
            $service->adjust($user, 0, 'Tidak ada perubahan');
            $this->fail('Delta 0 seharusnya ditolak.');
        } catch (ValidationException $e) {
            $this->assertArrayHasKey('delta', $e->errors());
        }

        $this->assertSame(5, $user->creditBalance());
    }

    public function test_valid_adjustment_inserts_ledger_entry(): void
    {
        [$user] = $this->seedData();
        $service = app(CreditAdjustmentService::class);

        $this->assertSame(0, $service->adjust($user, -5, '  Pengembalian dana  '));
        $this->assertSame(3, $service->adjust($user, 3, 'Kompensasi gangguan server'));

        $this->assertDatabaseHas('credit_ledger', ['user_id' => $user->id, 'delta' => -5, 'reason' => 'adjustment', 'note' => 'Pengembalian dana']);
        $this->assertDatabaseHas('credit_ledger', ['user_id' => $user->id, 'delta' => 3, 'reason' => 'adjustment', 'note' => 'Kompensasi gangguan server']);
        $this->assertSame(3, $user->creditBalance());
    }

    public function test_filament_adjust_credit_action(): void
    {
        [$user] = $this->seedData();
        $this->actingAs($this->admin());

        Livewire::test(ListUsers::class)
            ->callAction(TestAction::make('adjustCredit')->table($user), ['delta' => 2, 'note' => 'Bonus uji'])
            ->assertHasNoFormErrors()
            ->assertNotified('Kredit disesuaikan');
        $this->assertSame(7, $user->creditBalance());

        Livewire::test(ListUsers::class)
            ->callAction(TestAction::make('adjustCredit')->table($user), ['delta' => -100, 'note' => 'Terlalu banyak'])
            ->assertNotified('Penyesuaian ditolak');
        $this->assertSame(7, $user->creditBalance());

        Livewire::test(ListUsers::class)
            ->callAction(TestAction::make('adjustCredit')->table($user), ['delta' => 2, 'note' => ''])
            ->assertHasFormErrors(['note' => 'required']);
        $this->assertSame(7, $user->creditBalance());
    }
}
