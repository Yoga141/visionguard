<?php

namespace App\Filament\Resources\CreditPackages\Schemas;

use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;

class CreditPackageForm
{
    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->components([
                TextInput::make('name')
                    ->label('Nama paket')
                    ->required()
                    ->maxLength(50),
                TextInput::make('credits')
                    ->label('Jumlah kredit (hari)')
                    ->required()
                    ->integer()
                    ->minValue(1),
                TextInput::make('price_idr')
                    ->label('Harga (IDR)')
                    ->required()
                    ->integer()
                    ->minValue(1)
                    ->prefix('Rp'),
                Toggle::make('is_active')
                    ->label('Aktif (tampil di aplikasi)')
                    ->default(true),
            ]);
    }
}
