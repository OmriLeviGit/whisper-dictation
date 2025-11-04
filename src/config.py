"""
Configuration loader for Whisper Dictation
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

# Whisper settings
WHISPER_PORT = get_env("WHISPER_PORT", 58432, int)
WHISPER_MODEL = get_env("WHISPER_MODEL", "large-v3")
WHISPER_DEVICE = get_env("WHISPER_DEVICE", "cuda")
WHISPER_COMPUTE_TYPE = get_env("WHISPER_COMPUTE_TYPE", "float16")
WHISPER_TIMEOUT = get_env("WHISPER_TIMEOUT", 300, int)
WHISPER_MAX_RETRIES = get_env("WHISPER_MAX_RETRIES", 3, int)
WHISPER_RETRY_DELAY = get_env("WHISPER_RETRY_DELAY", 2, int)
WHISPER_SERVICE_URL = f"http://localhost:{WHISPER_PORT}"

# Typing settings
TYPING_CHAR_DELAY = get_env("TYPING_CHAR_DELAY", 0.03, float)
TYPING_INITIAL_DELAY = get_env("TYPING_INITIAL_DELAY", 0.3, float)

# Paths
TEMP_DIR = get_env("TEMP_DIR", None)
MODEL_CACHE = get_env("MODEL_CACHE_DIR", "/models")
