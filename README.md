# Whisper Dictation

GPU-accelerated speech-to-text dictation for Windows using OpenAI Whisper. Hold a hotkey to record, release to transcribe and auto-type the result. All processing happens locally.

## How to Use

Once installed, dictation is simple:

- **Hold Win+F1** while speaking, release when done
- Text auto-typing behavior:
  - If you stay in the same window: auto-types at the position where you released the hotkey
  - Falls back to current cursor position if restoration fails
  - If you switched windows: won't auto-type, but the transcription is saved to the pasting buffer (accessible via **Win+V**)
- **Press Win+V** to paste the last transcription again

> **Note:** Both hotkeys are configurable in `config/client.env`. Win+F1 overrides Windows Help, and Win+V overrides Windows' clipboard history.

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

3. **Run setup**:
   ```bash
   whisper-setup
   ```
   Installs dependencies, builds the Docker image, starts the Whisper service, and launches the dictation hotkey.

4. **Test it**: Hold **Win+F1**, speak, then release

> **Note:** First transcription may take longer as the model loads into memory, with subsequent ones being faster. If still too slow, consider setting a smaller model in `config/service.env`.

### Recommended: Auto-start on Windows startup

1. Navigate to `scripts\`
2. Right click to create a shortcut of `whisper-run.vbs`
3. Press **Win+R** → `shell:startup` → Enter
4. Place the shortcut in the startup folder

This will automatically launch the dictation hotkey silently in the background when Windows starts.

> **Security Note:** Before setting up auto-start, review the code in `scripts\whisper-run.vbs` and the source files to ensure you trust what will run on startup. Never blindly trust scripts from untrusted sources!

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
- After editing `client.env`: Run `whisper-run` to apply changes
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
- `whisper-run` - Run the dictation hotkey (use this after computer restart)
- `whisper-stop` - Stop all services (AutoHotkey + Docker)

> If you set up an auto-start, you don't need to run anything. Otherwise, run `whisper-run` whenever you want to use dictation.

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
whisper-run  # Run the hotkey script
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