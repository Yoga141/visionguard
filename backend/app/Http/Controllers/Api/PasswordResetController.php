<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\ForgotPasswordRequest;
use App\Http\Requests\ResetPasswordRequest;
use App\Services\PasswordResetService;
use Illuminate\Http\JsonResponse;

/** UC-03 Reset kata sandi (API publik). */
class PasswordResetController extends Controller
{
    public function __construct(private readonly PasswordResetService $resets) {}

    /** 200 email terkirim; 404 email tidak terdaftar; 429 diminta terlalu sering. */
    public function forgot(ForgotPasswordRequest $request): JsonResponse
    {
        return match ($this->resets->sendLink($request->validated('email'))) {
            PasswordResetService::SENT => response()->json([
                'message' => 'Tautan reset kata sandi telah dikirim ke email Anda. Berlaku 60 menit.',
            ]),
            PasswordResetService::THROTTLED => response()->json([
                'message' => 'Tautan baru saja dikirim. Tunggu sebentar sebelum meminta lagi.',
            ], 429),
            default => response()->json(['message' => 'Email tidak terdaftar.'], 404),
        };
    }

    /** 200 sandi diganti; 422 token tidak valid/kedaluwarsa. */
    public function reset(ResetPasswordRequest $request): JsonResponse
    {
        $data = $request->validated();
        $status = $this->resets->reset($data['email'], $data['token'], $data['password']);

        if ($status !== PasswordResetService::RESET) {
            $message = 'Tautan reset tidak valid atau sudah kedaluwarsa. Minta tautan baru.';

            return response()->json(['message' => $message, 'errors' => ['token' => [$message]]], 422);
        }

        return response()->json(['message' => 'Kata sandi berhasil diganti. Silakan login.']);
    }
}
