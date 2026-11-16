<?php

namespace App\Http\Controllers\Api;

use App\Exceptions\AiUnavailableException;
use App\Http\Controllers\Controller;
use App\Http\Requests\AiAdviceRequest;
use App\Services\GeminiAdviceService;
use Illuminate\Http\JsonResponse;

/** POST /ai/advice — DOCS_SPEC §17.4. Rate limit per pengguna lewat `throttle:ai-advice`. */
class AiAdviceController extends Controller
{
    public function store(AiAdviceRequest $request, GeminiAdviceService $gemini): JsonResponse
    {
        try {
            $advice = $gemini->advise($request->validated());
        } catch (AiUnavailableException $e) {
            return response()->json(['message' => $e->getMessage()], 503);
        }

        return response()->json(['advice' => $advice]);
    }
}
