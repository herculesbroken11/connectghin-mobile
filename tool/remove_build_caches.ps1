param([string]$Root = (Split-Path -Parent $PSScriptRoot))

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
    $empty = Join-Path $env:TEMP ("connectghin_empty_{0}" -f [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Path $empty -Force | Out-Null
    try {
        & robocopy.exe $empty $path /MIR /R:1 /W:1 /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
        Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction SilentlyContinue
    } finally {
        Remove-Item -LiteralPath $empty -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $path) {
        Write-Warning "Could not remove $path"
    }
}

Remove-DirRobust (Join-Path $Root 'build')
Remove-DirRobust (Join-Path $Root '.dart_tool\flutter_build')
Remove-DirRobust (Join-Path $env:TEMP 'connectghin_mobile_build')
