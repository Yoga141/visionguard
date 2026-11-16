<?php

namespace Database\Seeders;

use App\Models\CreditPackage;
use App\Models\User;
use Illuminate\Database\Seeder;

/**
 * Data awal pengembangan. Akun demo sama dengan akun demo klien Flutter.
 *
 *   admin@visionguard.id / password123  (role admin)
 *   demo@visionguard.id  / password123  (role user)
 */
class DatabaseSeeder extends Seeder
{
    public function run(): void
    {
        User::updateOrCreate(
            ['email' => 'admin@visionguard.id'],
            [
                'name' => 'Admin VisionGuard',
                'password_hash' => 'password123', // di-hash oleh cast `hashed`
                'role' => User::ROLE_ADMIN,
                'timezone' => 'Asia/Jakarta',
            ],
        );

        User::updateOrCreate(
            ['email' => 'demo@visionguard.id'],
            [
                'name' => 'Pengguna Demo',
                'password_hash' => 'password123',
                'role' => User::ROLE_USER,
                'timezone' => 'Asia/Jakarta',
            ],
        );

        $packages = [
            // Sama dengan paket aktif di FakeCreditRepository klien.
            ['name' => 'Paket Hemat', 'credits' => 5, 'price_idr' => 15000],
            ['name' => 'Paket Reguler', 'credits' => 12, 'price_idr' => 30000],
            ['name' => 'Paket Hemat Plus', 'credits' => 30, 'price_idr' => 65000],
        ];

        foreach ($packages as $package) {
            CreditPackage::updateOrCreate(['name' => $package['name']], $package + ['is_active' => true]);
        }
    }
}
