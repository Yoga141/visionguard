<?php

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        //
    }

    public function boot(): void
    {
        // Format JSON datar (tanpa pembungkus "data"), sesuai klien Flutter.
        JsonResource::withoutWrapping();

        // §17.4 — batas pemakaian Saran AI per pengguna → 429.
        RateLimiter::for('ai-advice', function (Request $request) {
            return Limit::perHour((int) config('visionguard.ai_advice.max_per_hour'))
                ->by('ai-advice:'.$request->user()?->id)
                ->response(fn (Request $request, array $headers) => response()->json(
                    ['message' => 'Batas pemakaian Saran AI tercapai. Coba lagi nanti.'],
                    429,
                    $headers,
                ));
        });
    }
}
