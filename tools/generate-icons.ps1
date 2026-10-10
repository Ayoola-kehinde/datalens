<#
  Generates DataLens PWA icon set.
  Draws the brand mark (rounded square + "DL" wordmark) programmatically
  so icons stay in sync with the design system colours.
#>
Add-Type -AssemblyName System.Drawing

# Icons belong at the web root so the manifest can reference /icons/*.png
$webRoot = Split-Path -Parent $PSScriptRoot
$outDir  = Join-Path $webRoot "icons"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

# Brand colours from design.html tokens
$bgTop     = [System.Drawing.Color]::FromArgb(255, 41, 98, 255)    # primary-500 Signal Blue
$bgMid     = [System.Drawing.Color]::FromArgb(255, 30, 79, 214)    # primary-600
$bgBottom  = [System.Drawing.Color]::FromArgb(255, 232, 169, 13)   # secondary-500 Tape Gold
$ink       = [System.Drawing.Color]::White
$transparent = [System.Drawing.Color]::Transparent

function New-RoundedRectPath([System.Drawing.Graphics]$g, [float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  $path.AddArc($x, $y, $d, $d, 180, 90)
  $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  $path.CloseFigure()
  return $path
}

function New-Icon([int]$size, [string]$file, [bool]$maskable, [string]$purpose) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g   = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
  $g.Clear($transparent)

  # Maskable icons need the content inside the safe zone (centre 80%).
  # Non-maskable icons use a rounded square that fills most of the canvas.
  if ($maskable) {
    $pad = $size * 0.18
    $box = $size - ($pad * 2)
  } else {
    $pad = $size * 0.055
    $box = $size - ($pad * 2)
  }

  $rect = New-Object System.Drawing.RectangleF($pad, $pad, $box, $box)
  $rad  = if ($maskable) { $box * 0.20 } else { $box * 0.225 }

  # Gradient background
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    $rect, $bgTop, $bgBottom,
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal)
  $g.FillPath($brush, (New-RoundedRectPath $g $rect.X $rect.Y $rect.Width $rect.Height $rad))
  $brush.Dispose()

  # "DL" wordmark, centred
  $fontSize = [float]($box * 0.44)
  $f = New-Object System.Drawing.Font("Segoe UI", $fontSize, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment     = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  $tb = New-Object System.Drawing.SolidBrush($ink)

  # Optical centring nudge (cap-height sits low in most fonts)
  $strRect = New-Object System.Drawing.RectangleF(
    $rect.X, ($rect.Y + ($rect.Height * 0.045)), $rect.Width, $rect.Height)
  $g.DrawString("DL", $f, $tb, $strRect, $fmt)
  $tb.Dispose(); $f.Dispose(); $fmt.Dispose()

  $out = Join-Path $outDir $file
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output ("  created {0,-26} {1}x{1}  {2}  ({3} KB)" -f $file, $size, $purpose, [math]::Round((Get-Item $out).Length/1KB,1))
}

# ---- Standard (any purpose) ----
New-Icon 192 "icon-192.png"      $false "any"
New-Icon 512 "icon-512.png"      $false "any"
New-Icon 384 "icon-384.png"      $false "any"
New-Icon 180 "apple-touch-icon.png" $false "apple-touch"

# ---- Maskable (Android adaptive, safe zone honoured) ----
New-Icon 192 "icon-maskable-192.png" $true "maskable"
New-Icon 512 "icon-maskable-512.png" $true "maskable"

# ---- Favicon ----
New-Icon 64  "favicon-64.png"    $false "favicon"
Write-Output ""
Write-Output ("Icon set written to: " + $outDir)