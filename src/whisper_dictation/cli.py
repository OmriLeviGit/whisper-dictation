"""Command-line interface for Whisper Dictation."""

import os
import subprocess
import sys
import time
from pathlib import Path


def get_project_root() -> Path:
    """Get the project root directory."""
    # When installed, this will be in site-packages/whisper_dictation/
    # We need to find the actual project root with docker/ and config/
    current = Path(__file__).parent

    # Check if we're in development (editable install)
    if (current.parent.parent / "docker").exists():
        return current.parent.parent

    # In production, config and docker should be in user's working directory
    # or we use the current working directory
    return Path.cwd()


def run_command(cmd: list, check: bool = True, capture_output: bool = False, shell: bool = False):
    """Run a command and handle errors. Returns True on success, False on failure."""
    try:
        if capture_output:
            result = subprocess.run(
                cmd,
                check=check,
                capture_output=True,
                text=True,
                shell=shell
            )
            return result
        else:
            result = subprocess.run(cmd, check=check, shell=shell)
            return True
    except subprocess.CalledProcessError as e:
        if capture_output and e.stderr:
            print(f"ERROR: {e.stderr}", file=sys.stderr)
        return False


def setup():
    """Run initial setup for Whisper Dictation."""
    print("=" * 40)
    print("   Whisper Dictation - Initial Setup")
    print("=" * 40)
    print()

    # Step 1: Sync Python dependencies
    print("[1/3] Syncing Python dependencies...")
    result = run_command(
        ["uv", "sync"],
        check=False,
        capture_output=True
    )
    if not result or result.returncode != 0:
        print("ERROR: Failed to sync Python dependencies!")
        print("Please install uv and try again.")
        sys.exit(1)
    print("Done.")
    print()

    # Step 2: Check if Docker is running
    print("[2/3] Checking Docker...")
    retries = 0
    max_retries = 4

    while retries < max_retries:
        result = run_command(
            ["docker", "info"],
            check=False,
            capture_output=True
        )
        if result and result.returncode == 0:
            print("Docker is running.")
            print()
            break

        retries += 1
        if retries >= max_retries:
            print("ERROR: Docker is not running!")
            print("Please start Docker Desktop and try again.")
            sys.exit(1)

        print(f"Docker not ready, waiting 60 seconds... (retry {retries}/3)")
        time.sleep(60)

    # Step 3: Build and start Whisper service
    print("[3/3] Building and starting Whisper service...")
    print("This may take a few minutes on first run...")

    project_root = get_project_root()
    docker_compose_file = project_root / "docker" / "docker-compose.yml"
    env_file = project_root / "config" / "service.env"

    success = run_command(
        [
            "docker-compose",
            "-f", str(docker_compose_file),
            "--env-file", str(env_file),
            "up", "-d", "--build"
        ],
        check=False
    )
    if not success:
        print("ERROR: Failed to start Docker service!")
        sys.exit(1)
    print()

    # Wait for service to be ready
    print("Waiting for service to be healthy...")
    time.sleep(10)
    print()

    print("=" * 40)
    print("   Setup Complete!")
    print("=" * 40)
    print()
    print("Starting dictation hotkey...")
    start()
    print()
    print("The Docker container will auto-start on system reboot.")
    print("To customize settings, check config/client.env and config/service.env")
    print()


def start():
    """Start the Whisper Dictation hotkey."""
    print("Starting Whisper Dictation...")

    project_root = get_project_root()
    ahk_script = project_root / "scripts" / "hold_to_record.ahk"

    # Stop any existing instances
    run_command(
        ["taskkill", "/F", "/IM", "AutoHotkey64.exe", "/FI", "WINDOWTITLE eq hold_to_record.ahk*"],
        check=False,
        capture_output=True
    )

    # Start the hotkey script
    run_command(
        ["start", "", str(ahk_script)],
        shell=True
    )

    print()
    print("Whisper Dictation hotkey is now active!")
    print("Check your system tray for hotkey details.")
    time.sleep(1)


def stop():
    """Stop Whisper Dictation."""
    print("Stopping Whisper Dictation...")
    print()

    # Kill AutoHotkey process
    print("Stopping dictation hotkey...")
    result = run_command(
        ["taskkill", "/F", "/IM", "AutoHotkey64.exe"],
        check=False,
        capture_output=True
    )
    if result and result.returncode == 0:
        print("AutoHotkey stopped.")
    else:
        print("AutoHotkey was not running.")

    # Stop Docker service
    print("Stopping Whisper service...")
    project_root = get_project_root()
    docker_compose_file = project_root / "docker" / "docker-compose.yml"
    env_file = project_root / "config" / "service.env"

    run_command(
        [
            "docker-compose",
            "-f", str(docker_compose_file),
            "--env-file", str(env_file),
            "down"
        ]
    )

    print()
    print("Whisper Dictation stopped.")
    print()


def service():
    """Start the Whisper FastAPI service directly (for development)."""
    print("Starting Whisper service...")
    print("Press Ctrl+C to stop")
    print()

    try:
        # Import and run the service
        from whisper_dictation import whisper_service
        # The service will be started by uvicorn when imported
        # This is mainly for development/debugging
        print("Service running at http://localhost:8000")
        print("API docs available at http://localhost:8000/docs")

        # Keep running
        import uvicorn
        uvicorn.run(
            "whisper_dictation.whisper_service:app",
            host="0.0.0.0",
            port=8000,
            reload=True
        )
    except KeyboardInterrupt:
        print("\nService stopped.")
        sys.exit(0)


def main():
    """Main entry point for debugging."""
    import sys
    if len(sys.argv) < 2:
        print("Usage: python -m whisper_dictation.cli <setup|start|stop|service>")
        sys.exit(1)

    command = sys.argv[1]
    if command == "setup":
        setup()
    elif command == "start":
        start()
    elif command == "stop":
        stop()
    elif command == "service":
        service()
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()
