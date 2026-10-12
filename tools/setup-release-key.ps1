# Creates a DataLens release signing key.
#
#   - Generates a strong random password (never printed, never committed)
#   - Writes it to android/keystore.properties (gitignored)
#   - Emits android/keystore/datalens-release.jks (gitignored)
#
# The keystore and its properties file are both gitignored, so the private
# key and its password never reach the repository. Re-running this script
# would create a DIFFERENT key, which breaks updates on any already
# installed copy - it refuses to overwrite an existing one.
#
# Run: powershell -ExecutionPolicy Bypass -File tools\setup-release-key.ps1

$ErrorActionPreference = "Stop"

$repoRoot  = Split-Path -Parent $PSScriptRoot
$androidDir = Join-Path $repoRoot "android"
$keyDir     = Join-Path $androidDir "keystore"
$jks        = Join-Path $keyDir "datalens-release.jks"
$props      = Join-Path $androidDir "keystore.properties"

$ALIAS = "datalens"

# Cryptographically random password.
# An earlier version hard-coded "datalens-release", which is also the
# keystore filename - so anyone who saw the file path could guess the
# signing password. A signing key must be protected by a secret that is
# actually secret.
function New-Secret([int]$Length = 32) {
    # Ambiguous characters (0/O, 1/l/I) removed so the password can be
    # transcribed from a backup note without ambiguity.
    $alphabet = "abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    $chars = New-Object System.Collections.Generic.List[char]
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    try {
        # Rejection sampling so every character is equally likely, and
        # draw exactly one byte per character so the result is exactly
        # $Length long. Filling a byte buffer per iteration and adding
        # every accepted byte overshoots the target length.
        $limit = 256 - (256 % $alphabet.Length)
        # RandomNumberGenerator.Create() is RNGCryptoServiceProvider on
        # .NET Framework, which has GetBytes() but not GetByte() (the
        # latter is .NET Core / PowerShell 7 only). Draw one byte at a
        # time so the result is exactly $Length characters.
        $one = New-Object byte[] 1
        while ($chars.Count -lt $Length) {
            $rng.GetBytes($one)
            if ($one[0] -lt $limit) { $chars.Add($alphabet[$one[0] % $alphabet.Length]) }
        }
    } finally { $rng.Dispose() }
    return -join $chars
}

$STOREPW = New-Secret 32
$KEYPW   = $STOREPW

if (Test-Path $jks) {
    $force = $env:DATALENS_FORCE_NEW_KEY -eq "1"
    if (-not $force) {
        Write-Host "keystore already exists: $jks" -ForegroundColor Yellow
        Write-Host "refusing to overwrite - that would break updates on installed copies." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "To deliberately rotate (only safe before anything is installed):" -ForegroundColor Yellow
        Write-Host "  `$env:DATALENS_FORCE_NEW_KEY='1'; tools\setup-release-key.ps1" -ForegroundColor Yellow
        exit 1
    }
    Write-Host "rotating: deleting the existing keystore" -ForegroundColor Yellow
    Remove-Item $jks -Force
}

$jdk = [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
if (-not $jdk -or -not (Test-Path (Join-Path $jdk "bin\keytool.exe"))) {
    Write-Host "keytool not found. Run tools\setup-java.ps1 first." -ForegroundColor Red
    exit 1
}
$keytool = Join-Path $jdk "bin\keytool.exe"
Write-Host "keytool: $keytool"

New-Item -ItemType Directory -Force -Path $keyDir | Out-Null

# keytool writes its progress banner to stderr even on success. Under
# $ErrorActionPreference = "Stop" PowerShell turns that into a
# terminating error, which previously aborted the script AFTER the
# keystore had been written but BEFORE keystore.properties - leaving
# the two permanently out of sync. Judge success by the exit code.
$ErrorActionPreference = "Continue"

Write-Host ""
Write-Host "Generating release key (valid 30 years)..."
& $keytool -genkeypair `
    -keystore $jks `
    -storetype PKCS12 `
    -alias $ALIAS `
    -keyalg RSA `
    -keysize 4096 `
    -sigalg SHA256withRSA `
    -validity 10950 `
    -storepass $STOREPW `
    -keypass $KEYPW `
    -dname "CN=DataLens, OU=Mobile, O=DataLens, L=Lagos, C=NG"

if ($LASTEXITCODE -ne 0) { Write-Host "keytool failed ($LASTEXITCODE)" -ForegroundColor Red; exit 1 }

# Only write the properties once the keystore definitely exists and the
# password has been proven against it. Writing first and verifying later
# is what allowed the desync above.
if (-not (Test-Path $jks)) {
    Write-Host "keytool reported success but no keystore was written." -ForegroundColor Red
    exit 1
}

$verify = (& $keytool -list -keystore $jks -storepass $STOREPW 2>&1 | Out-String)
if ($verify -notmatch [regex]::Escape($ALIAS)) {
    Write-Host "password verification failed against the new keystore - refusing to write properties." -ForegroundColor Red
    Write-Host "This leaves an orphaned keystore; delete it and re-run." -ForegroundColor Yellow
    exit 1
}
Write-Host "verified: password opens the keystore and alias '$ALIAS' is present"

@(
  "# DataLens release signing config - MACHINE SPECIFIC, GITIGNORED."
  "# Contains the keystore password. Do not commit or share this file."
  "storeFile=keystore/datalens-release.jks"
  "storePassword=$STOREPW"
  "keyAlias=$ALIAS"
  "keyPassword=$KEYPW"
) | Set-Content -Path $props -Encoding ASCII

Write-Host ""
Write-Host "created keystore : $jks"
Write-Host "created properties: $props   (gitignored - password lives here)"
Write-Host ""
Write-Host "Both files are gitignored. Back up the .jks somewhere private and"
Write-Host "permanent: lose it and you cannot update the app on any device or"
Write-Host "the Play Store without publishing a new listing."
Write-Host ""
Write-Host "Password deliberately not printed. Read it from keystore.properties if needed."