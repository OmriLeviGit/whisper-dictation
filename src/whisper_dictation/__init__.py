"""Whisper Dictation - Hold-to-record audio transcription."""

__version__ = "0.1.0"

# Lazy imports to avoid requiring optional dependencies at import time
__all__ = [
    "load_config",
    "record",
    "transcribe",
    "transcribe_client",
    "whisper_service",
    "cli",
]

def __getattr__(name):
    """Lazy import modules to avoid loading heavy dependencies."""
    if name in __all__:
        import importlib
        module = importlib.import_module(f".{name}", __package__)
        globals()[name] = module
        return module
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
