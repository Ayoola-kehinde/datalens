# Resume the Gradle distribution download that the wrapper abandoned.
#
# The wrapper writes to <dist>/<hash>/gradle-<ver>-bin.zip.part and supports
# HTTP range requests, so curl can continue the exact same file. Once the
# byte count matches Content-Length we rename .part -> .zip, which is what
# the wrapper looks for to skip downloading.

$dist = "$env:USERPROFILE\.gradle\wrapper\dists\gradle-8.14.3-bin"
$part = Get-ChildItem $dist -Recurse -Filter "*.zip.part" | Select-Object -First 1
if (-not $part) { Write-Host "no .part file found - cannot resume"; exit 1 }

$partPath = $part.FullName
$url = "https://services.gradle.org/distributions/gradle-8.14.3-bin.zip"
$maxAttempts = 40

$expected = [int64](Invoke-WebRequest -Uri $url -Method Head -UseBasicParsing -TimeoutSec 30).Headers['Content-Length']
Write-Host ("target : {0} MB" -f [math]::Round($expected/1MB,1))
Write-Host ("resume : {0} MB already on disk" -f [math]::Round($part.Length/1MB,1))
Write-Host ("path   : $partPath")
Write-Host ""

function SizeOf($p) { if (Test-Path $p) { (Get-Item $p).Length } else { 0 } }

for ($i = 1; $i -le $maxAttempts; $i++) {
    $have = SizeOf $partPath
    if ($have -ge $expected) { break }

    Write-Host ("attempt {0}/{1}  have {2:N1} MB ({3}%)" -f `
        $i, $maxAttempts, ($have/1MB), [math]::Round($have/$expected*100,1))

    curl.exe -L --http1.1 --retry 5 --retry-delay 3 --retry-all-errors `
            -C - --connect-timeout 20 --max-time 240 -s -o $partPath $url

    $now = SizeOf $partPath
    if ($now -gt $have) { Write-Host ("  gained {0:N1} MB" -f (($now-$have)/1MB)) }
    else { Write-Host "  no progress (curl exit $LASTEXITCODE), backing off"; Start-Sleep -Seconds 4 }
}

$have = SizeOf $partPath
Write-Host ""
if ($have -lt $expected) {
    Write-Host ("FAILED: {0:N1} MB of {1:N1} MB" -f ($have/1MB), ($expected/1MB))
    exit 1
}

# The wrapper treats a complete .zip as "already installed" and skips the fetch.
$zip = $partPath -replace '\.part$',''
Move-Item $partPath $zip -Force
Remove-Item ($partPath -replace '\.part$','.lck') -Force -ErrorAction SilentlyContinue
Write-Host ("COMPLETE: {0:N0} bytes" -f (Get-Item $zip).Length)
Write-Host "seeded -> $zip"