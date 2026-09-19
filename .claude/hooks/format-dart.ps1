# PostToolUse hook: run `dart format` on the edited file if it is Dart.
# Silent by design so formatting never costs conversation tokens.
# Prefers the pinned SDK, because PATH may point at a different one than CI uses.
try {
    $payload = [Console]::In.ReadToEnd() | ConvertFrom-Json
    $file = $payload.tool_input.file_path
    if (-not $file -or -not $file.EndsWith('.dart')) { exit 0 }

    $dart = 'D:\Desktop\projects\flutter_sdk\flutter\bin\dart.bat'
    if (-not (Test-Path $dart)) { $dart = (Get-Command dart -ErrorAction SilentlyContinue).Source }
    if ($dart) { & $dart format $file *> $null }
} catch {}
exit 0
