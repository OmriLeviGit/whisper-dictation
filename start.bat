@echo off
REM Start Whisper Dictation (assumes already set up)
echo Starting Whisper Dictation...
echo.

REM Check if Docker is running (retry up to 3 times)
set /a retries=0
:check_docker
docker info >nul 2>&1
if %errorlevel% equ 0 goto docker_ready

set /a retries+=1
if %retries% geq 3 (
    REM Docker not available after 3 retries, exit silently
    exit /b 1
)

echo Docker not ready, waiting 10 seconds... (attempt %retries%/3)
timeout /t 10 /nobreak >nul
goto check_docker

:docker_ready

REM Start Whisper service if not already running
cd docker
docker-compose ps | findstr "whisper-service" | findstr "Up" >nul 2>&1
if %errorlevel% neq 0 (
    echo Starting Whisper service...
    docker-compose up -d
    timeout /t 5 /nobreak >nul
) else (
    echo Whisper service is already running.
)
cd ..

echo.
echo Starting dictation hotkey (Win+F1)...
start "" "scripts\hold_to_record.ahk"

echo.
echo Whisper Dictation is now active!
echo Press Win+F1 to start recording.
echo.
