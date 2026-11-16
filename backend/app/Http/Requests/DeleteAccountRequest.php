<?php

namespace App\Http\Requests;

/** DELETE /me — UC-05. Kata sandi wajib; salah → 403 (dicek di controller). */
class DeleteAccountRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'password' => ['required', 'string'],
        ];
    }
}
