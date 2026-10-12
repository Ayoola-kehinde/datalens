# Completes deployment steps 1 and 2:
#   - waits for the winget JDK install to land on disk
#   - sets JAVA_HOME (machine scope if permitted, else user scope)
#   - adds the JDK bin directory to PATH
#   - verifies java and javac resolve

$ErrorActionPreference = "Stop"

function Find-Jdk {
    $roots = @(
        "$env:ProgramFiles\Microsoft",
        "$env:ProgramFiles\Eclipse Adoptium",
        "$env:ProgramFiles\Java",
        "$env:ProgramFiles\Amazon Corretto",
        "${env:ProgramFiles(x86)}\Microsoft"
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($r in $roots) {
        $hit = Get-ChildItem $r -Directory -ErrorAction SilentlyContinue |
               Where-Object {
                   $_.Name -match '^(jdk-17|jdk-17\.0|jre-17|openjdk-17)' -and
                   (Test-Path (Join-Path $_.FullName "bin\java.exe"))
               } |
               Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

Write-Host "waiting for the JDK install to finish..." -ForegroundColor Cyan
$jdk = $null
for ($i = 0; $i -lt 90; $i++) {
    $jdk = Find-Jdk
    if ($jdk) { break }
    Start-Sleep -Seconds 10
}

if (-not $jdk) {
    Write-Host "TIMED OUT: no JDK 17 found after 15 minutes" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "JDK located: $jdk" -ForegroundColor Green

# $jdk is already the JDK root (that is what Find-Jdk validates against
# bin\java.exe), so it IS the JAVA_HOME. Stripping again would set
# JAVA_HOME to "C:\Program Files" and Gradle would fail to find javac.
$javaHome = $jdk
$binDir   = Join-Path $jdk "bin"

# --- set JAVA_HOME (machine preferred, fall back to user) ---
$scopeSet = $null
foreach ($scope in @("Machine", "User")) {
    try {
        [Environment]::SetEnvironmentVariable("JAVA_HOME", $javaHome, $scope)
        $scopeSet = $scope
        break
    } catch {
        Write-Host "  could not set JAVA_HOME at ${scope} scope (needs admin)" -ForegroundColor Yellow
    }
}
if (-not $scopeSet) { Write-Host "FAILED to set JAVA_HOME" -ForegroundColor Red; exit 1 }
Write-Host "JAVA_HOME set at ${scopeSet} scope -> $javaHome" -ForegroundColor Green

# --- add bin to PATH ---
$current = [Environment]::GetEnvironmentVariable("Path", $scopeSet)
if (-not $current) { $current = "" }
if ($current -notlike "*$binDir*") {
    $newPath = $current.TrimEnd(";") + ";" + $binDir
    [Environment]::SetEnvironmentVariable("Path", $newPath, $scopeSet)
    Write-Host "added to PATH at ${scopeSet} scope: $binDir" -ForegroundColor Green
} else {
    Write-Host "bin already on PATH" -ForegroundColor DarkGray
}

# --- refresh this process and verify ---
$env:JAVA_HOME = $javaHome
$env:Path = $javaHome + "\bin;" + $env:Path

Write-Host ""
Write-Host "=== verification ===" -ForegroundColor Cyan

# java/javac write version output to stderr. With $ErrorActionPreference
# = Stop, PowerShell turns that into a terminating error, so shell out to
# cmd which just merges the streams.
$javaExe = Join-Path $binDir "java.exe"
$javacExe = Join-Path $binDir "javac.exe"

$javaOut = (cmd /c "`"$javaExe`" -version 2>&1") -join "`n"
Write-Host $javaOut
Write-Host ""

if (Test-Path $javacExe) {
    $v = (cmd /c "`"$javacExe`" -version 2>&1") -join " "
    Write-Host "  $v"
} else {
    Write-Host "  javac.exe NOT FOUND - this is a JRE, not a JDK" -ForegroundColor Red
    exit 1
}

if ($javaOut -notmatch 'version "17') {
    Write-Host "  WARNING: expected a Java 17 runtime" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "JAVA_HOME = $javaHome" -ForegroundColor Green
Write-Host "environment ready for gradlew" -ForegroundColor Green