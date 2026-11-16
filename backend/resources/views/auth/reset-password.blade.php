@extends('layouts.plain')

@section('title', 'Kata sandi baru')

@section('content')
    <h1>Buat kata sandi baru</h1>
    <p>Isi kata sandi baru dua kali. Tautan ini berlaku 60 menit.</p>

    @if ($errors->any())
        <ul class="errors">
            @foreach ($errors->all() as $error)
                <li>{{ $error }}</li>
            @endforeach
        </ul>
    @endif

    <form method="post" action="{{ route('password.update') }}">
        @csrf
        <input type="hidden" name="token" value="{{ $token }}">

        <label for="email">Email</label>
        <input id="email" type="email" name="email" value="{{ old('email', $email) }}" required autocomplete="email">

        <label for="password">Kata sandi baru</label>
        <input id="password" type="password" name="password" required minlength="8" autocomplete="new-password">

        <label for="password_confirmation">Ulangi kata sandi baru</label>
        <input id="password_confirmation" type="password" name="password_confirmation" required minlength="8" autocomplete="new-password">

        <button type="submit">Simpan kata sandi</button>
    </form>
@endsection
