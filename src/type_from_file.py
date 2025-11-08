"""
Type From File
Reads text from a file and types it immediately (no delays)
Used by AHK for automated typing after transcription
"""

import sys
import logging
from pathlib import Path
from keyboard_typer import type_text_fast

# Configure logging to file only
log_dir = Path.home() / "AppData" / "Local" / "Temp" / "whisper_dictation"
log_dir.mkdir(parents=True, exist_ok=True)
log_file = log_dir / "type_from_file.log"

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(log_file, encoding='utf-8')
    ]
)
logger = logging.getLogger(__name__)


def main(text_file_path: str) -> int:
    """
    Read text from file and type it

    Args:
        text_file_path: Path to file containing text to type

    Returns:
        Exit code (0 = success, 1 = error)
    """
    try:
        logger.info(f"Reading text from: {text_file_path}")

        # Read text from file
        with open(text_file_path, 'r', encoding='utf-8') as f:
            text = f.read()

        if not text:
            logger.warning("Text file is empty, nothing to type")
            return 0

        logger.info(f"Typing {len(text)} characters")

        # Type the text (fast, no delays)
        type_text_fast(text)

        logger.info("Typing completed successfully")
        return 0

    except FileNotFoundError:
        logger.error(f"Text file not found: {text_file_path}")
        return 1
    except Exception as e:
        logger.exception(f"Error typing text: {e}")
        return 1


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python type_from_file.py <text_file_path>", file=sys.stderr)
        sys.exit(1)

    text_file_path = sys.argv[1]
    exit_code = main(text_file_path)
    sys.exit(exit_code)
