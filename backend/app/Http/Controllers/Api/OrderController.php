<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\CreateOrderRequest;
use App\Http\Resources\OrderResource;
use App\Models\CreditPackage;
use App\Services\OrderService;
use App\Services\Payments\PaymentGatewayException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** POST /orders, GET /orders/{order_code} — UC-19, §8.4. */
class OrderController extends Controller
{
    /** 201 + snap_token, redirect_url, order_code; 422 paket tidak aktif; 503 gerbang gagal. */
    public function store(CreateOrderRequest $request, OrderService $orders): JsonResponse
    {
        $package = CreditPackage::findOrFail($request->validated('package_id'));

        try {
            $result = $orders->create($request->user(), $package);
        } catch (PaymentGatewayException $e) {
            return response()->json(['message' => $e->getMessage()], 503);
        }

        return response()->json([
            'order_code' => $result['order']->order_code,
            'snap_token' => $result['snap_token'],
            'redirect_url' => $result['redirect_url'],
            'payment_mode' => $result['payment_mode'],
            'order' => new OrderResource($result['order']),
        ], 201);
    }

    /** Status order untuk tombol "Muat ulang status" (milik sendiri; lainnya 404). */
    public function show(Request $request, string $orderCode, OrderService $orders): JsonResponse
    {
        $user = $request->user();
        $order = $user->orders()->with('package')->where('order_code', $orderCode)->firstOrFail();

        $order = $orders->refresh($order);

        return response()->json([
            'order' => new OrderResource($order),
            'credit_balance' => $user->creditBalance(),
        ]);
    }
}
