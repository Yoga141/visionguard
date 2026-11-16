<?php

namespace App\Filament\Resources\Orders\Tables;

use Filament\Forms\Components\DatePicker;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\Filter;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Builder;

class OrdersTable
{
    public const STATUS_LABELS = [
        'pending' => 'Menunggu pembayaran',
        'settlement' => 'Berhasil',
        'expire' => 'Kedaluwarsa',
        'cancel' => 'Dibatalkan',
        'deny' => 'Ditolak',
    ];

    public static function configure(Table $table): Table
    {
        return $table
            ->modifyQueryUsing(fn (Builder $query) => $query->with(['user', 'package']))
            ->columns([
                TextColumn::make('order_code')->label('Kode order')->searchable()->copyable(),
                TextColumn::make('user.email')
                    ->label('Pengguna')
                    ->placeholder('Akun dihapus')
                    ->searchable(),
                TextColumn::make('package.name')->label('Paket'),
                TextColumn::make('amount_idr')->label('Nominal')->money('IDR', locale: 'id')->sortable(),
                TextColumn::make('status')
                    ->label('Status')
                    ->badge()
                    ->formatStateUsing(fn (string $state) => self::STATUS_LABELS[$state] ?? $state)
                    ->color(fn (string $state) => match ($state) {
                        'settlement' => 'success',
                        'pending' => 'warning',
                        default => 'danger',
                    }),
                TextColumn::make('payment_type')->label('Metode')->placeholder('—'),
                TextColumn::make('created_at')->label('Dibuat')->dateTime('d M Y H:i')->sortable(),
                TextColumn::make('paid_at')->label('Dibayar')->dateTime('d M Y H:i')->placeholder('—')->sortable(),
            ])
            ->filters([
                SelectFilter::make('status')->label('Status')->options(self::STATUS_LABELS),
                Filter::make('created_at')
                    ->label('Tanggal')
                    ->schema([
                        DatePicker::make('from')->label('Dari tanggal'),
                        DatePicker::make('until')->label('Sampai tanggal'),
                    ])
                    ->query(fn (Builder $query, array $data) => $query
                        ->when($data['from'] ?? null, fn (Builder $q, $date) => $q->whereDate('created_at', '>=', $date))
                        ->when($data['until'] ?? null, fn (Builder $q, $date) => $q->whereDate('created_at', '<=', $date))),
            ])
            ->defaultSort('created_at', 'desc')
            ->emptyStateHeading('Belum ada transaksi');
    }
}
