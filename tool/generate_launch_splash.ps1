# Generates Android launch_logo.png and iOS LaunchImage from assets/branding/app_logo.png.
param(
    [string]$Source = '',
    [int]$AndroidMaxPx = 168,
    [int]$IosMaxPx1x = 160
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$mobileRoot = Split-Path $PSScriptRoot -Parent

if ([string]::IsNullOrWhiteSpace($Source)) {
    $candidates = @(
        (Join-Path $mobileRoot 'assets\branding\app_logo.png'),
        (Join-Path $mobileRoot '..\connectghin-server\admin\public\connectghin-logo.png'),
        (Join-Path $PSScriptRoot 'branding\launcher_icon.png')
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) { $Source = (Resolve-Path -LiteralPath $c).Path; break }
    }
}
if (-not (Test-Path -LiteralPath $Source)) {
    throw "Logo source not found: $Source"
}

function Test-NearWhite([System.Drawing.Color]$c, [int]$threshold = 242) {
    return $c.A -gt 0 -and $c.R -ge $threshold -and $c.G -ge $threshold -and $c.B -ge $threshold
}

function Get-ContentBounds([System.Drawing.Bitmap]$bmp) {
    $minX = $bmp.Width
    $minY = $bmp.Height
    $maxX = 0
    $maxY = 0
    for ($y = 0; $y -lt $bmp.Height; $y++) {
        for ($x = 0; $x -lt $bmp.Width; $x++) {
            if (-not (Test-NearWhite $bmp.GetPixel($x, $y))) {
                if ($x -lt $minX) { $minX = $x }
                if ($y -lt $minY) { $minY = $y }
                if ($x -gt $maxX) { $maxX = $x }
                if ($y -gt $maxY) { $maxY = $y }
            }
        }
    }
    if ($maxX -le $minX) { return $null }
    return [pscustomobject]@{ X = $minX; Y = $minY; W = ($maxX - $minX + 1); H = ($maxY - $minY + 1) }
}

function Save-ScaledPng([System.Drawing.Image]$src, [string]$path, [int]$maxDim) {
    $scale = $maxDim / [Math]::Max($src.Width, $src.Height)
    if ($scale -gt 1) { $scale = 1 }
    $w = [Math]::Max(1, [int]($src.Width * $scale))
    $h = [Math]::Max(1, [int]($src.Height * $scale))
    $bmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.Clear([System.Drawing.Color]::Transparent)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($src, 0, 0, $w, $h)
    $g.Dispose()
    $dir = Split-Path $path -Parent
    if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "  $path (${w}x${h})"
}

Write-Host "Source: $Source"
$srcImg = [System.Drawing.Bitmap]::FromFile((Resolve-Path -LiteralPath $Source))
$bounds = Get-ContentBounds $srcImg
if ($null -eq $bounds) { throw 'No non-white content found in logo source.' }

$cropped = New-Object System.Drawing.Bitmap $bounds.W, $bounds.H, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($cropped)
$g.DrawImage($srcImg, (New-Object System.Drawing.Rectangle 0, 0, $bounds.W, $bounds.H),
    (New-Object System.Drawing.Rectangle $bounds.X, $bounds.Y, $bounds.W, $bounds.H),
    [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$srcImg.Dispose()

Write-Host "Trimmed content: $($bounds.W)x$($bounds.H)"

$androidOut = Join-Path $mobileRoot 'android\app\src\main\res\drawable\launch_logo.png'
$iosDir = Join-Path $mobileRoot 'ios\Runner\Assets.xcassets\LaunchImage.imageset'

Write-Host 'Writing splash assets:'
Save-ScaledPng $cropped $androidOut $AndroidMaxPx
Save-ScaledPng $cropped (Join-Path $iosDir 'LaunchImage.png') $IosMaxPx1x
Save-ScaledPng $cropped (Join-Path $iosDir 'LaunchImage@2x.png') ($IosMaxPx1x * 2)
Save-ScaledPng $cropped (Join-Path $iosDir 'LaunchImage@3x.png') ($IosMaxPx1x * 3)
$cropped.Dispose()

Write-Host 'Done.'
