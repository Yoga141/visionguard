<?php

/*
 * Aturan bisnis VisionGuard (DOCS_SPEC §8). Satu-satunya tempat angka-angka ini
 * didefinisikan di backend.
 */
return [

    // §8.1 — kuota gratis Hari Pemantauan AI per bulan berjalan.
    'free_days_per_month' => 2,

    // §8.1 — 1 kredit = 1 Hari Pemantauan AI.
    'credits_per_day' => 1,

    // Zona waktu bawaan akun bila klien tidak mengirim `timezone` saat registrasi.
    'default_timezone' => env('VISIONGUARD_DEFAULT_TIMEZONE', 'Asia/Jakarta'),

    // KMN-02 — 5 kali gagal berturut-turut → login ditahan 5 menit.
    'login' => [
        'max_attempts' => 5,
        'lockout_seconds' => 300,
    ],

    // UC-17 — rentang grafik tren.
    'stats_ranges' => [7, 30],

    // Batas jumlah ringkasan harian per request POST /stats/daily.
    'stats_max_batch' => 31,

    // §9.4 — batas level skor (untuk prompt Saran AI).
    'fatigue_levels' => [
        'alert_min' => 40, // 40–59 Waspada
        'tired_min' => 60, // 60–100 Lelah
    ],

    // §8.4 — mode pembayaran: 'midtrans' (Snap) atau 'simulation' (halaman bayar tiruan).
    // 'midtrans' dengan MIDTRANS_SERVER_KEY kosong otomatis menjadi 'simulation'.
    // 'simulation' ditolak saat APP_ENV=production (§16 #25).
    'payment_mode' => env('PAYMENT_MODE', 'midtrans'),

    // Prefix kode order (orders.order_code ≤ 40 karakter).
    'order_code_prefix' => 'VG',

    // §17.4 — batas pemakaian Saran AI per pengguna.
    'ai_advice' => [
        'max_per_hour' => (int) env('AI_ADVICE_MAX_PER_HOUR', 10),
    ],
];
