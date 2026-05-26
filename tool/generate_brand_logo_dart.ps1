# Regenerates lib/generated/brand_logo_bytes.dart from admin logo (avoids Windows file locks on assets/*.png).
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

New-Item -ItemType Directory -Force -Path $iconDir | Out-Null

$img = [System.Drawing.Image]::FromFile((Resolve-Path $src))
$maxW = 512
$scale = $maxW / $img.Width
$newW = $maxW
$newH = [int]($img.Height * $scale)
$bmp = New-Object System.Drawing.Bitmap $newW, $newH
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($img, 0, 0, $newW, $newH)
$g.Dispose(); $img.Dispose()
$bmp.Save($iconPath, [System.Drawing.Imaging.ImageFormat]::Png)
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

Write-Host "Wrote $dartPath and $iconPath"
