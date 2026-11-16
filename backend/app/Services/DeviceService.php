<?php

namespace App\Services;

use App\Models\Device;
use App\Models\User;

/** DFD 1.6 Daftarkan Perangkat (D2) saat login/registrasi (§8.7). */
class DeviceService
{
    /**
     * Perangkat dikenali dari kombinasi (user, platform, device_name).
     * Bila sudah ada, hanya `last_seen_at` yang diperbarui.
     */
    public function record(User $user, string $platform, string $deviceName): Device
    {
        $device = Device::firstOrNew([
            'user_id' => $user->id,
            'platform' => $platform,
            'device_name' => $deviceName,
        ]);
        $device->last_seen_at = now();
        $device->save();

        return $device;
    }

    /** Perangkat milik [user] dengan id [deviceId], atau null. */
    public function findOwned(User $user, ?int $deviceId): ?Device
    {
        if ($deviceId === null) {
            return null;
        }

        return $user->devices()->whereKey($deviceId)->first();
    }
}
