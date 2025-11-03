"""
Whisper Transcription Service
FastAPI service for GPU-accelerated audio transcription using faster-whisper
"""

import os
import tempfile
import logging
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from faster_whisper import WhisperModel

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Initialize FastAPI app
app = FastAPI(
    title="Whisper Transcription Service",
    description="GPU-accelerated audio transcription using faster-whisper",
    version="1.0.0"
)

# Global model instance (loaded on startup)
model: Optional[WhisperModel] = None

# Model configuration
MODEL_SIZE = "large-v3"
DEVICE = "cuda"
COMPUTE_TYPE = "float16"
MODEL_CACHE_DIR = "/models"


@app.on_event("startup")
async def load_model():
    """Load Whisper model on service startup"""
    global model
    try:
        logger.info(f"Loading Whisper model: {MODEL_SIZE} on {DEVICE}")
        model = WhisperModel(
            MODEL_SIZE,
            device=DEVICE,
            compute_type=COMPUTE_TYPE,
            download_root=MODEL_CACHE_DIR
        )
        logger.info("Model loaded successfully")
    except Exception as e:
        logger.error(f"Failed to load model: {e}")
        raise


@app.get("/")
async def root():
    """Service information endpoint"""
    return {
        "service": "Whisper Transcription Service",
        "model": MODEL_SIZE,
        "device": DEVICE,
        "status": "ready" if model else "not_ready"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint for Docker"""
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")
    return {"status": "healthy"}


async def _do_transcription(file: UploadFile):
    """
    Internal function to perform transcription
    Returns dict with transcription results
    """
    if model is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    # Validate file extension
    allowed_extensions = {".wav", ".mp3", ".m4a", ".flac", ".ogg", ".opus", ".webm"}
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file format: {file_ext}. Allowed: {', '.join(allowed_extensions)}"
        )

    # Save uploaded file temporarily
    temp_path = None
    try:
        with tempfile.NamedTemporaryFile(delete=False, suffix=file_ext) as temp_file:
            content = await file.read()
            temp_file.write(content)
            temp_path = temp_file.name

        logger.info(f"Transcribing file: {file.filename} ({len(content)} bytes)")

        # Transcribe audio
        segments, info = model.transcribe(
            temp_path,
            beam_size=5,
            best_of=5,
            temperature=0.0,
            vad_filter=False,
            language=None  # Auto-detect language
        )

        # Collect segments and build full transcription
        transcription_segments = []
        full_text = []

        for segment in segments:
            transcription_segments.append({
                "start": round(segment.start, 2),
                "end": round(segment.end, 2),
                "text": segment.text.strip()
            })
            full_text.append(segment.text.strip())

        result = {
            "text": " ".join(full_text),
            "language": info.language,
            "language_probability": round(info.language_probability, 4),
            "duration": round(info.duration, 2),
            "segments": transcription_segments
        }

        logger.info(f"Transcription complete: {len(full_text)} segments, language={info.language}")

        return result

    except Exception as e:
        logger.error(f"Transcription error: {e}")
        raise HTTPException(status_code=500, detail=f"Transcription failed: {str(e)}")

    finally:
        # Clean up temporary file
        if temp_path and os.path.exists(temp_path):
            os.unlink(temp_path)


@app.post("/transcribe")
async def transcribe(file: UploadFile = File(...)):
    """
    Transcribe audio file to text

    Accepts: WAV, MP3, M4A, FLAC, OGG, OPUS, WEBM
    Returns: Transcription with language detection and segments
    """
    result = await _do_transcription(file)
    return JSONResponse(content=result)


@app.post("/transcribe/simple")
async def transcribe_simple(file: UploadFile = File(...)):
    """
    Simple transcription endpoint - returns only the text

    Accepts: WAV, MP3, M4A, FLAC, OGG, OPUS, WEBM
    Returns: Plain text transcription
    """
    result = await _do_transcription(file)
    return {"text": result["text"]}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=58432)
