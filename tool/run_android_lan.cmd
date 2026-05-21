@echo off
setlocal
REM Run on a physical Android phone over Wi-Fi/LAN.
REM Phone and PC must be on the same network, and the backend must listen on the PC LAN IP.
REM
REM Usage:
REM   tool\run_android_lan.cmd 192.168.1.10
REM   tool\run_android_lan.cmd 192.168.1.10 <device-id>

cd /d "%~dp0.."

set "HOST_IP=%~1"
set "DEVICE=%~2"
set "GOOGLE_SERVER_CLIENT_ID=%GOOGLE_SERVER_CLIENT_ID%"

if "%HOST_IP%"=="" (
  echo ERROR: Missing PC LAN IP.
  echo Example: tool\run_android_lan.cmd 192.168.1.10
  exit /b 1
)

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
  echo ERROR: No Android phone found. Enable USB debugging and run: adb devices
  exit /b 1
)

echo == Flutter: API_BASE_URL=http://%HOST_IP%:3001/api/v1 on %DEVICE% ==
call flutter run -d "%DEVICE%" --dart-define=API_BASE_URL=http://%HOST_IP%:3001/api/v1 --dart-define=GOOGLE_SERVER_CLIENT_ID=%GOOGLE_SERVER_CLIENT_ID%

endlocal
