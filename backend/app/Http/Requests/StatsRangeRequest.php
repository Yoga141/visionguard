<?php

namespace App\Http\Requests;

use Illuminate\Validation\Rule;

/** GET /stats?range=7|30 — UC-17. Bawaan 7 bila tidak dikirim. */
class StatsRangeRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'range' => ['sometimes', 'integer', Rule::in(config('visionguard.stats_ranges'))],
        ];
    }

    public function rangeDays(): int
    {
        return (int) $this->validated('range', config('visionguard.stats_ranges')[0]);
    }
}
