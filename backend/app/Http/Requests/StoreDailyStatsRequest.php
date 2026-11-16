<?php

namespace App\Http\Requests;

use Illuminate\Validation\Rule;

/**
 * POST /stats/daily — STK-03, Seq 4.26. Hanya angka ringkasan (§4.3);
 * field lain di luar daftar ini diabaikan.
 */
class StoreDailyStatsRequest extends ApiRequest
{
    public function rules(): array
    {
        $max = (int) config('visionguard.stats_max_batch');

        return [
            'device_id' => [
                'required', 'integer',
                Rule::exists('devices', 'id')->where('user_id', $this->user()->id),
            ],
            'summaries' => ['required', 'array', 'min:1', "max:{$max}"],
            'summaries.*.day' => ['required', 'date_format:Y-m-d', 'distinct'],
            'summaries.*.screen_minutes' => ['required', 'integer', 'min:0', 'max:1440'],
            'summaries.*.avg_blink_rate' => ['nullable', 'numeric', 'min:0', 'max:200'],
            'summaries.*.avg_distance_cm' => ['nullable', 'numeric', 'min:0', 'max:500'],
            'summaries.*.avg_fatigue_score' => ['nullable', 'numeric', 'min:0', 'max:100'],
            'summaries.*.alerts_count' => ['required', 'integer', 'min:0'],
            'summaries.*.breaks_taken' => ['required', 'integer', 'min:0'],
        ];
    }
}
