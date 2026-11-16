<?php

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/** Dasar Form Request API: otorisasi lewat middleware `auth:sanctum`. */
abstract class ApiRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }
}
