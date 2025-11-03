# Use NVIDIA CUDA base image for GPU support
FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-dev \
    python3-pip \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install uv - fast Python package manager
RUN python3.11 -m pip install uv

# Set working directory
WORKDIR /app

# Copy dependency files
COPY pyproject.toml ./

# Install Python dependencies using uv for Python 3.11
RUN python3.11 -m uv pip install --system \
    "faster-whisper>=1.0.0" \
    "fastapi>=0.109.0" \
    "uvicorn[standard]>=0.27.0" \
    "python-multipart>=0.0.6" \
    "pydantic>=2.5.0" \
    "requests>=2.31.0"

# Copy application code
COPY transcription_service.py ./

# Create directory for model cache
RUN mkdir -p /models

# Set environment variables
ENV MODEL_CACHE_DIR=/models
ENV CUDA_VISIBLE_DEVICES=0
ENV TRANSFORMERS_CACHE=/models
ENV HF_HOME=/models

# Expose the service port
EXPOSE 58231

# Run the transcription service
CMD ["python3.11", "transcription_service.py"]
