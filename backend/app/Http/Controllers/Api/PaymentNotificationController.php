<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Services\Payments\PaymentNotificationService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * POST /payments/midtrans/notification — publik, tanpa token, tanpa CSRF
 * (rute API). Keamanan bergantung pada verifikasi signature SHA-512 (§8.4, KMN-03).
 */
class PaymentNotificationController extends Controller
{
    public function __invoke(Request $request, PaymentNotificationService $notifications): JsonResponse
    {
        $result = $notifications->handle($request->all());

        return response()->json(['message' => $result['message']], $result['http_status']);
    }
}
