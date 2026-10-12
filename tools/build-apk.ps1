<#
  DataLens â€” one-command APK build for Windows.

    .\tools\build-apk.ps1                    # signed release APK (default)
    .\tools\build-apk.ps1 -DebugBuild       # debug APK
    .\tools\build-apk.ps1 -SkipWebBuild     # reuse the existing www/ folder

  Note: the switch is -DebugBuild, not -Debug. CmdletBinding gives every
  script a built-in -Debug common parameter, so declaring -Debug collides
  with it and the script fails to load.

  Produces a verified, checksummed APK in dist\ at the repo root.

  Requires, in order:
    1. Node.js                      winget install OpenJS.NodeJS.LTS
    2. JDK 21                       winget install Microsoft.OpenJDK.21
    3. Android SDK + platform 36    tools\setup-android-sdk.ps1
    4. Release keystore             tools\setup-release-key.ps1
#>
[CmdletBinding()]
param(
  # Named -DebugBuild: CmdletBinding injects a -Debug common parameter
  # into every advanced function/script, so a -Debug switch collides.
  [switch]$DebugBuild,
  [switch]$SkipWebBuild
)

$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"   # silences curl's progress bar

$repoRoot = Split-Path -Parent $PSScriptRoot
Set-Location $repoRoot

function Step($n, $msg) { Write-Host "`n[$n] $msg" -ForegroundColor Cyan }
function Ok($msg)       { Write-Host "    OK  $msg" -ForegroundColor Green }
function Die($msg)      { Write-Host "    FAIL $msg" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 1. environment
Step 1 "Checking toolchain"

$jdk = [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
if (-not $jdk -or -not (Test-Path (Join-Path $jdk "bin\javac.exe"))) {
    Die "JAVA_HOME not set. Run tools\setup-java.ps1"
}

# Capacitor 8 compiles against Java 21. A 17 JDK fails with
# "invalid source release: 21", so fail early with a clear message.
$javacVer = (cmd /c "`"$jdk\bin\javac.exe`" -version 2>&1" | Out-String).Trim()
if ($javacVer -notmatch 'javac 21') {
    Die "need JDK 21 for Capacitor 8, found: $javacVer`n          run tools\setup-java.ps1 to repoint JAVA_HOME"
}
Ok "JDK 21  ($jdk)"

$sdk = "$env:LOCALAPPDATA\Android\Sdk"
foreach ($req in @("platforms\android-36", "build-tools\36.0.0", "platform-tools\adb.exe")) {
    if (-not (Test-Path (Join-Path $sdk $req))) {
        Die "Android SDK incomplete: missing $req`n            run tools\setup-android-sdk.ps1"
    }
}
Ok "Android SDK  ($sdk)"

$node = Get-Command node -ErrorAction SilentlyContinue
if (-not $node) { Die "node not on PATH. winget install OpenJS.NodeJS.LTS" }
Ok "Node $(node --version)"

$env:JAVA_HOME         = $jdk
$env:ANDROID_HOME      = $sdk
$env:ANDROID_SDK_ROOT  = $sdk
$env:Path              = "$jdk\bin;$sdk\platform-tools;$env:Path"

# ---------------------------------------------------------------- 2. signing key
Step 2 "Checking signing key"

$variant = if ($DebugBuild) { "debug" } else { "release" }
$jks     = Join-Path $repoRoot "android\keystore\datalens-release.jks"
$props   = Join-Path $repoRoot "android\keystore.properties"

if ($DebugBuild) {
    Ok "debug build - uses the auto-generated Android debug keystore"
} elseif ((Test-Path $jks) -and (Test-Path $props)) {
    Ok "release keystore found (credentials stay in gitignored keystore.properties)"
} else {
    Die "no release keyst found. run tools\setup-release-key.ps1 first,`n            or use -Debug for a throwaway signed APK"
}

# ---------------------------------------------------------------- 3. web assets
if (-not $SkipWebBuild) {
    Step 3 "Building web assets (www/)"
    & node tools/sync-web.mjs
    if ($LASTEXITCODE -ne 0) { Die "sync-web failed" }
} else {
    Step 3 "Reusing existing www/"
}

# ---------------------------------------------------------------- 4. cap copy
Step 4 "Copying assets into the Android project"
& npx.cmd cap copy android
if ($LASTEXITCODE -ne 0) { Die "cap copy failed" }

# ---------------------------------------------------------------- 5. gradle
# Windows PowerShell 5.1 has no ternary operator - use if/else.
$taskName = if ($DebugBuild) { "assembleDebug" } else { "assembleRelease" }
Step 5 "Running gradlew $taskName"
Push-Location (Join-Path $repoRoot "android")
try {
    & .\gradlew.bat $taskName --no-daemon
    if ($LASTEXITCODE -ne 0) { Die "gradle build failed (exit $LASTEXITCODE)" }
} finally {
    Pop-Location
}

$built = Join-Path $repoRoot "android\app\build\outputs\apk\$variant\app-$variant.apk"
if (-not (Test-Path $built)) { Die "expected APK not found at $built" }

# ---------------------------------------------------------------- 6. publish
Step 6 "Publishing to dist\"
$dist = Join-Path $repoRoot "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$name = "DataLens-$variant-v1.0.apk"
$out  = Join-Path $dist $name
Copy-Item $built $out -Force

# ---------------------------------------------------------------- 7. verify
Step 7 "Verifying the APK"
$aapt2     = Join-Path $sdk "build-tools\36.0.0\aapt2.exe"
$apksigner = Join-Path $sdk "build-tools\36.0.0\apksigner.bat"

$bad = (& $aapt2 dump badging $out 2>&1 | Out-String)
foreach ($l in ($bad -split "`r?`n" | Where-Object { $_ -match "^package:|sdkVersion:|targetSdkVersion:|launchable-activity:" })) {
    Ok $l.Trim()
}

$sig = (& $apksigner verify --verbose --print-certs $out 2>&1 | Out-String)
if ($sig -match "DOES NOT VERIFY") { Die "signature verification FAILED" }
Ok "signature verifies"
($sig -split "`r?`n") | Where-Object { $_ -match "DN:|SHA-256 digest" } |
    Select-Object -First 2 | ForEach-Object { Ok $_.Trim() }

# Confirm our own assets survived packaging
Add-Type -AssemblyName System.IO.Compression.FileSystem
$z = [System.IO.Compression.ZipFile]::OpenRead($out)
foreach ($n in @("assets/public/index.html","assets/public/config.js","assets/public/manifest.json")) {
    $e = $z.Entries | Where-Object { $_.FullName -eq $n }
    if (-not $e) { $z.Dispose(); Die "web asset missing from APK: $n" }
    Ok ("$n  ($($e.Length) bytes)")
}
$z.Dispose()

$hash  = (Get-FileHash $out -Algorithm SHA256).Hash
$bytes = (Get-Item $out).Length

Write-Host ""
Write-Host "===============================================" -ForegroundColor Green
Write-Host " APK READY" -ForegroundColor Green
Write-Host "===============================================" -ForegroundColor Green
Write-Host ("  path    : " + $out)
Write-Host ("  size    : {0:N2} MB ({1:N0} bytes)" -f ($bytes/1MB), $bytes)
Write-Host ("  sha256  : " + $hash)
Write-Host ("  variant : " + $variant + "   signed")
Write-Host ""
Write-Host "  install : adb install -r `"$out`""
Write-Host "          (or copy the file to the phone and open it)"
Write-Host "===============================================" -ForegroundColor Green