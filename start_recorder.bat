@echo off
echo Starting Hold-to-Record with Win+F1...
echo.
echo Instructions:
echo   - Press and HOLD Win+F1 to start recording
echo   - Release Win+F1 to stop recording
echo   - Recordings will be saved to: %TEMP%\whisper_dictation\
echo   - Press Esc to cancel a recording
echo.
echo Starting AutoHotkey script...
start "" "hold_to_record.ahk"
