# Faster-Whisper Transcription Service

A high-performance, GPU-accelerated audio transcription service using OpenAI's Whisper (via Faster-Whisper) running in Docker. Optimized for real-time push-to-talk dictation on Windows with NVIDIA GPU support.

## Features

- **GPU Accelerated**: Uses NVIDIA CUDA for fast inference (float16 precision)
- **Large-v3 Model**: OpenAI's most accurate Whisper model
- **Auto Language Detection**: Automatically detects the spoken language
- **REST API**: Simple HTTP endpoints for easy integration
- **Persistent Caching**: Models are cached and persist across container restarts
- **Auto-start**: Configured to start automatically when Windows boots
- **Low Latency**: Optimized for real-time dictation use cases
- **Modern Python**: Uses `uv` package manager for fast dependency installation

## Prerequisites

### 1. NVIDIA GPU Driver
- Install the latest NVIDIA GPU driver for your graphics card
- Download from: https://www.nvidia.com/Download/index.aspx

### 2. Docker Desktop for Windows
- Download and install Docker Desktop: https://www.docker.com/products/docker-desktop/
- During installation, ensure "Use WSL 2 instead of Hyper-V" is selected
- After installation, restart your computer

### 3. NVIDIA Container Toolkit (for GPU support in Docker)

Open PowerShell as Administrator and run:

```powershell
# Verify Docker is running
docker --version

# The nvidia-docker toolkit is included in Docker Desktop for Windows
# Verify GPU access:
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

If the above command shows your GPU information, you're ready to go!

## Installation

### 1. Clone or Download This Repository

```bash
cd D:\Dev\Personal\Whisper
```

### 2. Build the Docker Image

```bash
docker-compose build
```

This will:
- Download the CUDA base image
- Install Python 3.11 and uv package manager
- Install all dependencies (Faster-Whisper, FastAPI, etc.)
- Set up the environment

**Note**: The first build takes 5-10 minutes depending on your internet speed.

### 3. Start the Service

```bash
docker-compose up -d
```

The `-d` flag runs the container in the background (daemon mode).

### 4. Verify the Service is Running

```bash
# Check container status
docker-compose ps

# Check logs
docker-compose logs -f whisper-transcription

# Test the health endpoint
curl http://localhost:58231/health
```

You should see:
```json
{
  "status": "healthy",
  "model_loaded": true,
  "ready": true
}
```

**First Start Note**: The first time you start the service, it will download the large-v3 model (~3GB). This takes 5-10 minutes depending on your internet speed. The model is cached in a Docker volume and won't be downloaded again.

## Usage

### API Endpoints

#### 1. Health Check
```bash
curl http://localhost:58231/health
```

#### 2. Transcribe Audio (Detailed Response)
```bash
curl -X POST "http://localhost:58231/transcribe" \
  -F "audio=@path/to/your/audio.wav"
```

Response:
```json
{
  "text": "This is the transcribed text.",
  "language": "en",
  "language_probability": 0.99,
  "duration": 5.2,
  "segments": [
    {
      "start": 0.0,
      "end": 5.2,
      "text": "This is the transcribed text."
    }
  ]
}
```

#### 3. Transcribe Audio (Simple Text Only)
```bash
curl -X POST "http://localhost:58231/transcribe/simple" \
  -F "audio=@path/to/your/audio.wav"
```

Response:
```json
{
  "text": "This is the transcribed text."
}
```

### Supported Audio Formats

- WAV (.wav)
- MP3 (.mp3)
- M4A (.m4a)
- FLAC (.flac)
- OGG (.ogg)
- Opus (.opus)
- WebM (.webm)

### Python Example

```python
import requests

def transcribe_audio(audio_file_path):
    url = "http://localhost:58231/transcribe/simple"

    with open(audio_file_path, 'rb') as audio_file:
        files = {'audio': audio_file}
        response = requests.post(url, files=files)

    if response.status_code == 200:
        return response.json()['text']
    else:
        raise Exception(f"Transcription failed: {response.text}")

# Usage
text = transcribe_audio("recording.wav")
print(text)
```

### AutoHotkey Integration

See `example_autohotkey.ahk` for a complete push-to-talk dictation example.

## Windows Auto-Start Configuration

To make the service start automatically when Windows boots:

### Method 1: Docker Desktop Settings (Recommended)

1. Open Docker Desktop
2. Go to **Settings** → **General**
3. Enable **"Start Docker Desktop when you log in"**
4. Click **Apply & Restart**

The service will now start automatically because the `docker-compose.yml` has `restart: unless-stopped`.

### Method 2: Windows Task Scheduler (More Control)

If you want more control or Docker Desktop isn't starting:

1. Open **Task Scheduler** (search in Start Menu)
2. Click **"Create Basic Task"** in the right panel
3. **Name**: "Start Whisper Transcription Service"
4. **Trigger**: "When I log on"
5. **Action**: "Start a program"
6. **Program/script**: `docker-compose`
7. **Add arguments**: `up -d`
8. **Start in**: `D:\Dev\Personal\Whisper`
9. Click **Finish**

### Method 3: Startup Folder (Simple)

Create a batch file `start_whisper.bat`:

```batch
@echo off
cd /d D:\Dev\Personal\Whisper
docker-compose up -d
```

Then:
1. Press `Win + R` and type: `shell:startup`
2. Copy `start_whisper.bat` to the opened folder
3. The service will start when you log in

## Managing the Service

### Start the service
```bash
docker-compose up -d
```

### Stop the service
```bash
docker-compose down
```

### Restart the service
```bash
docker-compose restart
```

### View logs (live)
```bash
docker-compose logs -f
```

### Check status
```bash
docker-compose ps
```

### Update the service (after code changes)
```bash
docker-compose down
docker-compose build
docker-compose up -d
```

### Clear model cache (if you want to re-download models)
```bash
docker-compose down -v
```

## Performance Optimization

The service is already optimized for low latency:

- **float16 compute type**: 2x faster than float32 with minimal accuracy loss
- **GPU inference**: 5-10x faster than CPU
- **VAD filtering**: Reduces processing time by skipping silence
- **Beam size 5**: Good balance between speed and accuracy
- **4 workers**: Parallel processing for better throughput

### Expected Performance (NVIDIA RTX 3060+)

- Short audio (5-10 seconds): ~0.5-1 second
- Medium audio (30 seconds): ~2-3 seconds
- Long audio (2 minutes): ~5-10 seconds

**Note**: First request after starting takes longer due to model initialization (~10 seconds).

## Troubleshooting

### GPU Not Detected

```bash
# Check if NVIDIA driver is installed
nvidia-smi

# Verify Docker can access GPU
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

If GPU is not detected:
1. Update NVIDIA drivers
2. Restart Docker Desktop
3. Verify Windows WSL 2 is enabled

### Service Won't Start

```bash
# Check logs for errors
docker-compose logs

# Common issues:
# 1. Port 58231 already in use
# 2. GPU not accessible
# 3. Insufficient disk space for model download
```

### Port Already in Use

If port 58231 is in use, edit `docker-compose.yml` and change:
```yaml
ports:
  - "127.0.0.1:58231:58231"
```
to a different port, e.g., `58232`.

### Model Download Fails

If the model download fails:
1. Check your internet connection
2. Clear the volume and try again:
   ```bash
   docker-compose down -v
   docker-compose up -d
   ```

### Out of Memory

If you get CUDA out of memory errors:
1. Close other GPU-intensive applications
2. Reduce batch size in `transcription_service.py`

## API Documentation

Once the service is running, visit:
- **Interactive API docs**: http://localhost:58231/docs
- **Alternative docs**: http://localhost:58231/redoc

## Project Structure

```
D:\Dev\Personal\Whisper\
├── Dockerfile                    # Docker image configuration
├── docker-compose.yml           # Docker Compose orchestration
├── transcription_service.py     # FastAPI service implementation
├── pyproject.toml              # Python dependencies (uv format)
├── README.md                   # This file
├── example_autohotkey.ahk      # AutoHotkey integration example
└── logs/                       # Service logs (created on first run)
```

## Security Notes

- The service binds to `127.0.0.1` (localhost only) for security
- Do NOT expose port 58231 to the internet without proper authentication
- The service does not store audio files (they're deleted after transcription)

## License

This project uses:
- **Faster-Whisper**: MIT License
- **OpenAI Whisper**: MIT License
- **FastAPI**: MIT License

## Support

For issues related to:
- **Faster-Whisper**: https://github.com/guillaumekln/faster-whisper
- **Docker**: https://docs.docker.com/
- **NVIDIA Container Toolkit**: https://github.com/NVIDIA/nvidia-docker

## Changelog

### Version 1.0.0
- Initial release
- Support for large-v3 model
- GPU acceleration with CUDA
- REST API with FastAPI
- Docker containerization
- Windows auto-start support
