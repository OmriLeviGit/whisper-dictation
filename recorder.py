"""
Simple audio recorder using sounddevice for hold-to-record functionality
"""
import sounddevice as sd
import soundfile as sf
import numpy as np
import sys
import os
import signal
import atexit
from datetime import datetime

# Set up logging
LOG_FILE = os.path.join(os.environ.get('TEMP', '.'), 'whisper_dictation', 'recorder.log')

def log(message):
    """Write debug messages to log file"""
    try:
        os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
        with open(LOG_FILE, 'a', encoding='utf-8') as f:
            timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            f.write(f"[{timestamp}] {message}\n")
            f.flush()
    except Exception as e:
        print(f"Logging error: {e}", file=sys.stderr)

def list_devices():
    """List all available audio input devices"""
    print("\nAvailable audio input devices:")
    print("-" * 60)
    devices = sd.query_devices()
    for i, device in enumerate(devices):
        if device['max_input_channels'] > 0:
            print(f"[{i}] {device['name']}")
            print(f"    Channels: {device['max_input_channels']}, Sample Rate: {device['default_samplerate']} Hz")
    print("-" * 60)

# Global variables for signal handling
recording_data = []
output_path = None
sample_rate = 44100

def save_recording():
    """Save the recording to file - called on exit"""
    global recording_data, output_path, sample_rate

    if recording_data and output_path:
        try:
            log(f"Saving {len(recording_data)} audio chunks")
            audio_data = np.concatenate(recording_data, axis=0)

            # Create directory if it doesn't exist
            output_dir = os.path.dirname(output_path)
            if output_dir:  # Only create if there's a directory path
                os.makedirs(output_dir, exist_ok=True)

            # Save to WAV file
            sf.write(output_path, audio_data, sample_rate)

            duration = len(audio_data) / sample_rate
            log(f"Recording saved: {output_path}, Duration: {duration:.2f}s")
            print(f"\nRecording saved: {output_path}")
            print(f"Duration: {duration:.2f} seconds")
        except Exception as e:
            log(f"Error saving recording: {e}")
    elif output_path:
        log("No audio data recorded")

def signal_handler(signum, frame):
    """Handle termination signals"""
    log(f"Received signal {signum}, saving recording...")
    save_recording()
    sys.exit(0)

def record_audio(output_file, device=None, samplerate=44100, channels=1):
    """
    Record audio until stop flag file is detected or process is killed

    Args:
        output_file: Path to save the WAV file
        device: Device ID or name (None for default)
        samplerate: Sample rate in Hz
        channels: Number of audio channels
    """
    global recording_data, output_path, sample_rate

    output_path = output_file
    sample_rate = samplerate
    recording_data = []
    chunk_counter = 0

    # Derive stop flag file path from output file
    # e.g., recording_20251102.wav -> recording_20251102.stop
    stop_flag_file = os.path.splitext(output_file)[0] + '.stop'

    # Register signal handlers (backup mechanism)
    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)
    atexit.register(save_recording)

    log(f"Starting recording to: {output_file}")
    log(f"Stop flag file: {stop_flag_file}")
    log(f"Sample rate: {samplerate} Hz, Channels: {channels}, Device: {device}")

    print(f"Recording to: {output_file}")
    print(f"Sample rate: {samplerate} Hz, Channels: {channels}")
    if device is not None:
        print(f"Using device: {device}")
    print("Recording... (will stop when key is released)")

    def callback(indata, frames, time, status):
        """Called for each audio block"""
        nonlocal chunk_counter
        if status:
            log(f"Audio callback status: {status}")
            print(f"Status: {status}", file=sys.stderr)
        recording_data.append(indata.copy())
        chunk_counter += 1

        # Save every 10 chunks (~0.2 seconds) to ensure data isn't lost
        if chunk_counter % 10 == 0:
            save_recording()
            log(f"Incremental save at {len(recording_data)} chunks")

    try:
        # Start recording
        log("Opening audio stream...")
        with sd.InputStream(samplerate=samplerate, channels=channels,
                          callback=callback, device=device):
            log("Audio stream opened, recording started")

            # Keep recording until stop flag file is detected
            check_counter = 0
            while True:
                sd.sleep(100)  # Sleep 100ms
                check_counter += 1

                # Check for stop flag every 200ms (2 iterations)
                if check_counter >= 2:
                    check_counter = 0
                    if os.path.exists(stop_flag_file):
                        log(f"Stop flag detected: {stop_flag_file}")
                        print("\nStop signal received, finishing recording...")
                        # Clean up flag file
                        try:
                            os.remove(stop_flag_file)
                            log("Stop flag file removed")
                        except Exception as e:
                            log(f"Error removing stop flag: {e}")
                        break

    except KeyboardInterrupt:
        log("Recording stopped by KeyboardInterrupt")
        print("\nRecording stopped by user")
    except Exception as e:
        log(f"Recording stopped with exception: {e}")
        print(f"\nRecording stopped: {e}", file=sys.stderr)
    finally:
        # Clean up stop flag file if it still exists
        try:
            if os.path.exists(stop_flag_file):
                os.remove(stop_flag_file)
                log("Stop flag file cleaned up in finally block")
        except Exception as e:
            log(f"Error cleaning up stop flag in finally: {e}")

def main():
    log(f"Script started with args: {sys.argv}")

    if len(sys.argv) < 2:
        log("No arguments provided")
        print("Usage:")
        print("  python recorder.py <output_file.wav> [device_id]")
        print("  python recorder.py --list-devices")
        print("\nExample:")
        print("  python recorder.py recording.wav")
        print("  python recorder.py recording.wav 1")
        sys.exit(1)

    if sys.argv[1] == "--list-devices":
        list_devices()
        sys.exit(0)

    output_file = sys.argv[1]
    device = None

    if len(sys.argv) > 2:
        try:
            device = int(sys.argv[2])
        except ValueError:
            device = sys.argv[2]  # Try as device name

    try:
        record_audio(output_file, device=device)
    except Exception as e:
        log(f"Fatal error in main: {e}")
        raise

if __name__ == "__main__":
    main()
