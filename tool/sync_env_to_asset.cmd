@echo off
setlocal
cd /d "%~dp0.."
if not exist ".env" (
  echo ERROR: Missing .env
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0sync_env_to_asset.ps1"
if errorlevel 1 exit /b 1
echo Sync complete: lib/generated/app_env.dart
endlocal
