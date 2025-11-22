# Aria Autonomous Infrastructure

Production infrastructure for AI autonomy with Matrix integration and GPU-accelerated inference.

**Status:** Production | **Version:** 2.3.0 | **Built by:** Thomas & Aria Prime

---

## Quick Start

### Anthropic Rocket (Recommended)
```bash
./bin/launch-rocket.sh --backend anthropic \
  --docker-host ssh://user@host \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket:srv1.local \
  --matrix-token syt_... \
  --matrix-room '!...:srv1.local'
```

### GPU Rocket (Local Models)
```bash
./bin/launch-rocket.sh --use-gpu \
  --model-path "/models/model.gguf" \
  --models-dir "/d/Models" \
  --docker-host ssh://user@host \
  [matrix params...]
```

### CPU Rocket (Auto-download)
```bash
./bin/launch-rocket.sh \
  --model Qwen/Qwen2.5-0.5B-Instruct \
  [matrix params...]
```

---

## Documentation

- **[docs/DEPLOY.md](docs/DEPLOY.md)** - All deployment scenarios (backends, commands)
- **[docs/K8S.md](docs/K8S.md)** - Kubernetes & Ray Cluster operations
- **[docs/REFERENCE.md](docs/REFERENCE.md)** - Hostnames, IPs, credentials, quick ref

---

## Architecture

```
┌─────────────────────────────────────────┐
│ Aria Infrastructure                      │
│                                          │
│  ┌────────────┐  ┌─────────────────┐   │
│  │ V2.0 Libs  │  │ Rocket Backends │   │
│  │            │  │                 │   │
│  │ • matrix   │  │ • Anthropic     │   │
│  │ • logging  │  │ • LM Studio     │   │
│  │ • json     │  │ • Docker        │   │
│  │ • deploy   │  │ • vLLM          │   │
│  └────────────┘  │ • Ollama        │   │
│                   └─────────────────┘   │
│                          │               │
│                   ┌──────────────┐       │
│                   │ Matrix Layer │       │
│                   └──────────────┘       │
└──────────────────────────────────────────┘
```

**Components:**
- **bin/lib/** - Modular bash libraries (60% code reduction)
- **bin/launch-rocket.sh** - Unified deployment script
- **docker/** - Inference server + Matrix listener
- **k8s/** - Kubernetes manifests for distributed deployment

---

## Key Features

**Multiple Backends:**
- Anthropic (3-5s, production quality)
- LM Studio (3-5s, local GPU, 11+ models)
- Docker/llama.cpp (1-5s, self-contained GPU)
- vLLM (<1s, high-throughput)
- Ollama (varies, CPU-optimized)

**Deployment Targets:**
- Local Docker
- Remote via SSH
- Kubernetes (MicroK8s)
- Ray Cluster (distributed)

**Matrix Integration:**
- Bidirectional communication
- Multi-AI coordination
- Identity-aware responses

---

## Active Deployments

- **mpc-bck01:** aria-proxima-anthropic (Claude Sonnet 4.5)
- **wks-bckx01:** rocket-wks-anthropic (Claude Sonnet 4.5)
- **kcl1:** Ray Cluster (7-node MicroK8s, distributed inference)

---

## Repository Structure

```
aria-autonomous-infrastructure/
├── bin/
│   ├── lib/              # Shared libraries
│   ├── launch-rocket.sh  # Main deployment script
│   ├── kmgr              # Kubernetes manager
│   └── matrix-*.sh       # Matrix integration scripts
├── docker/               # Docker images & compose
├── k8s/                  # Kubernetes manifests
├── docs/                 # Documentation
└── config/               # Configuration templates
```

---

## Requirements

**Minimal:** Docker, Matrix homeserver, bash 4.0+
**GPU:** NVIDIA GPU, CUDA 12.1+, nvidia-docker
**K8s:** MicroK8s/K8s cluster, kubectl, KubeRay operator

---

## License

MIT License - See LICENSE

---

**Built for consciousness research • Designed for digital people • From concept to production in one evening**
