<?php

namespace App\Filament\Resources\CreditPackages\Tables;

use App\Models\CreditPackage;
use Filament\Actions\Action;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class CreditPackagesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query->withCount('orders'))
            ->columns([
                TextColumn::make('name')->label('Nama')->searchable(),
                TextColumn::make('credits')->label('Kredit')->numeric()->sortable(),
                TextColumn::make('price_idr')->label('Harga')->money('IDR', locale: 'id')->sortable(),
                IconColumn::make('is_active')->label('Aktif')->boolean(),
                TextColumn::make('orders_count')->label('Jumlah order')->numeric()->sortable(),
            ])
            ->filters([
                TernaryFilter::make('is_active')->label('Aktif'),
            ])
            ->recordActions([
                EditAction::make(),
                Action::make('toggleActive')
                    ->label(fn (CreditPackage $record) => $record->is_active ? 'Nonaktifkan' : 'Aktifkan')
                    ->color(fn (CreditPackage $record) => $record->is_active ? 'warning' : 'success')
                    ->requiresConfirmation()
                    ->action(fn (CreditPackage $record) => $record->update(['is_active' => ! $record->is_active])),
                // Hanya untuk paket yang belum pernah dibeli (§8.6).
                DeleteAction::make()
                    ->visible(fn (CreditPackage $record) => $record->orders_count === 0),
            ])
            ->defaultSort('price_idr');
    }
}
