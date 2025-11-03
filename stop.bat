@echo off
REM Stop Whisper Dictation
echo Stopping Whisper Dictation...
echo.

REM Kill AutoHotkey process
echo Stopping dictation hotkey...
taskkill /F /IM AutoHotkey64.exe >nul 2>&1
if %errorlevel% equ 0 (
    echo AutoHotkey stopped.
) else (
    echo AutoHotkey was not running.
)

REM Stop Docker service
echo Stopping Whisper service...
cd docker
docker-compose down
cd ..

echo.
echo Whisper Dictation stopped.
echo.
pause
