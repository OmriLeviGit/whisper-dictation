import os

log_file = os.path.join(os.environ['TEMP'], 'whisper_dictation', 'recorder.log')

if os.path.exists(log_file):
    print(f"Log file: {log_file}")
    print("=" * 60)
    with open(log_file, 'r', encoding='utf-8') as f:
        print(f.read())
else:
    print(f"No log file found at: {log_file}")
