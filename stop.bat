@echo off
REM Stop Whisper Dictation
echo Stopping Whisper Dictation...
echo.

REM Kill AutoHotkey process
echo Stopping dictation hotkey...
taskkill /F /IM AutoHotkey64.exe >\\.\NUL 2>&1
if %errorlevel% equ 0 (
    echo AutoHotkey stopped.
) else (
    echo AutoHotkey was not running.
)

REM Stop Docker service
echo Stopping Whisper service...
docker-compose -f docker/docker-compose.yml --env-file config/service.env down

echo.
echo Whisper Dictation stopped.
echo.
pause
