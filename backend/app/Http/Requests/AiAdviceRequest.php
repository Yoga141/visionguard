<?php

namespace App\Http\Requests;

/**
 * POST /ai/advice — DOCS_SPEC §17.2. Hanya angka ringkasan; field lain
 * (mis. nama, email, gambar) tidak pernah diteruskan ke Gemini karena
 * controller hanya memakai `validated()`.
 */
class AiAdviceRequest extends ApiRequest
{
    public function rules(): array
    {
        return [
            'fatigue_score' => ['required', 'integer', 'min:0', 'max:100'],
            'blink_rate' => ['nullable', 'numeric', 'min:0', 'max:200'],
            'perclos' => ['nullable', 'numeric', 'min:0', 'max:1'],
            'distance_cm' => ['nullable', 'numeric', 'min:0', 'max:500'],
            'screen_minutes' => ['nullable', 'integer', 'min:0', 'max:1440'],
        ];
    }
}
