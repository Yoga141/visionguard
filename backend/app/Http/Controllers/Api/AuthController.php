<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\LoginRequest;
use App\Http\Requests\RegisterRequest;
use App\Http\Resources\UserResource;
use App\Models\Device;
use App\Models\User;
use App\Services\DeviceService;
use App\Services\LoginThrottle;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

/** UC-01 Registrasi, UC-02 Login, UC-04 Logout — DOCS_SPEC §8.7, §11.1. */
class AuthController extends Controller
{
    public function __construct(
        private readonly DeviceService $devices,
        private readonly LoginThrottle $throttle,
    ) {}

    /** POST /auth/register → 201 + token; 422 email terpakai. */
    public function register(RegisterRequest $request): JsonResponse
    {
        $data = $request->validated();

        $user = User::create([
            'name' => $data['name'],
            'email' => $data['email'],
            'password_hash' => $data['password'], // bcrypt via cast `hashed`
            'role' => User::ROLE_USER,
            'timezone' => $data['timezone'] ?? config('visionguard.default_timezone'),
        ]);

        $device = $this->devices->record($user, $data['platform'], $data['device_name']);

        return response()->json($this->session($user, $device), 201);
    }

    /** POST /auth/login → 200 + token; 401 salah; 429 ditahan 5 menit (KMN-02). */
    public function login(LoginRequest $request): JsonResponse
    {
        $data = $request->validated();
        $key = $this->throttle->key($data['email'], $request->ip());

        if ($seconds = $this->throttle->lockedFor($key)) {
            return response()->json([
                'message' => 'Terlalu banyak percobaan login. Coba lagi dalam 5 menit.',
                'retry_after' => $seconds,
            ], 429)->header('Retry-After', (string) $seconds);
        }

        $user = User::where('email', $data['email'])->first();

        if (! $user || ! Hash::check($data['password'], $user->password_hash)) {
            $this->throttle->recordFailure($key);

            return response()->json(['message' => 'Email atau kata sandi salah.'], 401);
        }

        $this->throttle->clear($key);
        $device = $this->devices->record($user, $data['platform'], $data['device_name']);

        return response()->json($this->session($user, $device));
    }

    /** POST /auth/logout → cabut token perangkat ini. */
    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()->delete();

        return response()->json(['message' => 'Berhasil keluar.']);
    }

    /** @return array<string, mixed> */
    private function session(User $user, Device $device): array
    {
        $token = $user->createToken("{$device->platform}:{$device->device_name}")->plainTextToken;

        return [
            'token' => $token,
            'token_type' => 'Bearer',
            'device_id' => $device->id,
            'user' => new UserResource($user),
        ];
    }
}
