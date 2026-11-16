<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ActivateMonitoringDayRequest;
use App\Services\DeviceService;
use App\Services\MonitoringDayService;
use Illuminate\Http\JsonResponse;

/** POST /monitoring-days/activate — §8.2, Seq 4.21. */
class MonitoringDayController extends Controller
{
    /** 200 OK + sisa kuota & saldo; 402 kredit tidak cukup. */
    public function activate(
        ActivateMonitoringDayRequest $request,
        MonitoringDayService $service,
        DeviceService $devices,
    ): JsonResponse {
        $user = $request->user();
        $device = $devices->findOwned($user, $request->validated('device_id'));

        $result = $service->activateToday($user, $device);

        if ($result['result'] === MonitoringDayService::RESULT_INSUFFICIENT) {
            return response()->json([
                'message' => 'Kredit tidak cukup. Beli kredit atau gunakan Mode Timer.',
                ...$result['status'],
            ], 402);
        }

        return response()->json([
            'message' => $result['already_active']
                ? 'Hari Pemantauan AI sudah aktif.'
                : 'Hari Pemantauan AI diaktifkan.',
            'source' => $result['source'],
            'already_active' => $result['already_active'],
            ...$result['status'],
        ]);
    }
}
