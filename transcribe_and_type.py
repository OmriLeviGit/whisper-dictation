"""
Transcribe and Type Orchestration
Main script that transcribes audio and types the result at the cursor position
"""

import sys
import logging
from pathlib import Path

from transcribe_client import transcribe_audio, ServiceUnavailableError, TranscriptionError
from keyboard_typer import type_text_fast

# Configure logging to also write to file
log_dir = Path.home() / "AppData" / "Local" / "Temp" / "whisper_dictation"
log_dir.mkdir(parents=True, exist_ok=True)
log_file = log_dir / "transcribe_and_type.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


def main(audio_path: str) -> int:
    """
    Main orchestration function

    Args:
        audio_path: Path to the recorded audio file

    Returns:
        Exit code (0 = success, 1 = error)
    """
    try:
        logger.info(f"Starting transcription workflow for: {audio_path}")

        # Step 1: Transcribe audio
        logger.info("Transcribing audio...")
        try:
            transcribed_text = transcribe_audio(audio_path, simple=True)
        except ServiceUnavailableError as e:
            logger.error(f"Service unavailable: {e}")
            print("ERROR: Whisper service is not running!")
            print("Please run 'start_whisper.bat' first.")
            return 1
        except TranscriptionError as e:
            logger.error(f"Transcription failed: {e}")
            print(f"ERROR: Transcription failed: {e}")
            return 1
        except FileNotFoundError as e:
            logger.error(f"File not found: {e}")
            print(f"ERROR: {e}")
            return 1

        # Check if transcription is empty
        if not transcribed_text or not transcribed_text.strip():
            logger.warning("Transcription is empty - no speech detected")
            print("No speech detected in recording")
            return 0

        logger.info(f"Transcription successful: '{transcribed_text[:50]}...'")

        # Step 2: Type the transcription
        logger.info("Typing transcription...")
        try:
            type_text_fast(transcribed_text)
            logger.info("Transcription typed successfully")
            print(f"Typed: {transcribed_text}")
            return 0

        except Exception as e:
            logger.error(f"Typing failed: {e}")
            print(f"ERROR: Failed to type text: {e}")
            return 1

    except Exception as e:
        logger.exception(f"Unexpected error: {e}")
        print(f"ERROR: Unexpected error: {e}")
        return 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python transcribe_and_type.py <audio_file_path>")
        sys.exit(1)

    audio_path = sys.argv[1]
    exit_code = main(audio_path)
    sys.exit(exit_code)
