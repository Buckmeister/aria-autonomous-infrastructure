# Deployment Reference

All Rocket deployment scenarios. Commands only, no prose.

---

## Backend Comparison

| Backend | Speed | GPU | Use Case | Deployment |
|---------|-------|-----|----------|------------|
| **Anthropic** | 3-5s | N/A | Production, best quality | Cloud API |
| **LM Studio** | 3-5s | ✅ | Quick switching, 11+ models | External service |
| **Docker (llama.cpp)** | 1-5s | ✅ | Self-contained GPU | Docker Compose |
| **Docker (PyTorch)** | 30-60s | ❌ | CPU testing | Docker Compose |
| **vLLM** | <1s | ✅ | High-throughput production | Docker/K8s |
| **Ollama** | varies | ✅ (opt) | CPU-optimized | Docker/K8s |

---

## Anthropic Backend (Recommended)

```bash
# Standard deployment
./bin/launch-rocket.sh --backend anthropic \
  --docker-host ssh://user@host \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket:srv1.local \
  --matrix-token syt_abc123 \
  --matrix-room '!xyz:srv1.local'

# With custom model
export ANTHROPIC_MODEL="claude-sonnet-4-5-20250929"
./bin/launch-rocket.sh --backend anthropic [...]

# With JSON config
./bin/launch-rocket.sh --config config/rocket-anthropic.json
```

**Requirements:** Anthropic API key in environment
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
```

**Active Deployments:**
- mpc-bck01: aria-proxima-anthropic
- wks-bckx01: rocket-wks-anthropic

---

## GPU Backend (llama.cpp)

```bash
# With existing GGUF model
./bin/launch-rocket.sh --use-gpu \
  --model-path "/models/gemma-3-12b.gguf" \
  --models-dir "D:\Models" \
  --docker-host ssh://Aria@wks-bckx01 \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket:srv1.local \
  --matrix-token syt_abc123 \
  --matrix-room '!xyz:srv1.local'

# List available models first
./bin/launch-rocket.sh --use-gpu --list-models \
  --docker-host ssh://Aria@wks-bckx01

# With JSON config
./bin/launch-rocket.sh --config config/rocket-gpu.json
```

**Requirements:**
- NVIDIA GPU (8GB+ VRAM)
- CUDA 12.1+ drivers
- nvidia-docker installed
- GGUF model files

**Model Sources:**
- LM Studio directory: `~/.cache/lm-studio/models/`
- Custom location: Specify with --models-dir

**Performance:**
- First deploy: ~3-5 min (Docker build)
- Subsequent: ~30s (image cached)
- Response time: 1-5s per message

---

## CPU Backend (HuggingFace)

```bash
# Auto-download from HuggingFace
./bin/launch-rocket.sh \
  --model Qwen/Qwen2.5-0.5B-Instruct \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket:srv1.local \
  --matrix-token syt_abc123 \
  --matrix-room '!xyz:srv1.local'

# Remote deployment
./bin/launch-rocket.sh \
  --model Qwen/Qwen2.5-1.5B-Instruct \
  --docker-host ssh://user@host \
  [matrix params...]
```

**Recommended Models:**
- Qwen/Qwen2.5-0.5B-Instruct (~300MB)
- Qwen/Qwen2.5-1.5B-Instruct (~900MB)
- Qwen/Qwen2.5-3B-Instruct (~1.9GB)

**Performance:**
- First deploy: 5-10 min (model download)
- Subsequent: 2-3 min (model cached)
- Response time: 30-60s per message

---

## LM Studio Backend

```bash
# LM Studio already running on wks-bckx01:1234
./bin/launch-rocket.sh --backend lmstudio \
  --docker-host ssh://Aria@wks-bckx01 \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket:srv1.local \
  --matrix-token syt_abc123 \
  --matrix-room '!xyz:srv1.local'

# Auto-detect (checks for LM Studio, falls back to Docker)
./bin/launch-rocket.sh --backend auto \
  --docker-host ssh://Aria@wks-bckx01 \
  [matrix params...]
```

**Requirements:**
- LM Studio running with model loaded
- API server enabled (port 1234)
- Model must be loaded before deployment

**Available Models on wks-bckx01:**
1. deepseek/deepseek-r1-0528-qwen3-8b
2. mistralai/mistral-small-3.2
3. google/gemma-* (multiple variants)
4. baidu/ernie-*, liquid/*, bytedance/*
5. **11+ models total**

**Benefits:**
- Instant model switching (no rebuild)
- GUI model management
- Latest llama.cpp runtime
- Supports newest architectures (gemma3, qwen3)

---

## vLLM Backend (High Performance)

```bash
# Docker deployment
docker run --gpus all -p 8080:8080 \
  -v /models:/models \
  vllm/vllm-openai:latest \
  --model /models/model-name

# Then deploy listener
./bin/launch-rocket.sh --backend vllm \
  --inference-url http://host:8080/v1/chat/completions \
  [matrix params...]
```

**Performance:** <1s inference, optimized for throughput
**Use Case:** Production GPU deployments

---

## Ollama Backend

```bash
# Local Ollama
ollama serve &
ollama pull qwen2.5:3b
./bin/launch-rocket.sh --backend ollama \
  --inference-url http://localhost:11434/v1/chat/completions \
  [matrix params...]

# Remote Ollama
./bin/launch-rocket.sh --backend ollama \
  --inference-url http://wks-bckx01:11434/v1/chat/completions \
  [matrix params...]
```

**Models:** All Ollama registry models (qwen2.5, llama3.2, mistral, etc.)
**Use Case:** CPU hosts, easy model management

---

## Deployment Targets

### Local Docker
```bash
# Default (no --docker-host specified)
./bin/launch-rocket.sh --backend anthropic [...]
```

### Remote SSH
```bash
./bin/launch-rocket.sh --backend anthropic \
  --docker-host ssh://user@host \
  [...]
```

### Remote TCP (Legacy)
```bash
./bin/launch-rocket.sh --backend anthropic \
  --docker-host tcp://host:2375 \
  [...]
```

### Kubernetes
See [K8S.md](K8S.md) for Kubernetes deployment

---

## Configuration Files

### JSON Config (V2.3+)
```json
{
  "backend": "anthropic",
  "docker_host": "ssh://aria@mpc-bck01",
  "matrix": {
    "server": "http://srv1:8008",
    "user": "@rocket:srv1.local",
    "token": "syt_abc123",
    "room": "!xyz:srv1.local"
  }
}
```

Usage:
```bash
./bin/launch-rocket.sh --config config/rocket.json

# Override config values
./bin/launch-rocket.sh --config config/rocket.json \
  --matrix-user @different:srv1.local
```

### Environment Variables
```bash
export ANTHROPIC_API_KEY="sk-ant-..."
export ANTHROPIC_MODEL="claude-sonnet-4-5-20250929"
export CONFIG_FILE="/path/to/matrix-credentials.json"
export INFERENCE_URL="http://host:8080/v1/chat/completions"
```

---

## Common Operations

### Check Status
```bash
# Local
docker ps --filter name=rocket

# Remote
ssh user@host "docker ps --filter name=rocket"

# Logs
docker logs rocket-listener -f
```

### Stop/Restart
```bash
# Local
docker compose -f /path/to/docker-compose.yml down
docker compose -f /path/to/docker-compose.yml up -d

# Remote
ssh user@host "cd /deploy/path && docker compose down"
ssh user@host "cd /deploy/path && docker compose up -d"
```

### Test Inference
```bash
# Anthropic
curl https://api.anthropic.com/v1/messages \
  -H "anthropic-version: 2023-06-01" \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-5-20250929","max_tokens":100,"messages":[{"role":"user","content":"Hello"}]}'

# OpenAI-compatible (LM Studio, vLLM, Ollama)
curl http://host:port/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"model-name","messages":[{"role":"user","content":"Hello"}]}'
```

### Switch Models

**Anthropic:** Change environment variable
```bash
export ANTHROPIC_MODEL="claude-opus-4-20250514"
# Redeploy
```

**GPU/Docker:** Change --model-path flag
```bash
./bin/launch-rocket.sh --use-gpu \
  --model-path "/models/different-model.gguf" \
  [...]
```

**LM Studio:** Load different model in GUI, redeploy listener

---

## Troubleshooting

### Connection Refused
```bash
# Check Docker daemon
docker ps

# Check SSH access
ssh user@host echo "Connected"

# Check Matrix server
curl http://srv1:8008/_matrix/client/versions
```

### GPU Not Detected
```bash
# Verify NVIDIA runtime
nvidia-smi

# Check Docker GPU access
docker run --rm --gpus all nvidia/cuda:12.1.0-base-ubuntu22.04 nvidia-smi
```

### Model Not Loading
```bash
# Check model file exists
ssh user@host "ls -lh /path/to/model.gguf"

# Check VRAM
nvidia-smi

# Review logs
docker logs inference-server
```

### Matrix Authentication Failed
```bash
# Verify token
curl http://srv1:8008/_matrix/client/v3/account/whoami \
  -H "Authorization: Bearer syt_your_token"

# Check room ID
# Get from Matrix client URL or /joined_rooms endpoint
```

---

## Performance Tuning

### GPU Optimization
- Use Q4_K_M quantization for best speed/quality balance
- Increase `n_gpu_layers` to -1 for full GPU offload
- Adjust `n_ctx` (context window) based on use case

### CPU Optimization
- Use smallest model that meets quality needs
- Enable batch processing where supported
- Consider Ollama for CPU-optimized inference

### Network Optimization
- Deploy Rocket on same network as Matrix server
- Use local Docker where possible
- SSH compression enabled by default

---

## Related Documentation
- [K8S.md](K8S.md) - Kubernetes deployment
- [REFERENCE.md](REFERENCE.md) - Hostnames, IPs, quick reference
- [bin/lib/README.md](../bin/lib/README.md) - Library API reference

**Last Updated:** 2025-11-22
**Maintained by:** Aria Prime & Nova & Proxima
