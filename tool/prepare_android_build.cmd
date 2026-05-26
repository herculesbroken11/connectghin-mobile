@echo off
setlocal
REM Clears stale Gradle/Dart locks that cause errno 32 on Windows during flutter build.
cd /d "%~dp0.."

echo == Stopping Gradle daemon ==
if exist "android\gradlew.bat" (
  pushd android
  call gradlew.bat --stop 2>nul
  popd
)

echo == Stopping Dart / Java tooling ==
taskkill /F /IM dart.exe 2>nul
taskkill /F /IM dartaotruntime.exe 2>nul
for /f "tokens=2" %%P in ('tasklist /FI "IMAGENAME eq java.exe" /FO LIST ^| findstr /I "PID:"') do (
  taskkill /F /PID %%P 2>nul
)

echo == Removing build caches (with retry) ==
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0remove_build_caches.ps1"

echo == flutter clean ==
call flutter clean

echo == Ready. Run tool\build_install_android.cmd ==
endlocal
