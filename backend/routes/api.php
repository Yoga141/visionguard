<?php

use App\Http\Controllers\Api\AccountController;
use App\Http\Controllers\Api\AiAdviceController;
use App\Http\Controllers\Api\AuthController;
use App\Http\Controllers\Api\CreditController;
use App\Http\Controllers\Api\MonitoringDayController;
use App\Http\Controllers\Api\StatsController;
use Illuminate\Support\Facades\Route;

/*
| REST API VisionGuard — prefix /api (DOCS_SPEC §11, API_CONTRACT.md).
| Semua rute wajib token Sanctum kecuali yang publik.
*/

// Publik
Route::post('/auth/register', [AuthController::class, 'register']);
Route::post('/auth/login', [AuthController::class, 'login']);

Route::middleware('auth:sanctum')->group(function () {
    Route::post('/auth/logout', [AuthController::class, 'logout']);

    Route::get('/me', [AccountController::class, 'show']);
    Route::delete('/me', [AccountController::class, 'destroy']);

    Route::post('/monitoring-days/activate', [MonitoringDayController::class, 'activate']);

    Route::get('/credits/status', [CreditController::class, 'status']);
    Route::get('/credits/history', [CreditController::class, 'history']);
    Route::get('/credit-packages', [CreditController::class, 'packages']);

    Route::post('/stats/daily', [StatsController::class, 'store']);
    Route::get('/stats', [StatsController::class, 'index']);

    Route::post('/ai/advice', [AiAdviceController::class, 'store'])->middleware('throttle:ai-advice');
});
