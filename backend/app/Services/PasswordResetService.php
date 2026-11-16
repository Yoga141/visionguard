<?php

namespace App\Services;

use App\Models\User;
use Illuminate\Support\Facades\Password;

/**
 * Reset kata sandi — DOCS_SPEC §8.7, UC-03. Memakai Password broker Laravel
 * (tabel `password_reset_tokens`, token berlaku 60 menit: config/auth.php).
 * Dipakai oleh API (`/auth/forgot-password`, `/auth/reset-password`) dan
 * halaman web form sandi baru.
 */
class PasswordResetService
{
    public const SENT = 'sent';

    public const UNKNOWN_EMAIL = 'unknown_email';

    public const THROTTLED = 'throttled';

    public const RESET = 'reset';

    public const INVALID_TOKEN = 'invalid_token';

    public function sendLink(string $email): string
    {
        $status = Password::broker()->sendResetLink(['email' => strtolower(trim($email))]);

        return match ($status) {
            Password::RESET_LINK_SENT => self::SENT,
            Password::RESET_THROTTLED => self::THROTTLED,
            default => self::UNKNOWN_EMAIL, // Password::INVALID_USER
        };
    }

    /**
     * Sandi baru di-hash (cast `hashed`) dan semua token Sanctum dicabut agar
     * sesi lama di perangkat lain berakhir (§16 #27).
     */
    public function reset(string $email, string $token, string $password): string
    {
        $status = Password::broker()->reset(
            ['email' => strtolower(trim($email)), 'token' => $token, 'password' => $password],
            function (User $user, string $password) {
                $user->forceFill(['password_hash' => $password])->save();
                $user->tokens()->delete();
            },
        );

        return $status === Password::PASSWORD_RESET ? self::RESET : self::INVALID_TOKEN;
    }
}
