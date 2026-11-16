<?php

namespace App\Http\Requests;

use App\Models\Device;
use Illuminate\Validation\Rule;

/** POST /auth/login — UC-02, §8.7. */
class LoginRequest extends ApiRequest
{
    protected function prepareForValidation(): void
    {
        if (is_string($this->input('email'))) {
            $this->merge(['email' => strtolower(trim($this->input('email')))]);
        }
    }

    public function rules(): array
    {
        return [
            'email' => ['required', 'string', 'email', 'max:150'],
            'password' => ['required', 'string'],
            'platform' => ['required', 'string', Rule::in(Device::PLATFORMS)],
            'device_name' => ['required', 'string', 'max:100'],
        ];
    }
}
