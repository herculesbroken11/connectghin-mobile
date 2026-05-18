@echo off
setlocal
REM Forward emulator TCP 3000 -> host TCP 3000, then run Flutter using 127.0.0.1 on the device
REM (loopback on the device is tunneled to your PC by adb reverse).
REM
REM Requires: Nest API listening on host port 3000, adb in PATH, emulator (or USB device) connected.
REM
REM ApiConfig: .env API_BASE_URL is read BEFORE --dart-define. Your .env uses the same URL as below,
REM so behavior is correct. If you change one, keep them aligned or comment out API_BASE_URL in .env.
REM
REM Usage (from repo root, or run this file from tool\):
REM   tool\run_android_with_adb_reverse.cmd
REM   tool\run_android_with_adb_reverse.cmd emulator-5554   REM first AVD is often 5554
REM   tool\run_android_with_adb_reverse.cmd emulator-5556   REM second AVD / your default

cd /d "%~dp0.."

set "DEVICE=%~1"
if "%DEVICE%"=="" set "DEVICE=emulator-5556"

where adb >nul 2>nul
if errorlevel 1 (
  echo ERROR: adb not in PATH. Add Android SDK platform-tools ^(e.g. ...\Android\Sdk\platform-tools^) to PATH.
  exit /b 1
)

echo == ADB reverse: device %DEVICE% tcp:3000 -^> host tcp:3000 ==
echo.
adb -s "%DEVICE%" reverse tcp:3000 tcp:3000
if errorlevel 1 (
  echo ERROR: adb reverse failed. Run: adb devices
  exit /b 1
)

echo.
adb -s "%DEVICE%" reverse --list
echo.

echo == Flutter: API_BASE_URL=http://127.0.0.1:3000/api/v1 ^(see .env / dart-define precedence^) ==
call flutter run -d "%DEVICE%" --dart-define=API_BASE_URL=http://127.0.0.1:3000/api/v1

endlocal
