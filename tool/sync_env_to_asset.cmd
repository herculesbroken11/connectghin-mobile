@echo off
setlocal
cd /d "%~dp0.."
if not exist ".env" (
  echo ERROR: Missing .env
  exit /b 1
)
if not exist "assets\env" mkdir "assets\env"
(
  echo # Synced from .env
  for /f "usebackq tokens=1,* delims==" %%A in (".env") do (
    if "%%A"=="API_BASE_URL" echo API_BASE_URL=%%B
    if "%%A"=="GOOGLE_SERVER_CLIENT_ID" echo GOOGLE_SERVER_CLIENT_ID=%%B
    if "%%A"=="GOOGLE_PLACES_API_KEY" echo GOOGLE_PLACES_API_KEY=%%B
  )
) > "assets\env\config.env"
echo Wrote assets\env\config.env
endlocal
