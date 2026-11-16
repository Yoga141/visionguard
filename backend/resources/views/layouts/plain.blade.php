<!doctype html>
<html lang="id">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex">
    <title>@yield('title') · VisionGuard</title>
    <style>
        :root { --bg: #f4f6f8; --card: #fff; --text: #1d2730; --muted: #5b6b78; --ok: #1f7a4d; --warn: #9a6700; --err: #b42318; --primary: #1565c0; --border: #d9e0e6; }
        @media (prefers-color-scheme: dark) {
            :root { --bg: #12171c; --card: #1b232b; --text: #e6edf3; --muted: #9fb0bf; --ok: #4cc38a; --warn: #e3b341; --err: #f97066; --primary: #64a8ff; --border: #2c3741; }
        }
        * { box-sizing: border-box; }
        body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 16px; background: var(--bg); color: var(--text); font: 16px/1.5 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
        main { width: 100%; max-width: 440px; background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 28px 24px; }
        h1 { font-size: 1.35rem; margin: 0 0 8px; }
        p { margin: 0 0 12px; color: var(--muted); }
        .status { font-weight: 600; margin-bottom: 12px; }
        .ok { color: var(--ok); } .warn { color: var(--warn); } .err { color: var(--err); }
        dl { display: grid; grid-template-columns: auto 1fr; gap: 4px 12px; margin: 0 0 16px; }
        dt { color: var(--muted); } dd { margin: 0; font-weight: 600; overflow-wrap: anywhere; }
        label { display: block; font-weight: 600; margin: 12px 0 4px; }
        input { width: 100%; padding: 10px 12px; border: 1px solid var(--border); border-radius: 8px; background: var(--bg); color: var(--text); font: inherit; }
        button { width: 100%; margin-top: 12px; padding: 11px 12px; border: 0; border-radius: 8px; background: var(--primary); color: #fff; font: inherit; font-weight: 600; cursor: pointer; }
        button.secondary { background: transparent; color: var(--text); border: 1px solid var(--border); }
        .errors { color: var(--err); margin: 0 0 12px; padding-left: 18px; }
        .brand { font-size: .85rem; color: var(--muted); margin-bottom: 16px; letter-spacing: .02em; }
    </style>
</head>
<body>
<main>
    <div class="brand">VisionGuard</div>
    @yield('content')
</main>
</body>
</html>
