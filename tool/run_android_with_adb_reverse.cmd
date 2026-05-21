@echo off
setlocal
REM Forward emulator TCP 3001 -> host TCP 3001, then run Flutter using 127.0.0.1 on the device
REM (loopback on the device is tunneled to your PC by adb reverse).
REM
REM Requires: Nest API listening on host port 3001, adb in PATH, emulator (or USB device) connected.
REM
REM Google Sign-In: set GOOGLE_SERVER_CLIENT_ID in .env to the OAuth Web client ID.
REM Backend .env must use the same value for GOOGLE_OAUTH_CLIENT_ID.
REM
REM Usage (from repo root, or run this file from tool\):
REM   tool\run_android_with_adb_reverse.cmd
REM   tool\run_android_with_adb_reverse.cmd emulator-5554   REM first AVD is often 5554
REM   tool\run_android_with_adb_reverse.cmd <physical-device-id>

cd /d "%~dp0.."

set "DEVICE=%~1"
set "GOOGLE_SERVER_CLIENT_ID=%GOOGLE_SERVER_CLIENT_ID%"

if exist ".env" (
  for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    if "%%A"=="GOOGLE_SERVER_CLIENT_ID" set "GOOGLE_SERVER_CLIENT_ID=%%B"
  )
)

if "%GOOGLE_SERVER_CLIENT_ID%"=="" (
  echo ERROR: GOOGLE_SERVER_CLIENT_ID is empty.
  echo Set it in connectghin-mobile\.env to your Google OAuth Web client ID.
  exit /b 1
)

where adb >nul 2>nul
if errorlevel 1 (
  echo ERROR: adb not in PATH. Add Android SDK platform-tools ^(e.g. ...\Android\Sdk\platform-tools^) to PATH.
  exit /b 1
)

if "%DEVICE%"=="" (
  for /f "skip=1 tokens=1,2" %%A in ('adb devices') do (
    if "%%B"=="device" (
      set "DEVICE=%%A"
      goto :device_found
    )
  )
)

:device_found
if "%DEVICE%"=="" (
  echo ERROR: No Android device found. Start an emulator or connect a phone with USB debugging enabled.
  echo Run: adb devices
  exit /b 1
)

echo == ADB reverse: device %DEVICE% tcp:3001 -^> host tcp:3001 ==
echo.
adb -s "%DEVICE%" reverse tcp:3001 tcp:3001
if errorlevel 1 (
  echo ERROR: adb reverse failed. Run: adb devices
  exit /b 1
)

echo.
adb -s "%DEVICE%" reverse --list
echo.

echo == Flutter: API_BASE_URL=http://127.0.0.1:3001/api/v1 ==
call flutter run -d "%DEVICE%" --dart-define=API_BASE_URL=http://127.0.0.1:3001/api/v1 --dart-define=GOOGLE_SERVER_CLIENT_ID=%GOOGLE_SERVER_CLIENT_ID%

endlocal
