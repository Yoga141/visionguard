<?php

namespace App\Http\Requests;

use Illuminate\Validation\Rule;

/** POST /orders — UC-19. Hanya paket aktif (§8.6). */
class CreateOrderRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'package_id' => [
                'required', 'integer',
                Rule::exists('credit_packages', 'id')->where('is_active', true),
            ],
        ];
    }

    public function messages(): array
    {
        return ['package_id.exists' => 'Paket kredit tidak tersedia.'];
    }
}
