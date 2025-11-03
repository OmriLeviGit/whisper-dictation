@echo off
REM Start Whisper Transcription Service

echo Starting Whisper transcription service...
echo.

REM Check if Docker is running
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker is not running!
    echo Please start Docker Desktop and try again.
    pause
    exit /b 1
)

REM Build and start the service
echo Building Docker image...
docker-compose build

if %errorlevel% neq 0 (
    echo ERROR: Failed to build Docker image!
    pause
    exit /b 1
)

echo.
echo Starting service...
docker-compose up -d

if %errorlevel% neq 0 (
    echo ERROR: Failed to start service!
    pause
    exit /b 1
)

echo.
echo Whisper service is starting...
echo Waiting for service to be ready (this may take a minute)...
timeout /t 5 /nobreak >nul

REM Wait for health check
set /a count=0
:wait_loop
docker-compose ps | findstr "healthy" >nul 2>&1
if %errorlevel% equ 0 goto service_ready

docker-compose ps | findstr "unhealthy" >nul 2>&1
if %errorlevel% equ 0 (
    echo WARNING: Service is unhealthy. Check logs with: docker-compose logs
)

set /a count+=1
if %count% geq 12 (
    echo WARNING: Service is taking longer than expected to start
    echo Check status with: docker-compose ps
    echo View logs with: docker-compose logs
    goto end
)

timeout /t 5 /nobreak >nul
goto wait_loop

:service_ready
echo.
echo SUCCESS: Whisper service is ready!
echo Service is running on http://localhost:58432
echo.

:end
echo.
echo Commands:
echo   - Check status: docker-compose ps
echo   - View logs: docker-compose logs -f
echo   - Stop service: stop_whisper.bat
echo.
pause
