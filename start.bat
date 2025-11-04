@echo off
REM Start Whisper Dictation
echo Starting Whisper Dictation...
echo.

REM Sync Python dependencies (fast with uv)
echo [1/3] Syncing Python dependencies...
uv sync >NUL 2>&1
if %errorlevel% neq 0 (
    echo Warning: Failed to sync dependencies, continuing anyway...
)
echo.

REM Check if Docker is running (retry up to 3 times)
echo [2/3] Checking Docker...
set /a retries=0
:check_docker
docker info >NUL 2>&1
if %errorlevel% equ 0 goto docker_ready

set /a retries+=1
if %retries% geq 3 (
    echo ERROR: Docker is not running!
    echo Please start Docker Desktop and try again.
    pause
    exit /b 1
)

echo Docker not ready, waiting 20 seconds... (attempt %retries%/3)
timeout /t 20 /nobreak >NUL
goto check_docker

:docker_ready
echo Docker is running.
echo.

REM Start Whisper service (rebuilds only if needed)
echo [3/3] Starting Whisper service...
docker-compose -f docker/docker-compose.yml --env-file config/service.env ps 2>NUL | findstr "whisper-service" 2>NUL | findstr "Up" >NUL 2>&1
if %errorlevel% neq 0 (
    docker-compose -f docker/docker-compose.yml --env-file config/service.env up -d --build
    timeout /t 5 /nobreak >NUL
) else (
    echo Service already running, checking for updates...
    docker-compose -f docker/docker-compose.yml --env-file config/service.env up -d --build
)

echo.
echo Starting dictation hotkey...
start "" "scripts\hold_to_record.ahk"

echo.
echo Whisper Dictation is now active!
echo Check your system tray for the hotkey details.
echo.
