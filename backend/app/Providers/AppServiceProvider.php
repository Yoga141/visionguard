<?php

namespace App\Providers;

use App\Services\Payments\PaymentManager;
use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Satu instance per proses → peringatan "server key kosong" cukup sekali.
        $this->app->singleton(PaymentManager::class);
    }

    public function boot(): void
    {
        // Format JSON datar (tanpa pembungkus "data"), sesuai klien Flutter.
        JsonResource::withoutWrapping();

        // §8.9 — batas pemakaian Saran AI per pengguna → 429.
        RateLimiter::for('ai-advice', function (Request $request) {
            return Limit::perHour((int) config('visionguard.ai_advice.max_per_hour'))
                ->by('ai-advice:'.$request->user()?->id)
                ->response(fn (Request $request, array $headers) => response()->json(
                    ['message' => 'Batas pemakaian Saran AI tercapai. Coba lagi nanti.'],
                    429,
                    $headers,
                ));
        });

        // UC-03 — cegah spam email reset / tebak token: 10 per menit per IP.
        RateLimiter::for('password-reset', function (Request $request) {
            return Limit::perMinute(10)->by('password-reset:'.$request->ip())
                ->response(fn (Request $request, array $headers) => response()->json(
                    ['message' => 'Terlalu banyak permintaan. Coba lagi sebentar lagi.'],
                    429,
                    $headers,
                ));
        });
    }
}
