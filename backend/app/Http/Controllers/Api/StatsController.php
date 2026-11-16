<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\StatsRangeRequest;
use App\Http\Requests\StoreDailyStatsRequest;
use App\Services\DeviceService;
use App\Services\StatsService;
use Illuminate\Http\JsonResponse;

/** POST /stats/daily (upsert), GET /stats?range=7|30 — Seq 4.26. */
class StatsController extends Controller
{
    public function store(StoreDailyStatsRequest $request, StatsService $stats, DeviceService $devices): JsonResponse
    {
        $user = $request->user();
        $device = $devices->findOwned($user, (int) $request->validated('device_id'));

        $days = $stats->upsert($user, $device, $request->validated('summaries'));

        return response()->json([
            'message' => 'Ringkasan harian tersimpan.',
            'synced_days' => $days,
        ]);
    }

    public function index(StatsRangeRequest $request, StatsService $stats): JsonResponse
    {
        return response()->json($stats->range($request->user(), $request->rangeDays()));
    }
}
