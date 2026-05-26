# Builds APK in %TEMP% to avoid Windows errno 32 file locks on the IDE workspace.
# Usage: powershell -File tool\build_install_android.ps1 [-Device emulator-5556] [-NoClean]

param(
    [string]$Device = '',
    [switch]$NoClean
)

$ErrorActionPreference = 'Stop'
$src = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$dst = Join-Path $env:TEMP 'connectghin_mobile_build'

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

function Remove-DirRobust([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return }

    for ($i = 1; $i -le 4; $i++) {
        try {
            Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
            return
        } catch {
            Start-Sleep -Milliseconds (250 * $i)
        }
    }

    # Robocopy mirror from an empty folder clears deep Gradle trees (long paths, $ in .dex names).
    $empty = Join-Path $env:TEMP ("connectghin_empty_{0}" -f [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $empty -Force | Out-Null
    try {
        & robocopy.exe $empty $path /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
        Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
    } finally {
        Remove-Item -LiteralPath $empty -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (-not (Test-Path -LiteralPath $path)) { return }

    # Leave a stale tree behind instead of failing the build.
    $parent = Split-Path -Parent $path
    $staleName = '{0}.stale.{1}' -f (Split-Path -Leaf $path), [DateTime]::UtcNow.Ticks
    $stalePath = Join-Path $parent $staleName
    try {
        Rename-Item -LiteralPath $path -NewName $staleName -ErrorAction Stop
        Write-Host "Note: could not delete $path ; renamed to $stalePath"
    } catch {
        Write-Warning "Could not clear temp build folder $path ($_). Build may reuse or overwrite files."
    }
}

if (-not $NoClean) {
    Write-Host '== prepare_android_build =='
    & (Join-Path $PSScriptRoot 'prepare_android_build.cmd')
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

Write-Host '== Sync .env =='
& (Join-Path $PSScriptRoot 'sync_env_to_asset.cmd')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

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

if ([string]::IsNullOrWhiteSpace($Device)) {
    $adbLines = & adb devices 2>$null
    foreach ($line in $adbLines) {
        if ($line -match '^(?<id>\S+)\s+device\s*$') {
            $Device = $Matches['id']
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($Device)) {
    Write-Error 'No adb device. Start LDPlayer and run: adb devices'
}

Write-Host "== Copy sources to $dst (avoids Cursor/Gradle locks on workspace) =="
if ($NoClean) {
    if (-not (Test-Path -LiteralPath $dst)) {
        New-Item -ItemType Directory -Path $dst -Force | Out-Null
    } else {
        Write-Host '== --no-clean: keeping existing temp build tree =='
    }
} else {
    Remove-DirRobust $dst
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
}

$robocopyExit = 0
& robocopy.exe $src $dst /MIR /NFL /NDL /NJH /NJS /nc /ns /np `
    /XD build .dart_tool .git android\.gradle android\app\build ios
$robocopyExit = $LASTEXITCODE
if ($robocopyExit -ge 8) {
    Write-Error "robocopy failed with exit code $robocopyExit"
}

Push-Location $dst
try {
    Write-Host '== flutter pub get (temp build tree) =='
    & flutter pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    $defineArgs = foreach ($d in $dartDefines) { '--dart-define', $d }
    Write-Host "== flutter build apk --debug (device $Device) =="
    & flutter build apk --debug @defineArgs
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host 'BUILD FAILED. Close Cursor terminals, run tool\prepare_android_build.cmd,'
        Write-Host 'add Windows Defender exclusion for the project folder, then retry.'
        exit $LASTEXITCODE
    }
} finally {
    Pop-Location
}

$apk = Join-Path $dst 'build\app\outputs\flutter-apk\app-debug.apk'
if (-not (Test-Path $apk)) {
    Write-Error "APK not found at $apk"
}

Write-Host '== adb install -r =='
& adb -s $Device install -r $apk
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host '== Launch app =='
& adb -s $Device shell am start -n com.connectghin.app/com.connectghin.app.MainActivity
Write-Host ''
Write-Host "Installed on $Device from temp build. For hot reload: flutter attach -d $Device"
