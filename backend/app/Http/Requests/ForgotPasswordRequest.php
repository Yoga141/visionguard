<?php

namespace App\Http\Requests;

/** POST /auth/forgot-password — UC-03. */
class ForgotPasswordRequest extends ApiRequest
{
    public function rules(): array
    {
        return ['email' => ['required', 'string', 'email', 'max:150']];
    }
}
