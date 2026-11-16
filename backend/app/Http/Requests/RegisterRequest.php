<?php

namespace App\Http\Requests;

use App\Models\Device;
use Illuminate\Validation\Rule;

/** POST /auth/register — UC-01, §8.7. */
class RegisterRequest extends ApiRequest
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
            'name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'string', 'email', 'max:150', Rule::unique('users', 'email')],
            'password' => ['required', 'string', 'min:8', 'max:72'],
            'timezone' => ['sometimes', 'string', 'max:50', 'timezone:all'],
            'platform' => ['required', 'string', Rule::in(Device::PLATFORMS)],
            'device_name' => ['required', 'string', 'max:100'],
        ];
    }

    public function messages(): array
    {
        return [
            'email.unique' => 'Email sudah terdaftar. Silakan login atau reset kata sandi.',
            'password.min' => 'Kata sandi minimal 8 karakter.',
        ];
    }
}
