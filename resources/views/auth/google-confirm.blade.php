<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Hubungkan akun Google - SIMASTA</title>
    <style>body{font-family:Arial,sans-serif;background:#f0f9f6;color:#1e293b;margin:0;padding:24px}main{max-width:420px;margin:10vh auto;background:white;padding:32px;border-radius:12px;box-shadow:0 4px 20px #0001}label,input,button{display:block;width:100%;box-sizing:border-box}input,button{padding:12px;margin:10px 0;border-radius:6px}input{border:1px solid #94a3b8}button{border:0;background:#059669;color:white;cursor:pointer}.error{color:#b91c1c}</style>
</head>
<body><main>
    <h1>Hubungkan akun Google</h1>
    <p>Email {{ $email }} sudah memiliki akun SIMASTA. Masukkan kata sandi SIMASTA untuk memastikan akun ini milik Anda dan menghubungkannya ke Google.</p>
    @if ($errors->any()) <p class="error">{{ $errors->first() }}</p> @endif
    <form method="post" action="{{ route('google.confirm') }}">
        @csrf
        <label for="password">Kata sandi SIMASTA</label>
        <input id="password" name="password" type="password" autocomplete="current-password" required>
        <button type="submit">Konfirmasi dan hubungkan</button>
    </form>
    <a href="{{ route('login') }}">Kembali ke halaman masuk</a>
</main></body></html>
