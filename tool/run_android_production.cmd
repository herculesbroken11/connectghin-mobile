@echo off
setlocal
REM Run against production API (https://api.connectghin.com). No adb reverse needed.
REM Reads GOOGLE_SERVER_CLIENT_ID from .env when not passed on the command line.
REM
REM Usage:
REM   tool\run_android_production.cmd
REM   tool\run_android_production.cmd emulator-5556
REM   tool\run_android_production.cmd emulator-5556 --no-clean
REM LDPlayer: adb id emulator-5556 = Flutter id emulator-5556 (name may show as 2304FPN6DG).

cd /d "%~dp0.."

if /I not "%~2"=="--no-clean" (
  echo == Prepare build (fixes Windows file-lock errno 32) ==
  call "%~dp0prepare_android_build.cmd"
  echo.
)

echo == Sync .env -^> lib/generated/app_env.dart ==
call "%~dp0sync_env_to_asset.cmd"
if errorlevel 1 exit /b 1
echo.

set "DEVICE=%~1"
set "GOOGLE_SERVER_CLIENT_ID=%GOOGLE_SERVER_CLIENT_ID%"
set "GOOGLE_PLACES_API_KEY=%GOOGLE_PLACES_API_KEY%"
set "PLACES_DEFINE="

if exist ".env" (
  for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    if "%%A"=="GOOGLE_SERVER_CLIENT_ID" set "GOOGLE_SERVER_CLIENT_ID=%%B"
    if "%%A"=="GOOGLE_PLACES_API_KEY" set "GOOGLE_PLACES_API_KEY=%%B"
  )
)
if not "%GOOGLE_PLACES_API_KEY%"=="" set "PLACES_DEFINE=--dart-define=GOOGLE_PLACES_API_KEY=%GOOGLE_PLACES_API_KEY%"

if "%GOOGLE_SERVER_CLIENT_ID%"=="" (
  echo ERROR: GOOGLE_SERVER_CLIENT_ID is empty.
  echo Set it in connectghin-mobile\.env
  exit /b 1
)

if "%DEVICE%"=="" (
  for /f "skip=1 tokens=1,2" %%A in ('adb devices 2^>nul') do (
    if "%%B"=="device" (
      set "DEVICE=%%A"
      goto :device_found
    )
  )
)

:device_found
if "%DEVICE%"=="" (
  echo ERROR: No Android device. Run: adb devices
  exit /b 1
)

echo == Production API: https://api.connectghin.com/api/v1 on %DEVICE% ==
echo == Flutter may display LDPlayer as 2304FPN6DG - same device if only one adb device ==
echo == If errno 32 persists, close Cursor and run: tool\build_install_android.cmd "%DEVICE%" ==
call flutter run -d "%DEVICE%" ^
  --dart-define=API_BASE_URL=https://api.connectghin.com/api/v1 ^
  --dart-define=GOOGLE_SERVER_CLIENT_ID=%GOOGLE_SERVER_CLIENT_ID% ^
  %PLACES_DEFINE%

endlocal
