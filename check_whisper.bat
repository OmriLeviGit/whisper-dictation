@echo off
REM Check Whisper Transcription Service Status

echo Checking Whisper transcription service status...
echo.

REM Check if Docker is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker is not running!
    echo Please start Docker Desktop.
    pause
    exit /b 1
)

REM Check service status
echo Docker Containers:
echo ==================
docker-compose ps
echo.

REM Check if container is running
docker-compose ps | findstr "whisper-service" | findstr "Up" >nul 2>&1
if %errorlevel% neq 0 (
    echo STATUS: Service is NOT running
    echo Run 'start_whisper.bat' to start the service.
) else (
    echo STATUS: Service is running
    echo.

    REM Check health
    docker-compose ps | findstr "healthy" >nul 2>&1
    if %errorlevel% equ 0 (
        echo HEALTH: Healthy - Service is ready!
    ) else (
        docker-compose ps | findstr "unhealthy" >nul 2>&1
        if %errorlevel% equ 0 (
            echo HEALTH: Unhealthy - Service has issues
            echo Check logs with: docker-compose logs
        ) else (
            echo HEALTH: Starting up - Wait a moment and check again
        )
    )

    echo.
    echo Service URL: http://localhost:58432
    echo API Docs: http://localhost:58432/docs
)

echo.
echo Commands:
echo   - View logs: docker-compose logs -f
echo   - Restart: docker-compose restart
echo   - Stop: stop_whisper.bat
echo.
pause
