<?php

namespace App\Filament\Resources\CreditPackages;

use App\Filament\Resources\CreditPackages\Pages\CreateCreditPackage;
use App\Filament\Resources\CreditPackages\Pages\EditCreditPackage;
use App\Filament\Resources\CreditPackages\Pages\ListCreditPackages;
use App\Filament\Resources\CreditPackages\Schemas\CreditPackageForm;
use App\Filament\Resources\CreditPackages\Tables\CreditPackagesTable;
use App\Models\CreditPackage;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;

/** A-01 Paket Kredit — UC-22, DOCS_SPEC §8.6. */
class CreditPackageResource extends Resource
{
    protected static ?string $model = CreditPackage::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedRectangleStack;

    protected static ?string $navigationLabel = 'Paket Kredit';

    protected static ?string $modelLabel = 'paket kredit';

    protected static ?string $pluralModelLabel = 'paket kredit';

    protected static ?int $navigationSort = 1;

    public static function form(Schema $schema): Schema
    {
        return CreditPackageForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return CreditPackagesTable::configure($table);
    }

    /** Paket yang pernah dibeli hanya bisa dinonaktifkan (§8.6). */
    public static function canDelete(Model $record): bool
    {
        return $record instanceof CreditPackage && ! $record->wasPurchased();
    }

    public static function canDeleteAny(): bool
    {
        return false; // tanpa hapus massal
    }

    public static function getPages(): array
    {
        return [
            'index' => ListCreditPackages::route('/'),
            'create' => CreateCreditPackage::route('/create'),
            'edit' => EditCreditPackage::route('/{record}/edit'),
        ];
    }
}
