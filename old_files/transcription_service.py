#!/usr/bin/env python3
"""
Faster-Whisper Transcription Service
A lightweight REST API for real-time audio transcription using Faster-Whisper
"""

import os
import tempfile
import logging
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import uvicorn
from faster_whisper import WhisperModel

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Faster-Whisper Transcription Service",
    description="Real-time audio transcription API",
    version="1.0.0"
)

# Global model instance
model: Optional[WhisperModel] = None

# Configuration
MODEL_SIZE = "large-v3"
DEVICE = "cuda"  # Use GPU
COMPUTE_TYPE = "float16"  # Optimized for GPU
MODEL_CACHE_DIR = os.getenv("MODEL_CACHE_DIR", "/models")
PORT = 58231


def initialize_model():
    """Initialize the Faster-Whisper model"""
    global model
    logger.info(f"Loading Faster-Whisper model: {MODEL_SIZE}")
    logger.info(f"Device: {DEVICE}, Compute type: {COMPUTE_TYPE}")
    logger.info(f"Model cache directory: {MODEL_CACHE_DIR}")

    try:
        model = WhisperModel(
            MODEL_SIZE,
            device=DEVICE,
            compute_type=COMPUTE_TYPE,
            download_root=MODEL_CACHE_DIR,
            num_workers=4,  # Optimize for speed
        )
        logger.info("Model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise


@app.on_event("startup")
async def startup_event():
    """Initialize model on startup"""
    initialize_model()


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "status": "online",
        "service": "Faster-Whisper Transcription Service",
        "model": MODEL_SIZE,
        "device": DEVICE,
        "compute_type": COMPUTE_TYPE
    }


@app.get("/health")
async def health_check():
    """Detailed health check"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    return {
        "status": "healthy",
        "model_loaded": model is not None,
        "ready": True
    }


@app.post("/transcribe")
async def transcribe_audio(
    audio: UploadFile = File(...),
    beam_size: int = 5,
    best_of: int = 5,
    temperature: float = 0.0
):
    """
    Transcribe audio file to text

    Parameters:
    - audio: Audio file (wav, mp3, m4a, etc.)
    - beam_size: Beam size for decoding (default: 5)
    - best_of: Number of candidates to consider (default: 5)
    - temperature: Sampling temperature (default: 0.0 for greedy)

    Returns:
    - JSON with transcribed text and metadata
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not initialized")

    # Validate file type
    allowed_extensions = {'.wav', '.mp3', '.m4a', '.flac', '.ogg', '.opus', '.webm'}
    file_extension = Path(audio.filename).suffix.lower()

    if file_extension not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file format: {file_extension}. Allowed: {allowed_extensions}"
        )

    # Save uploaded file to temporary location
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_extension) as temp_file:
            content = await audio.read()
            temp_file.write(content)
            temp_path = temp_file.name

        logger.info(f"Processing audio file: {audio.filename} ({len(content)} bytes)")

        # Transcribe with auto language detection
        segments, info = model.transcribe(
            temp_path,
            beam_size=beam_size,
            best_of=best_of,
            temperature=temperature,
            vad_filter=False,  # Disable VAD - it was filtering out all audio
        )

        # Collect all segments
        transcription = ""
        segment_list = []

        for segment in segments:
            transcription += segment.text
            segment_list.append({
                "start": segment.start,
                "end": segment.end,
                "text": segment.text.strip()
            })

        # Clean up transcription
        transcription = transcription.strip()

        logger.info(f"Transcription completed. Language: {info.language}, "
                   f"Probability: {info.language_probability:.2f}")

        return JSONResponse(content={
            "text": transcription,
            "language": info.language,
            "language_probability": info.language_probability,
            "duration": info.duration,
            "segments": segment_list
        })

    except Exception as e:
        logger.error(f"Transcription error: {e}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

    finally:
        # Clean up temporary file
        try:
            if os.path.exists(temp_path):
                os.unlink(temp_path)
        except Exception as e:
            logger.warning(f"Failed to delete temporary file: {e}")


@app.post("/transcribe/simple")
async def transcribe_simple(audio: UploadFile = File(...)):
    """
    Simple transcription endpoint that returns only text

    Parameters:
    - audio: Audio file

    Returns:
    - Plain text transcription
    """
    result = await transcribe_audio(audio)
    return {"text": result["text"]}


if __name__ == "__main__":
    logger.info(f"Starting Faster-Whisper Transcription Service on port {PORT}")
    uvicorn.run(
        app,
        host="0.0.0.0",
        port=PORT,
        log_level="info",
        access_log=True
    )
