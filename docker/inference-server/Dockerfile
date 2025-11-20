# Rocket GPU Inference Server - llama.cpp with CUDA support
FROM nvidia/cuda:12.1.0-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_DOCKER_ARCH=all
ENV LLAMA_CUBLAS=1

# Install dependencies
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    build-essential \
    cmake \
    && rm -rf /var/lib/apt/lists/*

# Upgrade pip
RUN python3 -m pip install --upgrade pip

# Install llama-cpp-python with CUDA support
RUN CMAKE_ARGS="-DLLAMA_CUBLAS=on" pip install llama-cpp-python[server]==0.3.2 --force-reinstall --no-cache-dir

# Install additional dependencies
RUN pip install --no-cache-dir \
    uvicorn \
    fastapi \
    pydantic-settings \
    sse-starlette

# Create app directory
WORKDIR /app

# Copy inference server script
COPY inference_server.py /app/

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python3 -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

# Run server
CMD ["python3", "inference_server.py"]
