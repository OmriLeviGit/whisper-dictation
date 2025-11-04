@echo off
REM Start Whisper Dictation Hotkey
echo Starting Whisper Dictation...

REM Stop any existing instances
taskkill /F /IM AutoHotkey64.exe /FI "WINDOWTITLE eq hold_to_record.ahk*" >\\.\NUL 2>&1

REM Start the hotkey script
start "" "%~dp0scripts\hold_to_record.ahk"

echo.
echo Whisper Dictation hotkey is now active!
echo Check your system tray for hotkey details.
timeout /t 2 >\\.\NUL
