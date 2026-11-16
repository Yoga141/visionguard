@extends('layouts.plain')

@section('title', 'Simulasi pembayaran')

@section('content')
    <h1>Simulasi pembayaran</h1>
    <p class="status warn">Mode simulasi — tidak ada uang sungguhan. Hanya untuk demo &amp; pengujian.</p>

    <dl>
        <dt>Order</dt><dd>{{ $order->order_code }}</dd>
        <dt>Paket</dt><dd>{{ $order->package?->name }} ({{ $order->package?->credits }} kredit)</dd>
        <dt>Total</dt><dd>Rp{{ number_format($order->amount_idr, 0, ',', '.') }}</dd>
        <dt>Status</dt><dd>{{ $order->status }}</dd>
    </dl>

    @if ($order->status === 'pending')
        <form method="post" action="{{ route('payments.simulate.pay', $order->order_code) }}">
            @csrf
            <button type="submit" name="status" value="settlement">Bayar (berhasil)</button>
            <button type="submit" name="status" value="expire" class="secondary">Biarkan kedaluwarsa</button>
            <button type="submit" name="status" value="cancel" class="secondary">Batalkan</button>
            <button type="submit" name="status" value="deny" class="secondary">Tolak</button>
        </form>
    @else
        <p>Order ini sudah final. Kembali ke aplikasi VisionGuard.</p>
    @endif
@endsection
