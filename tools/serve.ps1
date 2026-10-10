<#
  DataLens local static server.

  Service workers only run on a secure context, so the ONLY way to test the
  PWA on your own machine without deploying is over http://localhost.

  Usage:
      powershell -ExecutionPolicy Bypass -File tools\serve.ps1
      powershell -ExecutionPolicy Bypass -File tools\serve.ps1 -Port 3000

  Then open:  http://localhost:8080
#>
param(
  [int]$Port = 8080,
  [string]$Root = ""
)

$ErrorActionPreference = "Stop"

if (-not $Root) {
  # tools/ -> project root
  $Root = Split-Path -Parent $PSScriptRoot
}

Write-Host ""
Write-Host "  DataLens local server" -ForegroundColor Cyan
Write-Host "  --------------------" -ForegroundColor DarkCyan
Write-Host "  Root : $Root"
Write-Host "  URL  : http://localhost:$Port"
Write-Host ""
Write-Host "  Install test in Chrome: address bar -> install icon, or"
Write-Host "  DevTools (F12) -> Application -> Manifest"
Write-Host ""
Write-Host "  Press Ctrl+C to stop." -ForegroundColor DarkGray
Write-Host ""

$MIME = @{
  ".html"  = "text/html; charset=utf-8"
  ".js"    = "text/javascript; charset=utf-8"
  ".mjs"   = "text/javascript; charset=utf-8"
  ".css"   = "text/css; charset=utf-8"
  ".json"  = "application/json; charset=utf-8"
  ".webmanifest" = "application/manifest+json; charset=utf-8"
  ".png"   = "image/png"
  ".jpg"   = "image/jpeg"
  ".svg"   = "image/svg+xml"
  ".ico"   = "image/x-icon"
  ".webp"  = "image/webp"
  ".woff2" = "font/woff2"
  ".pdf"   = "application/pdf"
  ".txt"   = "text/plain; charset=utf-8"
  ".md"    = "text/markdown; charset=utf-8"
}

try {
  $listener = New-Object System.Net.HttpListener
  $listener.Prefixes.Add("http://localhost:$Port/")
  $listener.Prefixes.Add("http://127.0.0.1:$Port/")
  $listener.Start()
} catch {
  Write-Host "  ERROR: could not bind port $Port" -ForegroundColor Red
  Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
  Write-Host ""
  Write-Host "  Port $Port may be in use. Try another:" -ForegroundColor Yellow
  Write-Host "    powershell -ExecutionPolicy Bypass -File tools\serve.ps1 -Port 3001" -ForegroundColor Yellow
  exit 1
}

while ($listener.IsListening) {
  try {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response

    # Map request path to a file inside Root, refusing anything that escapes it
    $raw = [System.Uri]::UnescapeDataString($req.Url.AbsolutePath)
    if ($raw.EndsWith("/")) { $raw += "index.html" }
    if ($raw -eq "/") { $raw = "/index.html" }

    $full = Join-Path $Root ($raw.TrimStart('/') -replace '/', '\')
    $full = [System.IO.Path]::GetFullPath($full)

    if (-not $full.StartsWith([System.IO.Path]::GetFullPath($Root), [StringComparison]::OrdinalIgnoreCase)) {
      $res.StatusCode = 403
      $res.Close()
      continue
    }

    if (-not (Test-Path $full -PathType Leaf)) {
      $res.StatusCode = 404
      $b = [Text.Encoding]::UTF8.GetBytes("404 Not Found: $raw")
      $res.ContentType = "text/plain"
      $res.ContentLength64 = $b.Length
      $res.OutputStream.Write($b, 0, $b.Length)
      $res.Close()
      continue
    }

    $ext = [System.IO.Path]::GetExtension($full).ToLower()
    $ctype = if ($MIME.ContainsKey($ext)) { $MIME[$ext] } else { "application/octet-stream" }

    # Service workers and the manifest must never be served stale
    $noCache = ($raw -eq "/sw.js") -or ($raw -eq "/manifest.webmanifest")
    $bytes = [System.IO.File]::ReadAllBytes($full)

    $res.ContentType = $ctype
    $res.ContentLength64 = $bytes.Length
    if ($noCache) {
      $res.Headers["Cache-Control"] = "no-cache, no-store, must-revalidate"
      $res.Headers["Service-Worker-Allowed"] = "/"
    } else {
      $res.Headers["Cache-Control"] = "no-cache"
    }
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.Close()
  } catch {
    Write-Host "  request error: $($_.Exception.Message)" -ForegroundColor DarkYellow
  }
}

$listener.Stop()
$listener.Close()