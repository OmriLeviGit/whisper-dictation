# Whisper Dictation

GPU-accelerated speech-to-text dictation using OpenAI Whisper. Hold Win+F1 to record, release to transcribe and automatically type the result.

## Features

- **Hold-to-record**: Press and hold Win+F1 to record audio
- **Automatic transcription**: GPU-accelerated Whisper large-v3 model
- **Auto-typing**: Transcribed text automatically types at cursor position
- **Configurable**: All settings in one config file
- **Background service**: Docker-based Whisper service runs persistently

## Requirements

- **Windows 10/11**
- **Python 3.11+** with [uv](https://github.com/astral-sh/uv)
- **Docker Desktop** with WSL2
- **NVIDIA GPU** with nvidia-docker (for GPU acceleration)
- **AutoHotkey v2.0**

## Quick Start

### First-Time Setup

1. **Run setup script** (installs dependencies, builds Docker, starts service):
   ```bash
   setup.bat
   ```

2. **Start dictation**:
   ```bash
   start.bat
   ```

3. **Test it**: Press and hold **Win+F1**, speak, then release

### Daily Use

- **Start**: `start.bat` - Starts Whisper service and hotkey
- **Stop**: `stop.bat` - Stops everything
- **Restart hotkey**: `restart.bat` - Restarts just the AutoHotkey script

## How It Works

1. **Hold Win+F1** → Recording stttarts
2. **Speak** → Audio captured at 16kHz
3. **Release Win+F1** → Recording stops, sent to Whisper
4. **Transcription** → GPU-accelerated processing (~2-5 seconds)
5. **Auto-type** → Text types at cursor position

## Configuration

Edit `config.toml` to customize settings:

```toml
[audio]
sample_rate = 16000  # Optimal for Whisper
channels = 1         # Mono

[whisper]
port = 58432              # Service port
model = "large-v3"        # Whisper model size
device = "cuda"           # cuda or cpu
compute_type = "float16"  # float16 (GPU) or int8 (CPU)
timeout = 300             # Request timeout
max_retries = 3
retry_delay = 2

[typing]
char_delay = 0.03      # Delay between characters (slower for Notepad)
initial_delay = 0.3    # Delay before typing starts

[paths]
temp_dir = ""          # Leave empty for system temp
model_cache = "/models"
```

After changing config:
- Restart AHK: `restart.bat`
- Rebuild Docker (if changed model/device): `cd docker && docker-compose up -d --build`

## Project Structure

```
Whisper/
├── config.toml          # All configuration settings
├── README.md            # This file
├── setup.bat            # First-time setup
├── start.bat            # Start everything
├── stop.bat             # Stop everything
├── restart.bat          # Restart AutoHotkey
├── pyproject.toml       # Python dependencies
├── src/                 # Python source code
│   ├── config.py
│   ├── recorder.py
│   ├── transcribe_client.py
│   ├── keyboard_typer.py
│   ├── transcribe_and_type.py
│   └── transcription_service.py
├── scripts/
│   └── hold_to_record.ahk
├── docker/
│   ├── Dockerfile
│   ├── docker-compose.yml
│   └── .dockerignore
└── utils/
    ├── check_recordings.py
    └── view_log.py
```

## Troubleshooting

### Whisper service not starting
```bash
# Check Docker is running
docker info

# Check service status
cd docker
docker-compose ps
docker-compose logs

# Rebuild
docker-compose up -d --build
```

### No transcription / Empty text
- Check Whisper service is healthy: `cd docker && docker-compose ps`
- View logs: `cd docker && docker-compose logs -f`
- Check temp folder: `%TEMP%\whisper_dictation\`

### Text not typing / Cut off in Notepad
- Text types too fast for some apps
- Increase `char_delay` in config.toml
- Run `restart.bat`

### Recordings location
- Default: `%TEMP%\whisper_dictation\recording_*.wav`
- Logs: `%TEMP%\whisper_dictation\*.log`
- View recordings: `uv run python utils/check_recordings.py`

### Change audio device
```bash
# List available devices
uv run python src/recorder.py --list-devices

# Edit scripts/hold_to_record.ahk
global AUDIO_DEVICE := "5"  # Device ID
```

## Advanced

### Use CPU instead of GPU
1. Edit `config.toml`:
   ```toml
   [whisper]
   device = "cpu"
   compute_type = "int8"
   ```

2. Edit `docker/docker-compose.yml` - remove GPU sections:
   ```yaml
   # Remove entire 'deploy' section
   environment:
     - WHISPER_DEVICE=cpu
     - WHISPER_COMPUTE_TYPE=int8
   ```

3. Rebuild: `cd docker && docker-compose up -d --build`

### Different Whisper model
Edit `config.toml`:
```toml
model = "medium"  # Options: tiny, base, small, medium, large-v3
```
Then: `cd docker && docker-compose up -d --build`

### Change port
1. Edit `config.toml` → `whisper.port`
2. Edit `docker/docker-compose.yml` → Update all `58432` references
3. Rebuild: `cd docker && docker-compose up -d --build`
4. Restart: `restart.bat`

## Credits

- **OpenAI Whisper** - Speech recognition model
- **faster-whisper** - Optimized Whisper implementation
- **AutoHotkey** - Windows automation
- **FastAPI** - REST API framework

## License

MIT
