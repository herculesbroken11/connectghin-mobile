#!/usr/bin/env bash
# Build a signed iOS IPA for TestFlight. Must run on macOS with Xcode + Flutter.
# Usage: bash tool/build_ios_testflight.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "iOS / TestFlight builds require a Mac with Xcode."
  echo "Copy connectghin-mobile onto a Mac, then run this script there."
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "flutter not found on PATH."
  exit 1
fi

if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "Xcode command line tools not found. Install Xcode from the App Store."
  exit 1
fi

echo "== flutter pub get =="
flutter pub get

echo "== iOS pods =="
cd ios
pod install --repo-update
cd "$ROOT"

echo "== flutter build ipa --release =="
flutter build ipa --release \
  --dart-define=API_BASE_URL=https://api.connectghin.com/api/v1 \
  --dart-define=IAP_MONTHLY_PRODUCT_ID=connectghin_monthly \
  --dart-define=IAP_YEARLY_PRODUCT_ID=connectghin_yearly

IPA="$(find build/ios/ipa -name '*.ipa' | head -n 1)"
if [[ -z "$IPA" ]]; then
  echo "IPA not found. Open ios/Runner.xcworkspace in Xcode, select your Team,"
  echo "enable Sign in with Apple on App ID com.connectghin.app, then archive."
  exit 1
fi

mkdir -p dist
cp "$IPA" dist/ConnectGHIN.ipa
echo ""
echo "IPA ready: $ROOT/dist/ConnectGHIN.ipa"
echo "Upload with Transporter, or: xcrun altool --upload-app --type ios -f dist/ConnectGHIN.ipa --apiKey KEY --apiIssuer ISSUER"
