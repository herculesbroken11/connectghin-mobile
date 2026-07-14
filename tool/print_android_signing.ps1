# Prints SHA-1/SHA-256 for Firebase / Google Cloud OAuth.
# IMPORTANT: Play Store installs use Play App Signing — that SHA-1 is DIFFERENT from this upload keystore.
# For Play-installed builds failing Google Sign-In:
#   Play Console → App integrity → App signing → App signing key certificate → SHA-1
#   Add BOTH that SHA-1 and this upload SHA-1 in Firebase for com.connectghin.app
$mobileRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ks = Join-Path $mobileRoot 'android\upload-keystore.jks'
if (-not (Test-Path $ks)) {
    Write-Host 'No android\upload-keystore.jks — build script creates one on first release build.'
    exit 1
}
Write-Host 'Package: com.connectghin.app'
Write-Host 'Upload keystore: android\upload-keystore.jks (alias connectghin)'
Write-Host ''
& keytool -list -v -keystore $ks -alias connectghin -storepass change-me 2>&1 | Select-String -Pattern 'SHA1:|SHA256:'
Write-Host ''
Write-Host 'Add BOTH SHA-1 fingerprints in Firebase: Project connectghin-6e881 -> Project settings -> Your apps -> Android'
Write-Host '1) Upload key SHA-1 (printed above) - for sideloaded release APKs'
Write-Host '2) Play App Signing SHA-1 from Play Console -> App integrity -> App signing - for Play Store installs'
Write-Host 'Then wait a few minutes and update/reinstall the app from Play'
