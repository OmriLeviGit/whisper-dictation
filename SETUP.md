# Hold-to-Record Setup

## Quick Start

1. **Install dependencies:**
   ```bash
   uv sync
   ```

2. **Start the recorder:**
   ```bash
   start_recorder.bat
   ```
   Or to restart after changes:
   ```bash
   restart.bat
   ```

3. **Test recording:**
   - Press and HOLD `Win+F1`
   - Speak while holding the key
   - Release to stop recording
   - You'll hear a beep when recording stops

## Main Files

- `hold_to_record.ahk` - AutoHotkey script that captures Win+F1 hotkey
- `recorder.py` - Python script that records audio using sounddevice
- `restart.bat` - Restart the AHK script after changes
- `start_recorder.bat` - Start the AHK script with instructions

## Utility Scripts

- `check_recordings.py` - View list of recorded files with durations and sizes
- `view_log.py` - View recorder debug logs

## How It Works

The system uses a **flag file** approach for reliable communication:
1. AutoHotkey creates a `.stop` flag file when you release Win+F1
2. Python checks for the flag every 200ms while recording
3. When detected, Python saves the recording and exits gracefully
4. No process killing needed - fully reliable!

## Recorded Files

Audio files are saved to: `%TEMP%\whisper_dictation\recording_YYYYMMDD_HHMMSS.wav`

Logs are saved to:
- `%TEMP%\whisper_dictation\ahk_debug.log` - AutoHotkey debug log
- `%TEMP%\whisper_dictation\recorder.log` - Python recorder log

## List Audio Devices

To see available microphones:
```bash
uv run python recorder.py --list-devices
```

Then update `AUDIO_DEVICE` in `hold_to_record.ahk` if needed.

## Troubleshooting

- **Recording doesn't start**: Check that AutoHotkey is running (system tray icon)
- **Recording doesn't stop**: Check logs in `%TEMP%\whisper_dictation\`
- **No audio captured**: Run `--list-devices` and configure correct device
- **Dependencies missing**: Run `uv sync` to install required packages
