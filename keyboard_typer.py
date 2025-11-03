"""
Keyboard Typer
Simulates keyboard input to type transcribed text at the current cursor position
"""

import logging
import time
from pynput.keyboard import Controller, Key

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize keyboard controller
keyboard = Controller()

# Typing configuration
TYPING_DELAY = 0.01  # Delay between characters (seconds)
INITIAL_DELAY = 0.2  # Initial delay before starting to type (seconds)


def type_text(text: str, delay: float = TYPING_DELAY) -> None:
    """
    Type text at the current cursor position

    Args:
        text: The text to type
        delay: Delay between each character (default: 0.01 seconds)
    """
    if not text:
        logger.warning("No text to type")
        return

    # Small delay to ensure focus is on the target window
    time.sleep(INITIAL_DELAY)

    logger.info(f"Typing {len(text)} characters")

    try:
        for char in text:
            keyboard.type(char)
            if delay > 0:
                time.sleep(delay)

        logger.info("Typing completed successfully")

    except Exception as e:
        logger.error(f"Error while typing: {e}")
        raise


def type_text_fast(text: str) -> None:
    """
    Type text quickly without delays (except initial delay)

    Args:
        text: The text to type
    """
    type_text(text, delay=0)


if __name__ == "__main__":
    import sys

    if len(sys.argv) < 2:
        print("Usage: python keyboard_typer.py <text_to_type>")
        sys.exit(1)

    text = " ".join(sys.argv[1:])
    print(f"Typing: {text}")
    print("Switch to target window now...")
    time.sleep(3)  # Give user time to switch windows

    try:
        type_text(text)
        print("Done!")
    except Exception as e:
        print(f"Error: {e}")
        sys.exit(1)
