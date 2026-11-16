<?php

use App\Http\Controllers\Web\PasswordResetPageController;
use App\Http\Controllers\Web\PaymentPageController;
use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

// §8.4 — tujuan redirect Snap (finish lewat callbacks, unfinish/error diatur di dashboard Midtrans).
Route::get('/payments/finish', [PaymentPageController::class, 'finish'])->name('payments.finish');
Route::get('/payments/unfinish', [PaymentPageController::class, 'unfinish'])->name('payments.unfinish');
Route::get('/payments/error', [PaymentPageController::class, 'error'])->name('payments.error');

// Mode simulation saja: halaman bayar tiruan.
Route::get('/payments/simulate/{orderCode}', [PaymentPageController::class, 'simulate'])->name('payments.simulate');
Route::post('/payments/simulate/{orderCode}', [PaymentPageController::class, 'simulatePay'])->name('payments.simulate.pay');

// UC-03 — form sandi baru dari tautan email (token berlaku 60 menit).
Route::get('/reset-password/{token}', [PasswordResetPageController::class, 'show'])->name('password.reset');
Route::post('/reset-password', [PasswordResetPageController::class, 'update'])->name('password.update');
