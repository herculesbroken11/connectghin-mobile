# Prints SHA-1/SHA-256 for Firebase / Google Cloud OAuth (release APK signing key).
$mobileRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ks = Join-Path $mobileRoot 'android\upload-keystore.jks'
if (-not (Test-Path $ks)) {
    Write-Host 'No android\upload-keystore.jks — build script creates one on first release build.'
    exit 1
}
Write-Host 'Package: com.connectghin.app'
Write-Host 'Keystore: android\upload-keystore.jks (alias connectghin)'
Write-Host ''
& keytool -list -v -keystore $ks -alias connectghin -storepass change-me 2>&1 | Select-String -Pattern 'SHA1:|SHA256:'
Write-Host ''
Write-Host 'Add SHA-1 in Firebase: Project connectghin-6e881 → Project settings → Your apps → Android'
Write-Host 'Or Google Cloud: APIs & Credentials → OAuth 2.0 Client IDs → Android client'
Write-Host 'Then download google-services.json OR wait a few minutes and reinstall ConnectGHIN.apk'
