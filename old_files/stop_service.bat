@echo off
REM ============================================================================
REM Whisper Transcription Service - Stop Script
REM ============================================================================

echo.
echo ===================================
echo Stopping Whisper Service
echo ===================================
echo.

cd /d "%~dp0"

echo Current directory: %CD%
echo.

docker-compose down

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to stop service!
    echo.
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Service stopped successfully!
echo.

pause
