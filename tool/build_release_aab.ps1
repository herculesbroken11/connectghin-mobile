# Builds a signed release AAB for Google Play Console (Internal Testing / Production).
# Output: dist\connectghin-release-<timestamp>.aab and dist\ConnectGHIN.aab
# Usage: powershell -File tool\build_release_aab.ps1

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
    "GOOGLE_SERVER_CLIENT_ID=$googleId",
    "IAP_MONTHLY_PRODUCT_ID=connectghin_monthly",
    "IAP_YEARLY_PRODUCT_ID=connectghin_yearly"
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
    Write-Host '== flutter build appbundle --release =='
    & flutter build appbundle --release @defineArgs
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

$aab = Join-Path $dst 'build\app\outputs\bundle\release\app-release.aab'
if (-not (Test-Path $aab)) {
    Write-Error "AAB not found at $aab"
}

New-Item -ItemType Directory -Force -Path $distDir | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd-HHmm'
$outName = "connectghin-release-$stamp.aab"
$outPath = Join-Path $distDir $outName
$playAab = Join-Path $distDir 'ConnectGHIN.aab'
Copy-Item -LiteralPath $aab -Destination $outPath -Force
Copy-Item -LiteralPath $aab -Destination $playAab -Force
Copy-Item -LiteralPath $aab -Destination (Join-Path $distDir 'connectghin-release-latest.aab') -Force

$workspaceAab = Join-Path $mobileRoot 'build\app\outputs\bundle\release\app-release.aab'
$workspaceBuildDir = Split-Path $workspaceAab -Parent
New-Item -ItemType Directory -Force -Path $workspaceBuildDir | Out-Null
Copy-Item -LiteralPath $aab -Destination $workspaceAab -Force -ErrorAction SilentlyContinue

$sha1 = $null
$keytool = Get-Command keytool -ErrorAction SilentlyContinue
$ks = Join-Path $mobileRoot 'android\upload-keystore.jks'
if ($keytool -and (Test-Path $ks)) {
    $out = & keytool -list -v -keystore $ks -alias connectghin -storepass change-me 2>&1 | Out-String
    if ($out -match 'SHA1:\s*([0-9A-F:]+)') { $sha1 = $Matches[1] }
}

$uploadTxt = @"
ConnectGHIN — upload to Google Play Console (Internal Testing)

1. Open Google Play Console → ConnectGHIN app.
2. Testing → Internal testing → Create new release.
3. Upload: dist\ConnectGHIN.aab
4. Add release notes and save → Review release → Start rollout.

Package name: com.connectghin.app
Version: see pubspec.yaml (versionName + versionCode)

After first upload, create subscriptions in Play Console:
- connectghin_monthly
- connectghin_yearly

If Google Sign-In works on a sideloaded APK but FAILS after installing from Play Store:
  Play App Signing resigns the app. Add the Play Console "App signing key certificate"
  SHA-1 (Setup → App integrity → App signing) to Firebase for com.connectghin.app.
  Keep the upload-key SHA-1 registered as well for local release APKs.

Upload keystore SHA-1 (local release / sideload APK only):
$sha1
"@
Set-Content -Path (Join-Path $distDir 'PLAY_UPLOAD.txt') -Value $uploadTxt -Encoding UTF8

Write-Host ''
Write-Host 'Release AAB ready for Google Play Internal Testing.'
Write-Host "  Upload this file: $playAab"
Write-Host "  Also:            $outPath"
Write-Host "  Instructions:    $(Join-Path $distDir 'PLAY_UPLOAD.txt')"
if (Test-Path $workspaceAab) {
    Write-Host "  Workspace:       $workspaceAab"
}
Write-Host ''
Write-Host 'API: https://api.connectghin.com/api/v1'
if ($sha1) { Write-Host "Release SHA-1 (Firebase): $sha1" }
