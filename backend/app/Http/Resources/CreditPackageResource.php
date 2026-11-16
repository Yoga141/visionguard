<?php

namespace App\Http\Resources;

use App\Models\CreditPackage;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin CreditPackage */
class CreditPackageResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'name' => $this->name,
            'credits' => $this->credits,
            'price_idr' => $this->price_idr,
            'is_active' => $this->is_active,
        ];
    }
}
