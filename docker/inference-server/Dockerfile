# Rocket GPU Inference Server - llama.cpp with CUDA support
# Using CUDA 12.6 (latest available that's compatible with 12.9 host)
FROM nvidia/cuda:12.6.2-devel-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV CUDA_DOCKER_ARCH=all
ENV GGML_CUDA=1
ENV CUDA_HOME=/usr/local/cuda
ENV PATH=${CUDA_HOME}/bin:${PATH}
ENV LD_LIBRARY_PATH=${CUDA_HOME}/lib64:${LD_LIBRARY_PATH}

# Install dependencies
# Note: CUDA libraries already included in nvidia/cuda:12.6.2-devel-ubuntu22.04 base image
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
# Explicit CUDA paths and linker flags directly in CMAKE_ARGS
# Note: Using stubs directory for libcuda.so during build (real driver available at runtime)
RUN CMAKE_ARGS="-DGGML_CUDA=on -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc -DCUDA_TOOLKIT_ROOT_DIR=/usr/local/cuda -DCMAKE_EXE_LINKER_FLAGS='-L/usr/local/cuda/lib64/stubs -lcuda' -DCMAKE_SHARED_LINKER_FLAGS='-L/usr/local/cuda/lib64/stubs -lcuda'" \
    CUDA_HOME=/usr/local/cuda \
    pip install llama-cpp-python[server]==0.3.2 --force-reinstall --no-cache-dir --verbose

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
