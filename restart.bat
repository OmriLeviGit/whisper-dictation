@echo off
echo Stopping any running AutoHotkey instances of hold_to_record.ahk...
taskkill /F /IM AutoHotkey64.exe /FI "WINDOWTITLE eq hold_to_record.ahk*" >NUL 2>&1

echo Starting hold_to_record.ahk...
start "" "%~dp0scripts\hold_to_record.ahk"

echo.
echo Script restarted! Check system tray for hotkey details.
timeout /t 2 >NUL
