#!/usr/bin/env python3
"""
Rocket GPU Inference Server
Uses llama-cpp-python with CUDA acceleration for GGUF models
"""
import os
import sys

# Configuration from environment variables
MODEL_PATH = os.getenv("MODEL_PATH", "/models/lmstudio-community/gemma-3-12b-it-GGUF/gemma-3-12b-it-Q4_K_M.gguf")
N_GPU_LAYERS = int(os.getenv("N_GPU_LAYERS", "-1"))  # -1 = all layers on GPU
N_CTX = int(os.getenv("N_CTX", "4096"))  # Context window
N_BATCH = int(os.getenv("N_BATCH", "512"))
N_THREADS = int(os.getenv("N_THREADS", "8"))
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8080"))

def main():
    print(f"🚀 Rocket GPU Inference Server Starting...")
    print(f"Model: {MODEL_PATH}")
    print(f"GPU Layers: {N_GPU_LAYERS}")
    print(f"Context Size: {N_CTX}")
    print(f"Host: {HOST}:{PORT}")

    # Check if model file exists
    if not os.path.exists(MODEL_PATH):
        print(f"❌ ERROR: Model file not found: {MODEL_PATH}")
        print("Available models in /models:")
        if os.path.exists("/models"):
            os.system("find /models -name '*.gguf' -type f | head -20")
        sys.exit(1)

    print("✅ Model file found")
    print("🔥 Starting llama.cpp server with CUDA acceleration...")

    # Use llama-cpp-python's built-in server
    # Build command line arguments
    import subprocess
    cmd = [
        "python3", "-m", "llama_cpp.server",
        "--model", MODEL_PATH,
        "--n_gpu_layers", str(N_GPU_LAYERS),
        "--n_ctx", str(N_CTX),
        "--n_batch", str(N_BATCH),
        "--host", HOST,
        "--port", str(PORT),
        "--chat_format", "chatml",  # Override model's chat template to avoid strftime_now issues
    ]

    print(f"Command: {' '.join(cmd)}")

    # Run the server
    subprocess.run(cmd)

if __name__ == "__main__":
    main()
