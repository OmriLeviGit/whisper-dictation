@echo off
REM ============================================================================
REM Whisper Transcription Service - Quick Start Script
REM ============================================================================

echo.
echo ===================================
echo Whisper Transcription Service
echo ===================================
echo.

cd /d "%~dp0"

echo Current directory: %CD%
echo.

REM Check if Docker is running
docker info >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Docker is not running!
    echo Please start Docker Desktop and try again.
    echo.
    pause
    exit /b 1
)

echo [OK] Docker is running
echo.

REM Start the service
echo Starting Whisper transcription service...
docker-compose up -d

if errorlevel 1 (
    echo.
    echo [ERROR] Failed to start service!
    echo Check the logs with: docker-compose logs
    echo.
    pause
    exit /b 1
)

echo.
echo [SUCCESS] Service started successfully!
echo.
echo Waiting for service to be ready...
timeout /t 5 /nobreak >nul

REM Check health
curl -s http://localhost:58231/health >nul 2>&1
if errorlevel 1 (
    echo.
    echo [WARNING] Service is starting but not ready yet.
    echo This is normal on first run (model download takes 5-10 minutes).
    echo.
    echo Check status with: docker-compose logs -f
) else (
    echo.
    echo [OK] Service is healthy and ready!
    echo.
    echo Service URL: http://localhost:58231
    echo API docs: http://localhost:58231/docs
)

echo.
echo ===================================
echo Useful Commands:
echo ===================================
echo Stop service:    docker-compose down
echo View logs:       docker-compose logs -f
echo Restart service: docker-compose restart
echo Check status:    docker-compose ps
echo ===================================
echo.

pause
