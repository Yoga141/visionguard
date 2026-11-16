<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Http\Requests\DeleteAccountRequest;
use App\Http\Resources\UserResource;
use App\Services\AccountService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;

/** GET /me, DELETE /me (UC-05, Seq 4.28). */
class AccountController extends Controller
{
    public function show(Request $request): JsonResponse
    {
        return response()->json(['user' => new UserResource($request->user())]);
    }

    /** DELETE /me → 200; 403 kata sandi salah. */
    public function destroy(DeleteAccountRequest $request, AccountService $accounts): JsonResponse
    {
        $user = $request->user();

        if (! Hash::check($request->validated('password'), $user->password_hash)) {
            return response()->json(['message' => 'Kata sandi salah. Akun tidak dihapus.'], 403);
        }

        $accounts->delete($user);

        return response()->json(['message' => 'Akun dan data pribadi telah dihapus.']);
    }
}
