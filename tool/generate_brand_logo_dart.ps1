# Regenerates lib/generated/brand_logo_bytes.dart from admin logo (avoids Windows file locks on assets/*.png).
# Trims near-white margins so the logo fills its plate.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$src = Join-Path $root 'connectghin-server\admin\public\connectghin-logo.png'
if (-not (Test-Path $src)) {
  $src = Join-Path (Split-Path $PSScriptRoot -Parent) '..\connectghin-server\admin\public\connectghin-logo.png'
}
$mobileRoot = Split-Path $PSScriptRoot -Parent
$iconDir = Join-Path $PSScriptRoot 'branding'
$iconPath = Join-Path $iconDir 'launcher_icon.png'
$dartPath = Join-Path $mobileRoot 'lib\generated\brand_logo_bytes.dart'
$brandAsset = Join-Path $mobileRoot 'assets\connectghin_brand.png'
$appLogo = Join-Path $mobileRoot 'assets\branding\app_logo.png'

New-Item -ItemType Directory -Force -Path $iconDir | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path $appLogo) | Out-Null

function Test-IsBackground([System.Drawing.Color]$c) {
  if ($c.A -lt 16) { return $true }
  return ($c.R -gt 245 -and $c.G -gt 245 -and $c.B -gt 245)
}

function Get-ContentBounds([System.Drawing.Bitmap]$bmp) {
  $w = $bmp.Width; $h = $bmp.Height
  $minX = $w; $minY = $h; $maxX = 0; $maxY = 0
  for ($y = 0; $y -lt $h; $y++) {
    for ($x = 0; $x -lt $w; $x++) {
      if (-not (Test-IsBackground ($bmp.GetPixel($x, $y)))) {
        if ($x -lt $minX) { $minX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }
  if ($maxX -lt $minX) {
    return New-Object System.Drawing.Rectangle 0, 0, $w, $h
  }
  $pad = [Math]::Max(8, [int]([Math]::Max($maxX - $minX + 1, $maxY - $minY + 1) * 0.03))
  $x0 = [Math]::Max(0, $minX - $pad)
  $y0 = [Math]::Max(0, $minY - $pad)
  $x1 = [Math]::Min($w - 1, $maxX + $pad)
  $y1 = [Math]::Min($h - 1, $maxY + $pad)
  return New-Object System.Drawing.Rectangle $x0, $y0, ($x1 - $x0 + 1), ($y1 - $y0 + 1)
}

$img = [System.Drawing.Bitmap]::FromFile((Resolve-Path $src))
$bounds = Get-ContentBounds $img
$cropped = New-Object System.Drawing.Bitmap $bounds.Width, $bounds.Height
$gc = [System.Drawing.Graphics]::FromImage($cropped)
$gc.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gc.DrawImage(
  $img,
  (New-Object System.Drawing.Rectangle 0, 0, $bounds.Width, $bounds.Height),
  $bounds,
  [System.Drawing.GraphicsUnit]::Pixel
)
$gc.Dispose(); $img.Dispose()

$maxSide = 640
$scale = if ($cropped.Width -ge $cropped.Height) { $maxSide / $cropped.Width } else { $maxSide / $cropped.Height }
$newW = [Math]::Max(1, [int]($cropped.Width * $scale))
$newH = [Math]::Max(1, [int]($cropped.Height * $scale))
$bmp = New-Object System.Drawing.Bitmap $newW, $newH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($cropped, 0, 0, $newW, $newH)
$g.Dispose(); $cropped.Dispose()

$bmp.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save($brandAsset, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save($appLogo, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()

$b64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($iconPath))
$chunks = for ($i = 0; $i -lt $b64.Length; $i += 76) {
  '    "' + $b64.Substring($i, [Math]::Min(76, $b64.Length - $i)) + '"'
}
# Adjacent string literals (no commas) concatenate in Dart.
$chunkBody = $chunks -join "`n"

@"

// Generated from tool/branding/launcher_icon.png — do not edit by hand.
// Regenerate: powershell -File tool/generate_brand_logo_dart.ps1

import 'dart:convert';
import 'dart:typed_data';

const _kBrandLogoPngBase64 =
$chunkBody;

final Uint8List kBrandLogoPngBytes = base64Decode(_kBrandLogoPngBase64);
"@ | Set-Content -Path $dartPath -Encoding UTF8

$splashSrc = if (Test-Path -LiteralPath $appLogo) { $appLogo } else { $src }
& (Join-Path $PSScriptRoot 'generate_launch_splash.ps1') -Source $splashSrc

Write-Host "Wrote $dartPath and $iconPath ($newW x $newH)"
