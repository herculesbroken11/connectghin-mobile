@echo off
setlocal
REM Build APK in %%TEMP%% (avoids Windows errno 32 locks), then install to adb device.
REM Usage: tool\build_install_android.cmd [device-id] [--no-clean]
REM Example: tool\build_install_android.cmd emulator-5556

cd /d "%~dp0.."

set "DEVICE=%~1"
set "EXTRA="
if /I "%~2"=="--no-clean" set "EXTRA=-NoClean"
if /I "%~1"=="--no-clean" (
  set "DEVICE="
  set "EXTRA=-NoClean"
)

set "PS_ARGS=-ExecutionPolicy Bypass -File "%~dp0build_install_android.ps1""
if not "%DEVICE%"=="" set "PS_ARGS=%PS_ARGS% -Device %DEVICE%"
if not "%EXTRA%"=="" set "PS_ARGS=%PS_ARGS% %EXTRA%"

powershell -NoProfile %PS_ARGS%
exit /b %ERRORLEVEL%
