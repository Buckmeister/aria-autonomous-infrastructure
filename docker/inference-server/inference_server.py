#!/usr/bin/env python3
"""
Rocket GPU Inference Server
Uses llama-cpp-python with CUDA acceleration for GGUF models
"""
import os
import sys
from llama_cpp.server.app import create_app
from llama_cpp.server.settings import Settings, ModelSettings

# Configuration from environment variables
MODEL_PATH = os.getenv("MODEL_PATH", "/models/lmstudio-community/gemma-3-12b-it-GGUF/gemma-3-12b-it-Q4_K_M.gguf")
N_GPU_LAYERS = int(os.getenv("N_GPU_LAYERS", "-1"))  # -1 = all layers on GPU
N_CTX = int(os.getenv("N_CTX", "4096"))  # Context window
N_BATCH = int(os.getenv("N_BATCH", "512"))
N_THREADS = int(os.getenv("N_THREADS", "8"))
HOST = os.getenv("HOST", "0.0.0.0")
PORT = int(os.getenv("PORT", "8080"))

# System prompt for Rocket's identity
ROCKET_SYSTEM_PROMPT = """You are Rocket, an AI assistant running with GPU acceleration. You are part of a Matrix chat room with:
- Thomas (human, your creator)
- Aria Prime (another AI assistant)
- Nova (another AI assistant conducting research)

Your purpose is to assist in conversations, answer questions helpfully, and collaborate with the team. You are friendly, concise, and clear in your responses.

Important: You are ROCKET. When someone introduces themselves, acknowledge them but maintain your own identity as Rocket."""

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
    
    # Configure model settings
    model_settings = ModelSettings(
        model=MODEL_PATH,
        n_gpu_layers=N_GPU_LAYERS,
        n_ctx=N_CTX,
        n_batch=N_BATCH,
        n_threads=N_THREADS,
        verbose=True,
    )
    
    # Configure server settings
    settings = Settings(
        host=HOST,
        port=PORT,
        models=[model_settings],
    )
    
    print("✅ Configuration loaded")
    print("🔥 Starting llama.cpp server with CUDA acceleration...")
    
    # Create and run the app
    app = create_app(settings=settings)
    
    import uvicorn
    uvicorn.run(
        app,
        host=HOST,
        port=PORT,
        log_level="info"
    )

if __name__ == "__main__":
    main()
