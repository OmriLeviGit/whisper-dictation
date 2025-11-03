@echo off
echo Stopping any running AutoHotkey instances of hold_to_record.ahk...
taskkill /F /IM AutoHotkey64.exe /FI "WINDOWTITLE eq hold_to_record.ahk*" >nul 2>&1

echo Starting hold_to_record.ahk...
start "" "%~dp0hold_to_record.ahk"

echo.
echo Script restarted! Press Win+F1 to test recording.
timeout /t 2 >nul
