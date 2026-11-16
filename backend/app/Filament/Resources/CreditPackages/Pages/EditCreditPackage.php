<?php

namespace App\Filament\Resources\CreditPackages\Pages;

use App\Filament\Resources\CreditPackages\CreditPackageResource;
use Filament\Actions\DeleteAction;
use Filament\Resources\Pages\EditRecord;

class EditCreditPackage extends EditRecord
{
    protected static string $resource = CreditPackageResource::class;

    protected function getHeaderActions(): array
    {
        return [
            // Disembunyikan bila paket pernah dibeli (CreditPackageResource::canDelete).
            DeleteAction::make(),
        ];
    }
}
