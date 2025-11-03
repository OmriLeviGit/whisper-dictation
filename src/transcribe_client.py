"""
Whisper Transcription Client
Handles communication with the Whisper transcription service
"""

import logging
import time
from pathlib import Path
from typing import Optional

import requests
from config import (
    WHISPER_SERVICE_URL,
    WHISPER_TIMEOUT,
    WHISPER_MAX_RETRIES,
    WHISPER_RETRY_DELAY
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Service configuration (from config file)
TIMEOUT_SECONDS = WHISPER_TIMEOUT
MAX_RETRIES = WHISPER_MAX_RETRIES
RETRY_DELAY = WHISPER_RETRY_DELAY


class TranscriptionError(Exception):
    """Raised when transcription fails"""
    pass


class ServiceUnavailableError(Exception):
    """Raised when Whisper service is not available"""
    pass


def check_service_health(timeout: int = 5) -> bool:
    """
    Check if the Whisper service is healthy and ready

    Args:
        timeout: Request timeout in seconds

    Returns:
        True if service is healthy, False otherwise
    """
    try:
        response = requests.get(
            f"{WHISPER_SERVICE_URL}/health",
            timeout=timeout
        )
        return response.status_code == 200
    except requests.exceptions.RequestException as e:
        logger.warning(f"Health check failed: {e}")
        return False


def transcribe_audio(audio_path: str, simple: bool = True) -> str:
    """
    Transcribe audio file using the Whisper service

    Args:
        audio_path: Path to the audio file (WAV, MP3, etc.)
        simple: If True, return only text. If False, return full response with metadata

    Returns:
        Transcribed text

    Raises:
        ServiceUnavailableError: If service is not running or unhealthy
        TranscriptionError: If transcription fails
        FileNotFoundError: If audio file doesn't exist
    """
    audio_file = Path(audio_path)

    # Validate file exists
    if not audio_file.exists():
        raise FileNotFoundError(f"Audio file not found: {audio_path}")

    # Check service health first
    if not check_service_health():
        raise ServiceUnavailableError(
            "Whisper service is not available. "
            "Make sure Docker container is running (start_whisper.bat)"
        )

    # Choose endpoint
    endpoint = "/transcribe/simple" if simple else "/transcribe"
    url = f"{WHISPER_SERVICE_URL}{endpoint}"

    # Attempt transcription with retries
    last_error = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            logger.info(f"Transcribing {audio_file.name} (attempt {attempt}/{MAX_RETRIES})")

            # Send file to service
            with open(audio_file, 'rb') as f:
                files = {'file': (audio_file.name, f, 'audio/wav')}
                response = requests.post(
                    url,
                    files=files,
                    timeout=TIMEOUT_SECONDS
                )

            # Check response
            if response.status_code == 200:
                result = response.json()
                transcribed_text = result.get('text', '').strip()

                if not transcribed_text:
                    logger.warning("Transcription returned empty text")
                    return ""

                logger.info(f"Transcription successful: {len(transcribed_text)} characters")
                return transcribed_text

            elif response.status_code == 503:
                raise ServiceUnavailableError("Service is starting up, please wait...")

            else:
                error_detail = response.json().get('detail', 'Unknown error')
                raise TranscriptionError(f"Service error: {error_detail}")

        except requests.exceptions.Timeout:
            last_error = TranscriptionError("Transcription timed out")
            logger.error(f"Attempt {attempt} timed out")

        except requests.exceptions.ConnectionError as e:
            last_error = ServiceUnavailableError(f"Cannot connect to service: {e}")
            logger.error(f"Attempt {attempt} connection failed: {e}")

        except requests.exceptions.RequestException as e:
            last_error = TranscriptionError(f"Request failed: {e}")
            logger.error(f"Attempt {attempt} request failed: {e}")

        # Wait before retry (except on last attempt)
        if attempt < MAX_RETRIES:
            logger.info(f"Retrying in {RETRY_DELAY} seconds...")
            time.sleep(RETRY_DELAY)

    # All retries exhausted
    raise last_error or TranscriptionError("Transcription failed after all retries")


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python transcribe_client.py <audio_file>")
        sys.exit(1)

    try:
        audio_path = sys.argv[1]
        text = transcribe_audio(audio_path)
        print(f"\nTranscription:\n{text}")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
