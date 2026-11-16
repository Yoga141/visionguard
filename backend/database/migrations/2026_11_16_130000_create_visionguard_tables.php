<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Tabel server VisionGuard — DOCS_SPEC §12.2 (SDD 3.3 a, Tabel 3.3–3.8).
 *
 * Tidak ada kolom gambar/BLOB di tabel mana pun (§8.8, PRV-01).
 * Tambahan di luar §12.2: `orders.created_at` (tanggal di riwayat UC-20),
 * lihat DOCS_SPEC §16 #18.
 */
return new class extends Migration
{
    public function up(): void
    {
        // D2 Perangkat
        Schema::create('devices', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('platform', 20); // windows | macos | android | ios
            $table->string('device_name', 100);
            $table->dateTime('last_seen_at')->nullable();
        });

        // D9 Paket Kredit
        Schema::create('credit_packages', function (Blueprint $table) {
            $table->id();
            $table->string('name', 50);
            $table->integer('credits');
            $table->integer('price_idr');
            $table->boolean('is_active')->default(true);
        });

        // D8 Order
        Schema::create('orders', function (Blueprint $table) {
            $table->id();
            // Nullable: identitas dilepas saat hapus akun (§8.7, anonimisasi).
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            // restrict: paket yang pernah dibeli tidak boleh dihapus (§8.6).
            $table->foreignId('package_id')->constrained('credit_packages')->restrictOnDelete();
            $table->string('order_code', 40)->unique();
            $table->integer('amount_idr');
            $table->string('status', 20)->default('pending'); // pending|settlement|expire|cancel|deny
            $table->string('payment_type', 30)->nullable();
            $table->dateTime('paid_at')->nullable();
            $table->dateTime('created_at')->useCurrent();
        });

        // D6 Hari Pemantauan
        Schema::create('monitoring_days', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->date('day');
            $table->enum('source', ['free', 'credit']);
            $table->foreignId('device_id')->nullable()->constrained()->nullOnDelete();
            $table->dateTime('activated_at');

            $table->unique(['user_id', 'day']); // satu hari satu aktivasi (§8.1)
        });

        // D7 Ledger Kredit (append-only, §8.3)
        Schema::create('credit_ledger', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->nullable()->constrained()->nullOnDelete();
            $table->integer('delta');
            $table->enum('reason', ['purchase', 'usage', 'adjustment']);
            // UNIQUE → notifikasi Midtrans berulang tidak menambah kredit dua kali.
            $table->foreignId('order_id')->nullable()->unique()->constrained()->restrictOnDelete();
            $table->foreignId('monitoring_day_id')->nullable()->constrained()->restrictOnDelete();
            $table->string('note', 255)->nullable(); // wajib untuk adjustment
            $table->dateTime('created_at')->useCurrent();
        });

        // D11 Statistik Harian
        Schema::create('daily_stats', function (Blueprint $table) {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('device_id')->constrained()->cascadeOnDelete();
            $table->date('day');
            $table->integer('screen_minutes')->default(0);
            $table->float('avg_blink_rate')->nullable();
            $table->float('avg_distance_cm')->nullable();
            $table->float('avg_fatigue_score')->nullable();
            $table->integer('alerts_count')->default(0);
            $table->integer('breaks_taken')->default(0);

            $table->unique(['user_id', 'device_id', 'day']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('daily_stats');
        Schema::dropIfExists('credit_ledger');
        Schema::dropIfExists('monitoring_days');
        Schema::dropIfExists('orders');
        Schema::dropIfExists('credit_packages');
        Schema::dropIfExists('devices');
    }
};
