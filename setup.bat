@echo off
REM First-time setup script for Whisper Dictation
echo ========================================
echo Whisper Dictation - First Time Setup
echo ========================================
echo.

REM Check if Docker is running
echo [1/4] Checking Docker...
docker info >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: Docker is not running!
    echo Please start Docker Desktop and run this script again.
    pause
    exit /b 1
)
echo Docker is running.
echo.

REM Install Python dependencies
echo [2/4] Installing Python dependencies...
uv sync
if %errorlevel% neq 0 (
    echo ERROR: Failed to install Python dependencies!
    pause
    exit /b 1
)
echo Python dependencies installed.
echo.

REM Build Docker image
echo [3/4] Building Docker image (this may take several minutes)...
cd docker
docker-compose build
if %errorlevel% neq 0 (
    echo ERROR: Failed to build Docker image!
    cd ..
    pause
    exit /b 1
)
cd ..
echo Docker image built successfully.
echo.

REM Start services
echo [4/4] Starting Whisper service...
cd docker
docker-compose up -d
if %errorlevel% neq 0 (
    echo ERROR: Failed to start service!
    cd ..
    pause
    exit /b 1
)
cd ..
echo.
echo Waiting for service to be ready...
timeout /t 10 /nobreak >nul
echo.

echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo The Whisper service is now running in the background.
echo.
echo Next steps:
echo   1. Run start.bat to start the dictation hotkey
echo   2. Press Win+F1 to record
echo.
echo See README.md for more information.
echo.
pause
