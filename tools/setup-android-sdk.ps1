<#
  DataLens — Android SDK provisioning.

  Takes the Google command-line tools zip, lays out a valid SDK tree,
  accepts licenses, installs the packages Capacitor 8 needs, and writes
  android/local.properties.

  Run:  powershell -ExecutionPolicy Bypass -File tools\setup-android-sdk.ps1
#>

$ErrorActionPreference = "Stop"

# What Capacitor 8's variables.gradle asks for.
$COMPILE_SDK = "36"
$BUILD_TOOLS = "36.0.0"
$MIN_SDK     = "24"

$SDK       = "$env:LOCALAPPDATA\Android\Sdk"
$ZIP       = "$env:TEMP\cmdline-tools.zip"
$JDK_HOME  = [Environment]::GetEnvironmentVariable("JAVA_HOME", "User")
$PKGS      = @("platform-tools", "platforms;android-$COMPILE_SDK", "build-tools;$BUILD_TOOLS")

function Say($msg, $colour = "Gray") { Write-Host $msg -ForegroundColor $colour }

# ---------------------------------------------------------------- 1. JDK
if (-not $JDK_HOME -or -not (Test-Path (Join-Path $JDK_HOME "bin\java.exe"))) {
    Say "FATAL: JAVA_HOME is not set to a valid JDK." "Red"
    Say "       Run tools\setup-java.ps1 first." "Yellow"
    exit 1
}
$env:JAVA_HOME = $JDK_HOME
$env:Path = "$JDK_HOME\bin;$env:Path"
Say "JAVA_HOME = $JDK_HOME"

# ---------------------------------------------------------------- 2. unzip
$cmdlineRoot = Join-Path $SDK "cmdline-tools\latest"
$sdkManager  = Join-Path $cmdlineRoot "bin\sdkmanager.bat"

if (-not (Test-Path $sdkManager)) {
    if (-not (Test-Path $ZIP)) {
        Say "FATAL: $ZIP not found. Download commandlinetools first." "Red"
        exit 1
    }

    $zipMB = [math]::Round((Get-Item $ZIP).Length / 1MB, 1)
    Say "Extracting command-line tools ($zipMB MB)..."

    $stage = Join-Path $env:TEMP "cmdline-stage"
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path $stage | Out-Null

    Expand-Archive -Path $ZIP -DestinationPath $stage -Force

    # The zip contains a top-level cmdline-tools\ folder. sdkmanager requires
    # the layout <sdk>\cmdline-tools\latest\bin\sdkmanager.bat, so the folder
    # has to be moved one level deeper and renamed.
    $inner = Join-Path $stage "cmdline-tools"
    if (-not (Test-Path $inner)) { Say "FATAL: unexpected zip layout." "Red"; exit 1 }

    New-Item -ItemType Directory -Force -Path (Split-Path $cmdlineRoot) | Out-Null
    Remove-Item $cmdlineRoot -Recurse -Force -ErrorAction SilentlyContinue
    Move-Item $inner $cmdlineRoot
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

    if (-not (Test-Path $sdkManager)) {
        Say "FATAL: sdkmanager.bat not found after extraction." "Red"
        exit 1
    }
}
Say "sdkmanager: $sdkManager"

# ---------------------------------------------------------------- 3. env
foreach ($scope in @("User")) {
    [Environment]::SetEnvironmentVariable("ANDROID_HOME", $SDK, $scope)
    [Environment]::SetEnvironmentVariable("ANDROID_SDK_ROOT", $SDK, $scope)

    $p = [Environment]::GetEnvironmentVariable("Path", $scope)
    foreach ($extra in @((Join-Path $cmdlineRoot "bin"), (Join-Path $SDK "platform-tools"))) {
        if ($p -notlike "*$extra*") { $p = $p.TrimEnd(";") + ";" + $extra }
    }
    [Environment]::SetEnvironmentVariable("Path", $p, $scope)
}
$env:ANDROID_HOME      = $SDK
$env:ANDROID_SDK_ROOT  = $SDK
$env:Path = "$SDK\platform-tools;$cmdlineRoot\bin;$env:Path"
Say "ANDROID_HOME = $SDK"

# ---------------------------------------------------------------- 4. licenses
# sdkmanager writes progress and deprecation warnings to stderr. Under
# $ErrorActionPreference = "Stop" PowerShell turns ANY stderr line from a
# native command into a terminating error, so relax it for the whole
# provisioning section and judge success by exit codes instead.
$ErrorActionPreference = "Continue"

Say ""
Say "Accepting SDK licenses..."
$answers = (1..40 | ForEach-Object { "y" }) -join "`n"
$lic = $answers | & $sdkManager --sdk_root="$SDK" --licenses 2>&1
$lic | Where-Object { $_ -notmatch "WARNING|CategoryInfo|FullyQualifiedErrorId|^\s*\+|At C:" } |
    Select-Object -Last 3 | ForEach-Object { Say "  $_" }

# ---------------------------------------------------------------- 5. packages
foreach ($pkg in $PKGS) {
    Say ""
    Say "Installing $pkg ..."
    # Package ids contain a semicolon ("platforms;android-36"). Passing that
    # as a DIRECT argument does not work, even when PowerShell quotes it
    # correctly: sdkmanager.bat is a batch wrapper that re-splits the id on
    # the semicolon, so it reports "Package platforms not found / Package
    # android-36 not found". Reproduced directly before settling on this.
    # --package_file= reads ids from a file and bypasses the wrapper.
    $pf = Join-Path $env:TEMP "datalens-sdk-pkg.txt"
    $pkg | Set-Content -Path $pf -Encoding ASCII

    $out = & $sdkManager --sdk_root="$SDK" "--package_file=$pf" 2>&1
    $tail = $out | Where-Object { $_ -notmatch "CategoryInfo|FullyQualifiedErrorId|^\s*\+|At C:|WARNING|deprecated|android binary|documentation" } |
             Select-Object -Last 3
    if ($LASTEXITCODE -eq 0) {
        $tail | ForEach-Object { Say "  $_" }
    } else {
        Say "  FAILED ($LASTEXITCODE)" "Red"
        $tail | ForEach-Object { Say "  $_" "DarkRed" }
    }
    Remove-Item $pf -Force -ErrorAction SilentlyContinue
}

# ---------------------------------------------------------------- 6. verify
Say ""
Say "=== installed packages ==="
& $sdkManager --sdk_root="$SDK" --list_installed 2>&1 |
    Where-Object { $_ -notmatch "CategoryInfo|FullyQualifiedErrorId|^\s*\+|At C:|WARNING" } |
    Select-String -Pattern "platform-tools|platforms;android-$COMPILE_SDK|build-tools;$BUILD_TOOLS" |
    ForEach-Object { Say ("  " + $_.Line.Trim()) }

$missing = @()
foreach ($check in @(
    (Join-Path $SDK "platform-tools\adb.exe"),
    (Join-Path $SDK "platforms\android-$COMPILE_SDK"),
    (Join-Path $SDK "build-tools\$BUILD_TOOLS")
)) { if (-not (Test-Path $check)) { $missing += $check } }

if ($missing.Count) {
    Say ""
    Say "MISSING after install:" "Red"
    $missing | ForEach-Object { Say "  $_" "Red" }
    exit 1
}

# ---------------------------------------------------------------- 7. local.properties
$repoRoot = Split-Path -Parent $PSScriptRoot
$lp       = Join-Path $repoRoot "android\local.properties"
# Java properties format: a backslash in the value must be doubled.
# Use String.Replace (literal) rather than -replace (regex), where the
# escaping rules differ and previously produced C:\\\\Users instead of C:\\Users.
$escaped  = $SDK.Replace('\', '\\')
$content  = "### Generated by tools\setup-android-sdk.ps1 - machine specific, gitignored`r`nsdk.dir=$escaped"
Set-Content -Path $lp -Value $content -Encoding ASCII
Say ""
Say "wrote $lp"
Say "sdk.dir=$SDK"

Say ""
Say "SDK ready. Next: cd android; .\gradlew assembleDebug" "Green"