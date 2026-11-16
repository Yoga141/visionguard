<?php

namespace App\Http\Controllers\Web;

use App\Http\Controllers\Controller;
use App\Http\Requests\ResetPasswordRequest;
use App\Services\PasswordResetService;
use Illuminate\Http\RedirectResponse;
use Illuminate\Http\Request;
use Illuminate\View\View;

/** Halaman web form sandi baru dari tautan email (UC-03). */
class PasswordResetPageController extends Controller
{
    public function show(Request $request, string $token): View
    {
        return view('auth.reset-password', [
            'token' => $token,
            'email' => (string) $request->query('email'),
        ]);
    }

    public function update(ResetPasswordRequest $request, PasswordResetService $resets): RedirectResponse|View
    {
        $data = $request->validated();

        if ($resets->reset($data['email'], $data['token'], $data['password']) !== PasswordResetService::RESET) {
            return back()->withInput($request->only('email'))->withErrors([
                'token' => 'Tautan reset tidak valid atau sudah kedaluwarsa. Minta tautan baru dari aplikasi.',
            ]);
        }

        return view('auth.reset-password-done');
    }
}
