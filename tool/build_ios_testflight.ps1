# iOS / TestFlight IPA cannot be built on Windows.
# Copy connectghin-mobile to a Mac with Xcode, then run:
#   bash tool/build_ios_testflight.sh

$ErrorActionPreference = 'Stop'
Write-Host 'iOS TestFlight builds require macOS + Xcode. This Windows machine cannot produce an IPA.'
Write-Host ''
Write-Host 'On a Mac:'
Write-Host '  1. Open connectghin-mobile/ios/Runner.xcworkspace in Xcode'
Write-Host '  2. Signing & Capabilities: Team + bundle ID com.connectghin.app'
Write-Host '  3. Confirm Sign in with Apple capability is present'
Write-Host '  4. bash tool/build_ios_testflight.sh'
Write-Host '  5. Upload dist/ConnectGHIN.ipa with Transporter to App Store Connect / TestFlight'
exit 1
