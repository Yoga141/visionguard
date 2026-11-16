@extends('layouts.plain')

@php
    $titles = [
        'finish' => 'Pembayaran diproses',
        'unfinish' => 'Pembayaran belum selesai',
        'error' => 'Pembayaran gagal',
    ];
    $statusLabels = [
        'pending' => ['Menunggu pembayaran', 'warn'],
        'settlement' => ['Berhasil, kredit sudah ditambahkan', 'ok'],
        'expire' => ['Kedaluwarsa', 'err'],
        'cancel' => ['Dibatalkan', 'err'],
        'deny' => ['Ditolak', 'err'],
    ];
@endphp

@section('title', $titles[$variant])

@section('content')
    <h1>{{ $titles[$variant] }}</h1>

    @if ($variant === 'finish')
        <p>Terima kasih. Kredit ditambahkan otomatis setelah Midtrans mengonfirmasi pembayaran.</p>
    @elseif ($variant === 'unfinish')
        <p>Pembayaran belum diselesaikan. Anda bisa mencoba lagi dari aplikasi.</p>
    @else
        <p>Terjadi kesalahan saat memproses pembayaran. Saldo Anda tidak berubah.</p>
    @endif

    @if ($order)
        <dl>
            <dt>Order</dt><dd>{{ $order->order_code }}</dd>
            <dt>Paket</dt><dd>{{ $order->package?->name }}</dd>
            <dt>Status</dt>
            <dd class="{{ $statusLabels[$order->status][1] ?? '' }}">{{ $statusLabels[$order->status][0] ?? $order->status }}</dd>
        </dl>
    @endif

    <p><strong>Kembali ke aplikasi VisionGuard</strong>, lalu buka menu Kredit dan ketuk <em>Muat ulang status</em>. Halaman ini boleh ditutup.</p>
@endsection
