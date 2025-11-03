@echo off
REM ============================================================================
REM Whisper Transcription Service - View Logs
REM ============================================================================

echo.
echo ===================================
echo Whisper Service Logs
echo ===================================
echo.
echo Press Ctrl+C to exit
echo.

cd /d "%~dp0"

docker-compose logs -f
