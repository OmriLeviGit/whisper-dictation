"""
Transcribe
Transcribes audio and outputs the text to stdout (no typing)
Used by AHK to get transcription text for window matching logic
"""

import sys
import logging
from pathlib import Path

from transcribe_client import transcribe_audio, ServiceUnavailableError, TranscriptionError

# Configure logging to file only (not to console, to keep stdout clean)
log_dir = Path.home() / "AppData" / "Local" / "Temp" / "whisper_dictation"
log_dir.mkdir(parents=True, exist_ok=True)
log_file = log_dir / "transcribe.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8')
    ]
)
logger = logging.getLogger(__name__)


def main(audio_path: str) -> int:
    """
    Transcribe audio and output text to stdout

    Args:
        audio_path: Path to the recorded audio file

    Returns:
        Exit code (0 = success, 1 = error)
    """
    try:
        logger.info(f"Starting transcription for: {audio_path}")

        # Transcribe audio
        try:
            transcribed_text = transcribe_audio(audio_path, simple=True)
        except ServiceUnavailableError as e:
            logger.error(f"Service unavailable: {e}")
            print("ERROR:SERVICE_UNAVAILABLE", file=sys.stderr)
            return 1
        except TranscriptionError as e:
            logger.error(f"Transcription failed: {e}")
            print(f"ERROR:TRANSCRIPTION_FAILED:{e}", file=sys.stderr)
            return 1
        except FileNotFoundError as e:
            logger.error(f"File not found: {e}")
            print(f"ERROR:FILE_NOT_FOUND:{e}", file=sys.stderr)
            return 1

        # Check if transcription is empty
        if not transcribed_text or not transcribed_text.strip():
            logger.warning("Transcription is empty - no speech detected")
            print("", end='')  # Output empty string
            return 0

        logger.info(f"Transcription successful: '{transcribed_text[:50]}...'")

        # Output transcribed text to stdout (no newline at the end)
        print(transcribed_text, end='')
        return 0

    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        print(f"ERROR:UNEXPECTED:{e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python transcribe.py <audio_file_path>", file=sys.stderr)
        sys.exit(1)

    audio_path = sys.argv[1]
    exit_code = main(audio_path)
    sys.exit(exit_code)
