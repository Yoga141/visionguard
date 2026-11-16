<?php

namespace App\Http\Requests;

use Illuminate\Validation\Rule;

/** POST /monitoring-days/activate — §8.2. `device_id` opsional (perangkat pertama yang mengaktifkan). */
class ActivateMonitoringDayRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'device_id' => [
                'sometimes', 'nullable', 'integer',
                Rule::exists('devices', 'id')->where('user_id', $this->user()->id),
            ],
        ];
    }
}
