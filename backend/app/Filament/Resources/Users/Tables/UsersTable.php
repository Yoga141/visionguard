<?php

namespace App\Filament\Resources\Users\Tables;

use App\Models\User;
use App\Services\CreditAdjustmentService;
use Filament\Actions\Action;
use Filament\Forms\Components\Textarea;
use Filament\Forms\Components\TextInput;
use Filament\Notifications\Notification;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Validation\ValidationException;

class UsersTable
{
    public static function configure(Table $table): Table
    {
        return $table
            // Saldo = SUM(delta) ledger (§8.3), dihitung di query.
            ->modifyQueryUsing(fn (Builder $query) => $query->withSum('creditLedger as credit_balance', 'delta'))
            ->columns([
                TextColumn::make('name')->label('Nama')->searchable(),
                TextColumn::make('email')->label('Email')->searchable()->copyable(),
                TextColumn::make('role')
                    ->label('Role')
                    ->badge()
                    ->color(fn (string $state) => $state === 'admin' ? 'info' : 'gray'),
                TextColumn::make('credit_balance')
                    ->label('Saldo kredit')
                    ->numeric()
                    ->default(0)
                    ->sortable(),
                TextColumn::make('timezone')->label('Zona waktu')->toggleable(isToggledHiddenByDefault: true),
                TextColumn::make('created_at')->label('Terdaftar')->dateTime('d M Y H:i')->sortable(),
            ])
            ->filters([
                SelectFilter::make('role')->label('Role')->options(['user' => 'user', 'admin' => 'admin']),
            ])
            ->recordActions([
                self::adjustCreditAction(),
            ])
            ->defaultSort('created_at', 'desc');
    }

    /** UC-24: delta ± dan alasan wajib; saldo akhir negatif ditolak (§8.5). */
    public static function adjustCreditAction(): Action
    {
        return Action::make('adjustCredit')
            ->label('Sesuaikan kredit')
            ->icon('heroicon-o-adjustments-horizontal')
            ->modalHeading(fn (User $record) => 'Sesuaikan kredit: '.$record->email)
            ->modalDescription(fn (User $record) => 'Saldo saat ini: '.$record->creditBalance().' kredit. Perubahan dicatat di ledger sebagai "adjustment".')
            ->schema([
                TextInput::make('delta')
                    ->label('Perubahan kredit (+ tambah, − kurangi)')
                    ->required()
                    ->integer()
                    ->notIn([0]),
                Textarea::make('note')
                    ->label('Alasan')
                    ->required()
                    ->maxLength(255),
            ])
            ->action(function (User $record, array $data, Action $action) {
                try {
                    $balance = app(CreditAdjustmentService::class)->adjust($record, (int) $data['delta'], $data['note'] ?? null);
                } catch (ValidationException $e) {
                    Notification::make()
                        ->title('Penyesuaian ditolak')
                        ->body(collect($e->errors())->flatten()->first())
                        ->danger()
                        ->send();

                    $action->halt();

                    return;
                }

                Notification::make()
                    ->title('Kredit disesuaikan')
                    ->body("Saldo terbaru: {$balance} kredit.")
                    ->success()
                    ->send();
            });
    }
}
