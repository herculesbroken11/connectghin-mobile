# ConnectGHIN Flutter

## Setup

1. Install dependencies:
   - `flutter pub get`
2. Choose `API_BASE_URL` for your runtime target:
   - Android emulator: `http://10.0.2.2:3001/api/v1`
   - Android emulator or USB phone with `adb reverse`: `http://127.0.0.1:3001/api/v1`
   - iOS simulator / desktop: `http://localhost:3001/api/v1`
   - Physical device over Wi-Fi/LAN: `http://<YOUR_LAN_IP>:3001/api/v1`
   - Production: `https://api.connectghin.com/api/v1`
3. Configure Google Sign-In:
   - Set `GOOGLE_SERVER_CLIENT_ID` to the Google OAuth **Web client ID**.
   - Set the backend `GOOGLE_OAUTH_CLIENT_ID` to the same value.
   - In Google Cloud Console, also create an Android OAuth client for package `com.connectghin.app` using the debug SHA-1 from `cd android && ./gradlew signingReport`.
4. Copy `.env.example` to `.env`, then run `tool\sync_env_to_asset.cmd` (writes `assets/env/config.env` for the app). Or use `tool\run_android_production.cmd` which syncs automatically.
5. Run app:
   - Production: `tool\run_android_production.cmd` or `flutter run` with production URL in `.env`
   - Local emulator/USB: `tool\run_android_with_adb_reverse.cmd`
   - Wi-Fi/LAN phone: `tool\run_android_lan.cmd <YOUR_LAN_IP>`

## Android Emulator And Phone Testing

Use debug/profile builds for local HTTP API testing. These build types allow cleartext traffic so emulator and physical phone can reach your local Nest backend. Release builds keep cleartext disabled and should use HTTPS.

Recommended local flow:

1. Start backend on the PC: `npm run start:dev` in `connectghin-server/backend`.
2. Confirm backend port is `3001`.
3. Put the Google OAuth Web client ID in `connectghin-mobile/.env` as `GOOGLE_SERVER_CLIENT_ID`.
4. Put the same value in `connectghin-server/backend/.env` as `GOOGLE_OAUTH_CLIENT_ID`.
5. For emulator or a USB-connected real phone, run `tool\run_android_with_adb_reverse.cmd`.
6. For a real phone over Wi-Fi/LAN, run `tool\run_android_lan.cmd <YOUR_PC_LAN_IP>`.

Google Sign-In requires a Google Play services emulator image or a real Android phone with Google Play services.

## Environment Resolution

`ApiConfig.baseUrl` resolves in this order:

1. `--dart-define=API_BASE_URL=...`
2. Optional local `.env` (`API_BASE_URL`)
3. Fallback default: `http://10.0.2.2:3001/api/v1`

`GOOGLE_SERVER_CLIENT_ID` resolves from `--dart-define` first, then `.env` (must be in `pubspec.yaml` assets). Helpers `run_android_production.cmd` / `run_android_with_adb_reverse.cmd` pass the dart-define from `.env`.

Use `--dart-define` for release builds so the APK points at the intended backend:

- `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3001/api/v1 --dart-define=GOOGLE_SERVER_CLIENT_ID=<WEB_CLIENT_ID>`
- `flutter build apk --release --dart-define=API_BASE_URL=https://api.connectghin.com/api/v1 --dart-define=GOOGLE_SERVER_CLIENT_ID=<WEB_CLIENT_ID>`

## Android Release Signing

1. Create a release keystore outside Git.
2. Copy `android/key.properties.example` to `android/key.properties`.
3. Fill in `storePassword`, `keyPassword`, `keyAlias`, and `storeFile`.
4. Build with:
   - `flutter build apk --release --dart-define=API_BASE_URL=https://api.connectghin.com/api/v1`

## Backend Requirement

The backend should be running at the configured URL:

- Base API: `/api/v1`
- Realtime chat namespace: `/chat`
