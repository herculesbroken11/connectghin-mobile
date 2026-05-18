# ConnectGHIN Flutter

## Setup

1. Install dependencies:
   - `flutter pub get`
2. Create local env:
   - Copy `.env.example` to `.env`
3. Set `API_BASE_URL` in `.env` for your runtime target:
   - Android emulator: `http://10.0.2.2:3000/api/v1`
   - iOS simulator / desktop: `http://localhost:3000/api/v1`
   - Physical device: `http://<YOUR_LAN_IP>:3000/api/v1`
4. Run app:
   - `flutter run`

## Environment Resolution

`ApiConfig.baseUrl` resolves in this order:

1. `.env` (`API_BASE_URL`)
2. `--dart-define=API_BASE_URL=...`
3. Fallback default: `http://10.0.2.2:3000/api/v1`

This means you can use `.env` for local defaults and still override per run:

- `flutter run --dart-define=API_BASE_URL=http://192.168.1.10:3000/api/v1`

## Backend Requirement

The backend should be running at the configured URL:

- Base API: `/api/v1`
- Realtime chat namespace: `/chat`
