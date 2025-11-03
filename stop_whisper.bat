@echo off
REM Stop Whisper Transcription Service

echo Stopping Whisper transcription service...
echo.

REM Check if Docker is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo WARNING: Docker is not running!
    echo Service may already be stopped.
    pause
    exit /b 0
)

REM Stop the service
docker-compose down

if %errorlevel% neq 0 (
    echo ERROR: Failed to stop service!
    pause
    exit /b 1
)

echo.
echo SUCCESS: Whisper service stopped.
echo.
pause
