<?php

use App\Http\Controllers\Api\AccountController;
use App\Http\Controllers\Api\AiAdviceController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CreditController;
use App\Http\Controllers\Api\MonitoringDayController;
use App\Http\Controllers\Api\OrderController;
use App\Http\Controllers\Api\PasswordResetController;
use App\Http\Controllers\Api\PaymentNotificationController;
use App\Http\Controllers\Api\StatsController;
use Illuminate\Support\Facades\Route;

/*
| REST API VisionGuard — prefix /api (DOCS_SPEC §11, API_CONTRACT.md).
| Semua rute wajib token Sanctum kecuali yang publik.
*/

// Publik
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login', [AuthController::class, 'login']);
Route::post('/auth/forgot-password', [PasswordResetController::class, 'forgot'])->middleware('throttle:password-reset');
Route::post('/auth/reset-password', [PasswordResetController::class, 'reset'])->middleware('throttle:password-reset');

// Notifikasi Midtrans: publik, tanpa CSRF (rute API), wajib signature SHA-512 (§8.4).
Route::post('/payments/midtrans/notification', PaymentNotificationController::class);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::get('/me', [AccountController::class, 'show']);
    Route::delete('/me', [AccountController::class, 'destroy']);

    Route::post('/monitoring-days/activate', [MonitoringDayController::class, 'activate']);

    Route::get('/credits/status', [CreditController::class, 'status']);
    Route::get('/credits/history', [CreditController::class, 'history']);
    Route::get('/credit-packages', [CreditController::class, 'packages']);

    Route::post('/orders', [OrderController::class, 'store']);
    Route::get('/orders/{orderCode}', [OrderController::class, 'show']);

    Route::post('/stats/daily', [StatsController::class, 'store']);
    Route::get('/stats', [StatsController::class, 'index']);

    Route::post('/ai/advice', [AiAdviceController::class, 'store'])->middleware('throttle:ai-advice');
});
