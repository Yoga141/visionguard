<?php

namespace App\Http\Resources;

use App\Models\CreditLedger;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** @mixin CreditLedger */
class LedgerEntryResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'delta' => $this->delta,
            'reason' => $this->reason,
            'order_id' => $this->order_id,
            'monitoring_day_id' => $this->monitoring_day_id,
            'day' => $this->monitoringDay?->day,
            'note' => $this->note,
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
