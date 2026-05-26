# Builds a release APK for sideload / production API testing.
# Output: build\app\outputs\flutter-apk\app-release.apk (and copy under dist\)
# Usage: powershell -File tool\build_release_apk.ps1

$ErrorActionPreference = 'Stop'
$mobileRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$src = $mobileRoot
$dst = Join-Path $env:TEMP 'connectghin_mobile_build'
$distDir = Join-Path $mobileRoot 'dist'

function Read-DotEnvKey([string]$key) {
    $envPath = Join-Path $src '.env'
    if (-not (Test-Path $envPath)) { return $null }
    foreach ($line in Get-Content $envPath) {
        $t = $line.Trim()
        if ($t.StartsWith('#') -or -not $t.Contains('=')) { continue }
        $parts = $t.Split('=', 2)
        if ($parts[0].Trim() -eq $key) { return $parts[1].Trim() }
    }
    return $null
}

function Ensure-ReleaseSigning {
    $keyProps = Join-Path $mobileRoot 'android\key.properties'
    $keystore = Join-Path $mobileRoot 'android\upload-keystore.jks'
    if ((Test-Path $keyProps) -and (Test-Path $keystore)) {
        Write-Host 'Release signing: using android\key.properties'
        return
    }
    Write-Host 'Creating local test release keystore (android\upload-keystore.jks, gitignored)...'
    $keytool = Get-Command keytool -ErrorAction SilentlyContinue
    if (-not $keytool) {
        throw 'keytool not found. Install JDK or create android/key.properties and upload-keystore.jks manually.'
    }
    & keytool -genkeypair -v `
        -keystore $keystore `
        -alias connectghin `
        -keyalg RSA -keysize 2048 -validity 10000 `
        -storepass change-me -keypass change-me `
        -dname 'CN=ConnectGHIN, OU=Mobile, O=ConnectGHIN, L=Local, ST=NA, C=US'
    if ($LASTEXITCODE -ne 0) { throw 'keytool failed' }
  Copy-Item (Join-Path $mobileRoot 'android\key.properties.example') $keyProps -Force
}

Write-Host '== Sync .env to app_env.dart =='
& (Join-Path $PSScriptRoot 'sync_env_to_asset.cmd')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Ensure-ReleaseSigning

$googleId = Read-DotEnvKey 'GOOGLE_SERVER_CLIENT_ID'
if ([string]::IsNullOrWhiteSpace($googleId)) {
    Write-Error 'GOOGLE_SERVER_CLIENT_ID missing in .env'
}
$placesKey = Read-DotEnvKey 'GOOGLE_PLACES_API_KEY'
$dartDefines = @(
    "API_BASE_URL=https://api.connectghin.com/api/v1",
    "GOOGLE_SERVER_CLIENT_ID=$googleId"
)
if (-not [string]::IsNullOrWhiteSpace($placesKey)) {
    $dartDefines += "GOOGLE_PLACES_API_KEY=$placesKey"
}

Write-Host "== Copy sources to $dst =="
if (Test-Path $dst) {
    & robocopy.exe $src $dst /MIR /NFL /NDL /NJH /NJS /nc /ns /np `
        /XD build .dart_tool .git android\.gradle android\app\build ios dist | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
} else {
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    & robocopy.exe $src $dst /E /NFL /NDL /NJH /NJS /nc /ns /np `
        /XD build .dart_tool .git android\.gradle android\app\build ios dist | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed with exit code $LASTEXITCODE" }
}

Push-Location $dst
try {
    Write-Host '== flutter pub get =='
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $defineArgs = foreach ($d in $dartDefines) { '--dart-define', $d }
    # Single universal APK (arm + x86) — copy to phone and tap; no adb required.
    Write-Host '== flutter build apk --release (universal) =='
    & flutter build apk --release @defineArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

$apk = Join-Path $dst 'build\app\outputs\flutter-apk\app-release.apk'
if (-not (Test-Path $apk)) {
    Write-Error "APK not found at $apk"
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$outName = "connectghin-release-$stamp.apk"
$outPath = Join-Path $distDir $outName
Copy-Item -LiteralPath $apk -Destination $outPath -Force

# Also copy into workspace build folder when possible.
$workspaceApk = Join-Path $mobileRoot 'build\app\outputs\flutter-apk\app-release.apk'
$workspaceBuildDir = Split-Path $workspaceApk -Parent
New-Item -ItemType Directory -Force -Path $workspaceBuildDir | Out-Null
Copy-Item -LiteralPath $apk -Destination $workspaceApk -Force -ErrorAction SilentlyContinue
$phoneApk = Join-Path $distDir 'ConnectGHIN.apk'
Copy-Item -LiteralPath $apk -Destination (Join-Path $distDir 'connectghin-release-latest.apk') -Force
Copy-Item -LiteralPath $apk -Destination $phoneApk -Force

$sha1 = $null
$keytool = Get-Command keytool -ErrorAction SilentlyContinue
$ks = Join-Path $mobileRoot 'android\upload-keystore.jks'
if ($keytool -and (Test-Path $ks)) {
    $out = & keytool -list -v -keystore $ks -alias connectghin -storepass change-me 2>&1 | Out-String
    if ($out -match 'SHA1:\s*([0-9A-F:]+)') { $sha1 = $Matches[1] }
}

$installTxt = @"
ConnectGHIN — install on a real phone (no PC / no adb)

1. Copy ConnectGHIN.apk to your phone (USB, email, Drive, WhatsApp, etc.).
2. Open Files or Downloads and tap ConnectGHIN.apk.
3. If asked, allow install from this app (unknown sources).
4. Tap Install, then Open ConnectGHIN.

Requires: internet (uses https://api.connectghin.com).

If install says signatures do not match: uninstall old ConnectGHIN first (Settings → Apps).

If Google sign-in fails on this APK, add this release SHA-1 in Firebase Console
(Project connectghin-6e881 → Project settings → Your apps → Android → Add fingerprint):
$sha1
"@
Set-Content -Path (Join-Path $distDir 'INSTALL.txt') -Value $installTxt -Encoding UTF8

Write-Host ''
Write-Host 'Release APK ready for real phones (tap to install, no adb).'
Write-Host "  Send this file: $phoneApk"
Write-Host "  Also:         $outPath"
Write-Host "  Instructions: $(Join-Path $distDir 'INSTALL.txt')"
if (Test-Path $workspaceApk) {
    Write-Host "  Workspace:    $workspaceApk"
}
Write-Host ''
Write-Host 'API: https://api.connectghin.com/api/v1'
if ($sha1) { Write-Host "Release SHA-1 (Firebase): $sha1" }
