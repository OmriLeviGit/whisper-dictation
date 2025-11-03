"""
Configuration loader for Whisper Dictation
"""
import tomllib
from pathlib import Path

# Find project root (where config.toml is located)
PROJECT_ROOT = Path(__file__).parent.parent
CONFIG_FILE = PROJECT_ROOT / "config.toml"

# Load configuration
def load_config():
    """Load configuration from config.toml"""
    with open(CONFIG_FILE, "rb") as f:
        return tomllib.load(f)

# Global config object
_config = load_config()

# Audio settings
SAMPLE_RATE = _config["audio"]["sample_rate"]
CHANNELS = _config["audio"]["channels"]

# Whisper settings
WHISPER_PORT = _config["whisper"]["port"]
WHISPER_MODEL = _config["whisper"]["model"]
WHISPER_DEVICE = _config["whisper"]["device"]
WHISPER_COMPUTE_TYPE = _config["whisper"]["compute_type"]
WHISPER_TIMEOUT = _config["whisper"]["timeout"]
WHISPER_MAX_RETRIES = _config["whisper"]["max_retries"]
WHISPER_RETRY_DELAY = _config["whisper"]["retry_delay"]
WHISPER_SERVICE_URL = f"http://localhost:{WHISPER_PORT}"

# Typing settings
TYPING_CHAR_DELAY = _config["typing"]["char_delay"]
TYPING_INITIAL_DELAY = _config["typing"]["initial_delay"]

# Paths
TEMP_DIR = _config["paths"]["temp_dir"] or None
MODEL_CACHE = _config["paths"]["model_cache"]
