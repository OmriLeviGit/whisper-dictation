"""
Configuration Loader
Loads configuration from .env files and exports as Python constants
Used by record.py and transcribe_client.py
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Find project root (where config/ is located)
PROJECT_ROOT = Path(__file__).parent.parent
CONFIG_DIR = PROJECT_ROOT / "config"
CLIENT_ENV = CONFIG_DIR / "client.env"
SERVICE_ENV = CONFIG_DIR / "service.env"

# Load environment variables from both config files
# Service config loaded first, then client can override if needed
load_dotenv(SERVICE_ENV)
load_dotenv(CLIENT_ENV)

# Helper function to get environment variables with defaults
def get_env(key: str, default=None, cast=str):
    """Get environment variable with optional type casting"""
    value = os.getenv(key, default)
    if value is None or value == "":
        return default
    if cast == int:
        return int(value)
    elif cast == float:
        return float(value)
    return value

# Audio settings
SAMPLE_RATE = get_env("AUDIO_SAMPLE_RATE", 16000, int)
CHANNELS = get_env("AUDIO_CHANNELS", 1, int)

# Whisper client settings
WHISPER_PORT = get_env("WHISPER_PORT", 8765, int)
WHISPER_TIMEOUT = get_env("WHISPER_TIMEOUT", 300, int)
WHISPER_MAX_RETRIES = get_env("WHISPER_MAX_RETRIES", 3, int)
WHISPER_RETRY_DELAY = get_env("WHISPER_RETRY_DELAY", 2, int)
WHISPER_SERVICE_URL = f"http://localhost:{WHISPER_PORT}"
