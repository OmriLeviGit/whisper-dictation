# Whisper Dictation

GPU-accelerated speech-to-text dictation for Windows using OpenAI Whisper. Hold a hotkey to record, release to transcribe and auto-type the result. All processing happens locally.

## Features

- Hold **Win+F1** (configurable) while speaking, release when done
- If you stay in the same window: auto-types at the position where you released the hotkey (falls back to current cursor if restoration fails)
- Every transcription is saved to a buffer. Use **Win+V** for pasting

> **Note:** Win+V overrides Windows' default clipboard history hotkey. Can be changed `config/client.env`.

## Requirements

- **Windows 10/11**
- **Python 3.11+** with [uv](https://github.com/astral-sh/uv)
- **Docker Desktop** with WSL2
- **NVIDIA GPU** (optional, can use CPU)
- **[AutoHotkey v2.0](https://www.autohotkey.com/)**

## Installation

1. **Clone the repository**:
   ```bash
   git clone <your-repo-url>
   cd whisper-dictation
   ```

2. **Install the package**:
   ```bash
   uv pip install -e .
   ```
   This installs the package in editable mode and creates CLI commands.

## Quick Start

1. **First-time setup**:
   ```bash
   whisper-setup
   ```
   Installs dependencies, builds the Docker image, and starts the Whisper service.

2. **Daily use**:
   ```bash
   whisper-start
   ```
   Launches the dictation hotkey. Run this whenever you want to use dictation. Whisper should auto-start on system reboot with docker.

3. **Test it**: Hold **Win+F1**, speak, then release

4. **Stop services** (optional):
   ```bash
   whisper-stop
   ```
   Stops both the AutoHotkey script and Docker service.

> **Note:** First transcription may take longer as the model loads into memory, with subsequent ones being faster. If still too slow, consider setting a smaller model in `config/service.env`.

### Optional: Auto-start on Windows startup

1. Create a shortcut that runs: `whisper-start`
2. Press **Win+R** → `shell:startup` → Enter
3. Place the shortcut in the startup folder

## Configuration

The defaults work well for most users. Edit files in `config/` directory as needed.

**`config/client.env`** - Hotkey and client behavior:
```env
HOTKEY=Win+F1                    # Examples: Alt+R, Ctrl+Shift+Space, Win+Shift+F1
PASTE_HOTKEY=Win+V               # Paste last transcription (overrides Windows clipboard history)
AUDIO_DEVICE=                    # Empty = default mic (see Troubleshooting to list devices)
AUDIO_SAMPLE_RATE=16000          # Recommended for Whisper models
WHISPER_TIMEOUT=300              # Timeout for transcription requests (seconds)
WHISPER_MAX_RETRIES=3            # Number of retry attempts
TEMP_DIR=                        # Recordings location (empty = %TEMP%\whisper_dictation)
```

**`config/service.env`** - Whisper model and performance:
```env
WHISPER_MODEL=large-v3-turbo     # Options: tiny, base, small, medium, large-v3, large-v3-turbo
WHISPER_DEVICE=cuda              # cuda (GPU) or cpu
WHISPER_COMPUTE_TYPE=float16     # float16 (GPU) or int8 (CPU)
```

**Apply changes:**
- After editing `client.env`: `whisper-start` (restart the hotkey script)
- After editing `service.env`: Rebuild the Docker container with `whisper-setup`

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
├── src/                         # Python package
│   └── whisper_dictation/       # Main package
│       ├── __init__.py          # Package initialization
│       ├── cli.py               # Command-line interface
│       ├── load_config.py       # Configuration loader
│       ├── record.py            # Audio recording module
│       ├── transcribe.py        # Transcription wrapper for AHK
│       ├── transcribe_client.py # API client for transcription service
│       └── whisper_service.py   # Whisper API service (runs in Docker)
├── utils/                       # Utility scripts
│   ├── check_recordings.py      # Debug recording files
│   └── view_log.py              # View application logs
├── pyproject.toml               # Package configuration and dependencies
├── MANIFEST.in                  # Package data files
├── LICENSE                      # MIT License
└── README.md                    # This file
```

## CLI Commands

After installation, the following commands are available:

- `whisper-setup` - First-time setup (install deps, build Docker, start service)
- `whisper-start` - Start the dictation hotkey
- `whisper-stop` - Stop all services (AutoHotkey + Docker)
- `whisper-service` - Manually run the Whisper service (for development)

## Troubleshooting

**Service not starting:**
- Check Docker is running: `docker info`
- View logs: `docker-compose -f docker/docker-compose.yml --env-file config/service.env logs`

**No transcription / Empty text:**
- Verify Whisper service is running: `docker-compose -f docker/docker-compose.yml --env-file config/service.env ps`
- Check logs in `%TEMP%\whisper_dictation\`

**Change audio device:**
```bash
uv run python -m whisper_dictation.record --list-devices  # List devices
# Edit config/client.env: Set AUDIO_DEVICE=<device_id>
whisper-start  # Restart the hotkey script
```

**Recordings location:**
- Default: `%TEMP%\whisper_dictation\recording_*.wav`
- Can be changed via `TEMP_DIR` in `config/client.env`

## Advanced

### Using CPU instead of GPU
If you don't have an NVIDIA GPU:
1. Edit `config/service.env`: Set `WHISPER_DEVICE=cpu` and `WHISPER_COMPUTE_TYPE=int8`
2. Remove the GPU sections from `docker/docker-compose.yml` (the `deploy:` block)
3. Run `whisper-setup` to rebuild with CPU support

## Tools used

- **OpenAI Whisper** - Speech recognition model
- **faster-whisper** - Optimized Whisper implementation
- **AutoHotkey** - Windows automation