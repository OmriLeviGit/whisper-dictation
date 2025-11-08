FROM nvidia/cuda:12.6.0-cudnn-devel-ubuntu22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install Python 3.11 and dependencies
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-dev \
    python3.11-venv \
    python3-pip \
    ffmpeg \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set Python 3.11 as default
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 1

# Install pip for Python 3.11
RUN curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# Upgrade pip
RUN python3.11 -m pip install --no-cache-dir --upgrade pip

# Install Python packages
RUN python3.11 -m pip install --no-cache-dir \
    faster-whisper>=1.0.0 \
    fastapi>=0.109.0 \
    uvicorn[standard]>=0.27.0 \
    python-multipart>=0.0.6

# Create working directory
WORKDIR /app

# Copy the package files needed for installation
COPY pyproject.toml /app/
COPY README.md /app/
COPY src/ /app/src/

# Install the package
RUN python3.11 -m pip install --no-cache-dir /app

# Create model cache directory
RUN mkdir -p /models

# Expose API port (configurable via environment)
ARG WHISPER_PORT=58432
EXPOSE ${WHISPER_PORT}

# Environment variables (can be overridden in docker-compose)
ENV WHISPER_PORT=${WHISPER_PORT}
ENV WHISPER_MODEL=large-v3
ENV WHISPER_DEVICE=cuda
ENV WHISPER_COMPUTE_TYPE=float16
ENV MODEL_CACHE_DIR=/models

# Run the service using the installed package
CMD uvicorn whisper_dictation.whisper_service:app --host 0.0.0.0 --port ${WHISPER_PORT}
