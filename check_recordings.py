import os
import glob
from pathlib import Path

temp_dir = os.path.join(os.environ['TEMP'], 'whisper_dictation')
print(f"Checking directory: {temp_dir}")
print()

if os.path.exists(temp_dir):
    wav_files = glob.glob(os.path.join(temp_dir, "*.wav"))
    if wav_files:
        print(f"Found {len(wav_files)} recording(s):")
        print()
        for file in sorted(wav_files, key=os.path.getmtime, reverse=True):
            size = os.path.getsize(file)
            mtime = os.path.getmtime(file)
            from datetime import datetime
            timestamp = datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M:%S')
            print(f"  {os.path.basename(file)}")
            print(f"    Size: {size:,} bytes ({size/1024:.2f} KB)")
            print(f"    Modified: {timestamp}")
            print()
    else:
        print("No WAV files found in directory.")
else:
    print("Directory does not exist yet.")
