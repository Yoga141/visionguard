<?php

namespace App\Http\Resources;

use App\Models\Order;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin Order */
class OrderResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'order_code' => $this->order_code,
            'package_id' => $this->package_id,
            'package_name' => $this->package?->name,
            'credits' => $this->package?->credits,
            'amount_idr' => $this->amount_idr,
            'status' => $this->status,
            'payment_type' => $this->payment_type,
            'paid_at' => $this->paid_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
