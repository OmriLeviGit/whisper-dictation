# Whisper Dictation

GPU-accelerated speech-to-text dictation for Windows using OpenAI Whisper. Hold a hotkey to record, release to transcribe and auto-type the result. All processing happens locally.

**How it works:** Hold the hotkey (default: Win+F1) while speaking, release when done - text appears at cursor

## Requirements

- **Windows 10/11**
- **Python 3.11+** with [uv](https://github.com/astral-sh/uv)
- **Docker Desktop** with WSL2
- **NVIDIA GPU** (optional, can use CPU)
- **[AutoHotkey v2.0](https://www.autohotkey.com/)**

## Quick Start

1. **First-time setup**:
   ```bash
   setup.bat
   ```
   Installs dependencies, builds the Docker image, and starts the Whisper service.

2. **Daily use**:
   ```bash
   start.bat
   ```
   Launches the dictation hotkey. Run this whenever you want to use dictation. Whisper should auto-start on system reboot with docker.

3. **Test it**: Hold **Win+F1**, speak, then release

> **Note:** First transcription takes longer as the Whisper model loads into memory. Subsequent transcriptions will be much faster (depending on model type and hardware).

### Optional: Auto-start on Windows startup

1. Press **Win+R** → `shell:startup` → Enter
2. Create a shortcut to `start.bat`
3. Shortcut properties → Run: **Minimized**

## Configuration

The defaults work well for most users. Edit files in `config/` directory as needed.

**`config/client.env`** - Hotkey and typing behavior:
```env
HOTKEY=Win+F1                    # Examples: Alt+R, Ctrl+Shift+Space, Win+Shift+F1
TYPING_CHAR_DELAY=0.03           # Increase to 0.05 if text gets cut off in some apps
AUDIO_DEVICE=                    # Empty = default mic (see Troubleshooting to list devices)
TEMP_DIR=                        # Recording location (default: %TEMP%\whisper_dictation\)
```

**`config/service.env`** - Whisper model and performance (smaller is faster):
```env
WHISPER_MODEL=large-v3-turbo     # Options: tiny, base, small, medium, large-v3, large-v3-turbo
WHISPER_DEVICE=cuda              # cuda (GPU) or cpu
WHISPER_COMPUTE_TYPE=float16     # float16 (GPU) or int8 (CPU)
```

**Apply changes:**
- After editing `client.env`: `start.bat` (restart the hotkey script)
- After editing `service.env`: Rebuild the Docker container with `setup.bat`

## Project Structure

```
whisper-dictation/
├── config/                      # Configuration files
│   ├── client.env               # Hotkey and typing behavior settings
│   └── service.env              # Whisper model and performance settings
├── docker/                      # Docker setup
│   ├── Dockerfile               # Container image definition
│   └── docker-compose.yml       # Service orchestration
├── scripts/                     # AutoHotkey scripts
│   └── hold_to_record.ahk       # Hotkey handler for recording
├── src/                         # Python source code
│   ├── config.py                # Configuration loader
│   ├── keyboard_typer.py        # Types transcribed text
│   ├── recorder.py              # Audio recording module
│   ├── transcribe_client.py     # API client for transcription
│   ├── transcribe_and_type.py   # Main client orchestrator
│   └── transcription_service.py # Whisper API service
├── utils/                       # Utility scripts
│   ├── check_recordings.py      # Debug recording files
│   └── view_log.py              # View application logs
├── setup.bat                    # First-time setup (run once)
├── start.bat                    # Launch dictation hotkey
├── stop.bat                     # Stop all services
├── pyproject.toml               # Python dependencies
└── README.md                    # This file
```

## Troubleshooting

**Service not starting:**
- Check Docker is running: `docker info`
- View logs: `docker-compose -f docker/docker-compose.yml --env-file config/service.env logs`

**No transcription / Empty text:**
- Verify Whisper service is running: `docker-compose -f docker/docker-compose.yml --env-file config/service.env ps`
- Check logs in `%TEMP%\whisper_dictation\`

**Text cut off or not typing:**
- Increase `TYPING_CHAR_DELAY` in `config/client.env` to `0.05` or higher
- Run `start.bat` to restart the hotkey script

**Change audio device:**
```bash
uv run python src/recorder.py --list-devices  # List devices
# Edit config/client.env: Set AUDIO_DEVICE=<device_id>
start.bat  # Restart the hotkey script
```

**Recordings location:** `%TEMP%\whisper_dictation\recording_*.wav`

## Advanced

### Using CPU instead of GPU
If you don't have an NVIDIA GPU:
1. Edit `config/service.env`: Set `WHISPER_DEVICE=cpu` and `WHISPER_COMPUTE_TYPE=int8`
2. Remove the GPU sections from `docker/docker-compose.yml` (the `deploy:` block)
3. Run `setup.bat` to rebuild with CPU support

## Credits

- **OpenAI Whisper** - Speech recognition model
- **faster-whisper** - Optimized Whisper implementation
- **AutoHotkey** - Windows automation
- **FastAPI** - REST API framework
