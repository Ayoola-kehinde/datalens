# Repeatedly resume the Android command-line tools download.
# dl.google.com resets long-lived bulk transfers on this connection, but
# each attempt still banks some progress, so looping with -C - converges.
# Stops when the file matches Content-Length or attempts are exhausted.

$zip = "$env:TEMP\cmdline-tools.zip"
$url = "https://dl.google.com/android/repository/commandlinetools-win-16111833_latest.zip"
$expected = 154957218
$maxAttempts = 40

function SizeOf($p) { if (Test-Path $p) { (Get-Item $p).Length } else { 0 } }

for ($i = 1; $i -le $maxAttempts; $i++) {
    $have = SizeOf $zip
    $pct  = [math]::Round($have / $expected * 100, 1)

    if ($have -ge $expected) {
        Write-Host "COMPLETE: $have bytes ($pct%)"
        exit 0
    }

    Write-Host ("attempt {0}/{1}  have {2:N1} MB ({3}%)" -f $i, $maxAttempts, ($have/1MB), $pct)

    # -s silences the progress bar; errors surface via exit code.
    curl.exe -L --http1.1 --retry 5 --retry-delay 2 --retry-all-errors `
            -C - --connect-timeout 20 --max-time 240 -s -o $zip $url

    $now = SizeOf $zip
    if ($now -gt $have) {
        Write-Host ("  gained {0:N1} MB" -f (($now - $have)/1MB))
    } else {
        Write-Host "  no progress (curl exit $LASTEXITCODE), backing off"
        Start-Sleep -Seconds 5
    }
}

$have = SizeOf $zip
Write-Host ""
Write-Host ("FAILED after {0} attempts. {1:N1} MB of {2:N1} MB ({3}%)" -f `
    $maxAttempts, ($have/1MB), ($expected/1MB), [math]::Round($have/$expected*100,1))
exit 1