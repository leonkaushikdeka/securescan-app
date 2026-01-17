@echo off
echo ============================================
echo       SecureScan App Builder
echo ============================================
echo.

cd /d "%~dp0"
echo Working directory: %CD%
echo.

echo Step 1: Cleaning previous build...
call D:\src\flutter\bin\flutter.bat clean
echo.

echo Step 2: Getting dependencies...
call D:\src\flutter\bin\flutter.bat pub get
echo.

echo Step 3: Building APK...
call D:\src\flutter\bin\flutter.bat build apk --debug
echo.

echo Step 4: Build complete!
echo.
echo APK location:
echo D:\securescanapp_new\build\app\outputs\apk\debug\app-debug.apk
echo.
pause
