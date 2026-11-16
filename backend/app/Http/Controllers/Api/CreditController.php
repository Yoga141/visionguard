<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Resources\CreditPackageResource;
use App\Http\Resources\LedgerEntryResource;
use App\Http\Resources\OrderResource;
use App\Models\CreditPackage;
use App\Services\MonitoringDayService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/** KRD-01 status, KRD-04 riwayat, daftar paket aktif (UC-18..20). */
class CreditController extends Controller
{
    /** GET /credits/status */
    public function status(Request $request, MonitoringDayService $service): JsonResponse
    {
        return response()->json($service->status($request->user()));
    }

    /** GET /credit-packages — hanya paket aktif (§8.6). */
    public function packages(): JsonResponse
    {
        $packages = CreditPackage::active()->orderBy('price_idr')->get();

        return response()->json(['packages' => CreditPackageResource::collection($packages)]);
    }

    /** GET /credits/history — order (terbaru dulu) + mutasi ledger (terbaru dulu). */
    public function history(Request $request): JsonResponse
    {
        $user = $request->user();

        $orders = $user->orders()->with('package')->latest('id')->get();
        $ledger = $user->creditLedger()->with('monitoringDay')->latest('id')->get();

        return response()->json([
            'credit_balance' => $user->creditBalance(),
            'orders' => OrderResource::collection($orders),
            'ledger' => LedgerEntryResource::collection($ledger),
        ]);
    }
}
