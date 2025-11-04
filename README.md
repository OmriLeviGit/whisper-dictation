# Whisper Dictation

GPU-accelerated speech-to-text dictation using OpenAI Whisper. Hold a hotkey to record, release to transcribe and auto-type the result.

**How it works:** Hold Win+F1 → Speak → Release → Text appears at your cursor (~2-5 seconds)

## Requirements

- **Windows 10/11**
- **Python 3.11+** with [uv](https://github.com/astral-sh/uv)
- **Docker Desktop** with WSL2
- **NVIDIA GPU** (optional, can use CPU)
- **[AutoHotkey v2.0](https://www.autohotkey.com/)**

## Quick Start

1. **Start everything**:
   ```bash
   start.bat
   ```
   First run automatically installs dependencies and builds the Docker image.

2. **Test it**: Hold **Win+F1**, speak, then release

3. **Stop**: `stop.bat`

### Optional: Auto-start on login

1. Press **Win+R** → `shell:startup` → Enter
2. Create a shortcut to `start.bat`
3. Shortcut properties → Run: **Minimized**

## Configuration

The defaults work well for most users. Edit configuration files in the `config/` directory as needed.

### Common Settings

**`config/client.env`** - Hotkey and typing behavior:
- **`HOTKEY=Win+F1`** - Customize your recording hotkey
  - Examples: `Alt+R`, `Ctrl+Shift+Space`, `Win+Shift+F1`
- **`TYPING_CHAR_DELAY=0.03`** - Increase if text gets cut off in some apps
- **`AUDIO_DEVICE=`** - Empty uses default mic (see Troubleshooting to list devices)
- **`TEMP_DIR=`** - Recording save location (default: `%TEMP%\whisper_dictation\`)

**`config/service.env`** - Whisper model and performance:
- **`WHISPER_MODEL=large-v3-turbo`** - Balance speed vs accuracy
  - Fast: `tiny`, `base`, `small`
  - Balanced: `medium`, `large-v3-turbo` ⭐ (default)
  - Most Accurate: `large-v3`
- **`WHISPER_DEVICE=cuda`** - Use `cpu` if no NVIDIA GPU
- **`WHISPER_COMPUTE_TYPE=float16`** - Use `int8` for CPU mode

### Apply Changes

- After editing **client.env** (hotkey/typing): `restart.bat`
- After editing **service.env** (model/GPU): `start.bat`

## Troubleshooting

**Service not starting:**
- Check Docker is running: `docker info`
- View logs: `docker-compose -f docker/docker-compose.yml --env-file config/service.env logs`

**No transcription / Empty text:**
- Verify Whisper service is running: `docker-compose -f docker/docker-compose.yml --env-file config/service.env ps`
- Check logs in `%TEMP%\whisper_dictation\`

**Text cut off or not typing:**
- Increase `TYPING_CHAR_DELAY` in `config/client.env` to `0.05` or higher
- Run `restart.bat`

**Change audio device:**
```bash
uv run python src/recorder.py --list-devices  # List devices
# Edit config/client.env: Set AUDIO_DEVICE=<device_id>
restart.bat
```

**Recordings location:** `%TEMP%\whisper_dictation\recording_*.wav`

## Advanced

### Using CPU instead of GPU
If you don't have an NVIDIA GPU:
1. Edit `config/service.env`: Set `WHISPER_DEVICE=cpu` and `WHISPER_COMPUTE_TYPE=int8`
2. Remove the GPU sections from `docker/docker-compose.yml` (the `deploy:` block)
3. Run `start.bat`

## Credits

- **OpenAI Whisper** - Speech recognition model
- **faster-whisper** - Optimized Whisper implementation
- **AutoHotkey** - Windows automation
- **FastAPI** - REST API framework
