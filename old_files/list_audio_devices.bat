@echo off
echo Listing audio input devices...
echo.
ffmpeg -list_devices true -f dshow -i dummy 2>&1 | findstr /C:"DirectShow audio devices"
ffmpeg -list_devices true -f dshow -i dummy 2>&1 | findstr /C:"(audio)"
echo.
echo Copy the exact name of your microphone from above
echo and update the hold_to_record.ahk script if needed.
pause
