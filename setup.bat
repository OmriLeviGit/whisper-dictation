@echo off
REM One-time setup for Whisper Dictation
echo ========================================
echo    Whisper Dictation - Initial Setup
echo ========================================
echo.

REM Sync Python dependencies
echo [1/3] Syncing Python dependencies...
uv sync >\\.\NUL 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Failed to sync Python dependencies!
    echo Please install uv and try again.
    pause
    exit /b 1
)
echo Done.
echo.

REM Check if Docker is running (retry up to 4 times)
echo [2/3] Checking Docker...
set /a retries=0
:check_docker
docker info >\\.\NUL 2>&1
if %errorlevel% equ 0 goto docker_ready

set /a retries+=1
if %retries% geq 4 (
    echo ERROR: Docker is not running!
    echo Please start Docker Desktop and try again.
    pause
    exit /b 1
)

echo Docker not ready, waiting 60 seconds... (retry %retries%/3)
timeout /t 60 /nobreak >\\.\NUL 2>&1
goto check_docker

:docker_ready
echo Docker is running.
echo.

REM Build and start Whisper service
echo [3/3] Building and starting Whisper service...
echo This may take a few minutes on first run...
docker-compose -f docker/docker-compose.yml --env-file config/service.env up -d --build
if %errorlevel% neq 0 (
    echo ERROR: Failed to start Docker service!
    pause
    exit /b 1
)
echo.

REM Wait for service to be ready
echo Waiting for service to be healthy...
timeout /t 10 /nobreak >\\.\NUL 2>&1
echo.

echo ========================================
echo    Setup Complete!
echo ========================================
echo.
echo Next steps:
echo   1. Run 'start.bat' to activate the dictation hotkey
echo   2. Check config/client.env to customize settings
echo   3. Check config/service.env to change Whisper model
echo.
echo The Docker container will auto-start on system reboot.
echo.
pause
