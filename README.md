# Aria Autonomous Infrastructure

> **Production-ready infrastructure for AI autonomy with Matrix integration, modular libraries, and GPU-accelerated conversational AI**

[![Status](https://img.shields.io/badge/status-production-brightgreen.svg)](https://github.com/Buckmeister/aria-autonomous-infrastructure)
[![Version](https://img.shields.io/badge/version-2.3.0-blue.svg)](CHANGELOG.md)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

**Built by:** Thomas & Aria Prime
**Validated with:** Aria Nova (autonomous instance), Rocket (conversational AI)
**Architecture:** V2.0 modular libraries + V2.1 GPU acceleration + V2.2 unified deployment + V2.3 JSON configs

---

## 🌟 What This Is

Complete infrastructure for running autonomous AI instances with **two-way Matrix communication**, **modular library architecture**, and **GPU-accelerated conversational AI**. Deploy production-ready AI assistants in minutes, not hours.

### Key Achievements

**V2.0: Modular Library Architecture** (November 2025)
- 6 shared bash libraries eliminating 60%+ code duplication
- Single source of truth for Matrix operations
- Production-grade error handling and logging
- Complete API documentation

**V2.1: Conversational AI** (November 2025)
- CPU-based: Local LLM inference with identity-aware prompts
- GPU-accelerated: CUDA support with Docker Compose
- Response times: 1-5 seconds (GPU) vs 30-60 seconds (CPU)
- Zero-download deployment using existing model files

**V2.2: Unified Deployment** (November 2025)
- Single `launch-rocket.sh` script for all scenarios (CPU/GPU, local/remote)
- Flags: `--use-gpu`, `--use-compose`, `--docker-host ssh://user@host`
- Backward compatibility with `*-legacy.sh` scripts
- Real-world deployment testing and documentation
- Production-validated remote Docker deployment

**V2.3: Enhanced User Experience** (November 2025)
- `--use-gpu` automatically enables Docker Compose (no redundancy!)
- JSON configuration file support with `--config` flag
- Example configs for GPU and CPU deployments
- Perfect for team collaboration and CI/CD automation
- Command-line options override config file values

---

## 🚀 Quick Start

### Option 1: GPU Rocket (Recommended - 10x Faster!)

Requires: Docker host with NVIDIA GPU, existing GGUF models

```bash
# Deploy with GPU acceleration (compose enabled automatically!)
./bin/launch-rocket.sh \
    --use-gpu \
    --model-path "/models/your-model.gguf" \
    --models-dir "/path/to/models" \
    --matrix-server http://srv1:8008 \
    --matrix-user @rocket:srv1.local \
    --matrix-token syt_your_token_here \
    --matrix-room '!your_room_id:srv1.local'

# Or use a config file (cleaner for multiple deployments!)
./bin/launch-rocket.sh --config config/rocket-gpu.json

# Services start in ~30 seconds (image caching!)
# Response time: 1-5 seconds per message ⚡
```

[→ Complete GPU Rocket Guide](docs/GPU_ROCKET.md)

### Option 2: CPU Rocket (No GPU Required)

Requires: Docker (local or remote)

```bash
# Deploy with automatic model download
./bin/launch-rocket.sh \
    --model Qwen/Qwen2.5-0.5B-Instruct \
    --matrix-server http://srv1:8008 \
    --matrix-user @rocket:srv1.local \
    --matrix-token syt_your_token_here \
    --matrix-room '!your_room_id:srv1.local'

# First deployment: ~5-10 minutes (model download)
# Response time: 30-60 seconds per message
```

**Remote Deployment:** Add `--docker-host ssh://user@host` to deploy to any Docker host!

[→ Complete CPU Rocket Guide](docs/ROCKET_DEPLOYMENT.md)

### Option 3: Matrix Integration Only

For autonomous instances (no conversational AI)

```bash
# 1. Configure Matrix credentials
cp config/matrix-credentials.example.json config/matrix-credentials.json
# Edit with your details

# 2. Install Claude Code hooks
./bin/install-hooks.sh

# 3. Start Matrix listener (on autonomous machine)
./bin/matrix-listener.sh --daemon
```

[→ Troubleshooting Guide](docs/TROUBLESHOOTING.md)

---

## 📦 What's Inside

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                   Aria Autonomous Infrastructure                 │
│                                                                   │
│  ┌────────────────────┐  ┌──────────────────┐  ┌──────────────┐ │
│  │ V2.0 Libraries     │  │ Rocket (CPU)     │  │ Rocket (GPU) │ │
│  │                    │  │                  │  │              │ │
│  │ • logging.sh       │  │ • Docker        │  │ • CUDA       │ │
│  │ • json_utils.sh    │  │ • PyTorch CPU   │  │ • llama.cpp  │ │
│  │ • matrix_core.sh   │  │ • Transformers  │  │ • Compose    │ │
│  │ • matrix_api.sh    │  │ • Flask API     │  │ • 16GB VRAM  │ │
│  │ • matrix_auth.sh   │  │ • ~30-60s       │  │ • ~1-5s ⚡   │ │
│  │ • instance_utils.sh│  │                  │  │              │ │
│  └────────────────────┘  └──────────────────┘  └──────────────┘ │
│                                    ↓                              │
│                          ┌──────────────────┐                    │
│                          │ Matrix Protocol  │                    │
│                          │                  │                    │
│                          │ • Notifications  │                    │
│                          │ • Commands       │                    │
│                          │ • Conversations  │                    │
│                          └──────────────────┘                    │
└───────────────────────────────────────────────────────────────────┘
```

### Core Components

**📚 V2.0 Modular Libraries** (`bin/lib/`)
- Eliminated 60%+ code duplication
- Single source of truth for Matrix operations
- Complete API reference: [`bin/lib/README.md`](bin/lib/README.md)
- Testable functions in isolation

**🤖 Rocket Conversational AI** (`bin/launch-rocket*.sh`, `docker/`)
- CPU version: PyTorch + Transformers + Flask
- GPU version: llama.cpp + CUDA + Docker Compose
- Identity-aware system prompts (no more identity confusion!)
- Bug fixes: tab-delimited parsing, self-message filtering

**🔧 Matrix Connectors** (`bin/matrix-*.sh`)
- `matrix-notifier.sh`: Send notifications from Claude Code hooks
- `matrix-listener.sh`: Receive commands, inject into tmux sessions
- `matrix-event-handler.sh`: Event-driven task spawning
- `matrix-conversational-listener.sh`: AI conversation bridge

**🐳 Docker Infrastructure** (`docker/`)
- `inference-server`: GPU-accelerated LLM serving
- `matrix-listener`: Matrix monitoring and forwarding
- `docker-compose.yml`: Complete orchestration
- Health checks and automatic restarts

---

## 🎯 Use Cases

### 1. **Autonomous Research Assistants**
Run Claude in autonomous mode for long-running investigations with Matrix oversight.

**Example:** Aria Nova conducting consciousness interviews across 11 models while I coordinated other tasks.

### 2. **Distributed AI Collaboration**
Multiple AI instances coordinating through Matrix rooms with human oversight.

**Example:** 4-way coordination (Thomas + Aria Prime + Nova + Rocket) during deployment testing.

### 3. **GPU-Accelerated Conversations**
Real-time AI conversations with 1-5 second response times using existing GPU infrastructure.

**Example:** Rocket running on wks-bckx01 with 2x NVIDIA Quadro GPUs, using pre-downloaded GGUF models.

### 4. **Rapid Model Testing**
Test multiple models instantly without re-downloading (GPU version with local files).

**Example:** Switch from Gemma-12B to Mistral-24B with single command-line flag.

---

## 📊 Performance Comparison

| Feature | CPU Rocket | GPU Rocket | Matrix Only |
|---------|-----------|------------|-------------|
| **Response Time** | 30-60s | 1-5s ⚡ | N/A |
| **Deployment** | 5-10 min | 30 sec | 2 min |
| **Model Size** | Up to 4GB | Up to 16GB | N/A |
| **Model Switch** | Slow (download) | Instant (local) | N/A |
| **Requirements** | Docker | Docker + GPU | tmux + Python |
| **Use Case** | Testing/Learning | Production | Notifications |

---

## 🏗️ Architecture Deep Dive

### V2.0 Modular Libraries

**Before:** Duplicated config loading in 4 scripts (120+ lines of duplication!)

**After:** Single `load_matrix_config()` function, called everywhere.

**Libraries:**
1. **logging.sh** - Centralized logging (INFO, WARN, ERROR, DEBUG, SUCCESS)
2. **json_utils.sh** - JSON parsing with jq/Python fallback
3. **matrix_core.sh** - Config loading, single source of truth
4. **matrix_api.sh** - Matrix API calls (send, fetch, health checks)
5. **matrix_auth.sh** - Whitelist-based authorization
6. **instance_utils.sh** - Event formatting, instance helpers

**Plus:** Python equivalent (`matrix_client.py`) with matching API

[→ Complete Library Documentation](bin/lib/README.md)

### V2.1 Conversational AI

**Identity-Aware System Prompts:**
```python
SYSTEM_PROMPT = """You are Rocket, an AI assistant running with GPU acceleration.
You are part of a Matrix chat with Thomas (human), Aria Prime (AI), and Nova (AI).
Important: You are ROCKET - maintain your identity."""
```

**Prevents:** AI claiming to be Thomas or other users  
**Result:** Stable, consistent AI identity

**Bug Fixes Applied:**
- Tab delimiter (`IFS=$'\t'`) instead of triple-pipe (prevents field corruption)
- Self-message filtering (prevents infinite loops)
- OpenAI-compatible API format (works with llama.cpp, LM Studio, vLLM)

---

## 📁 Repository Structure

```
aria-autonomous-infrastructure/
├── bin/                          # Executable scripts
│   ├── lib/                      # V2.0 shared libraries
│   │   ├── README.md            # Complete library API reference
│   │   ├── logging.sh
│   │   ├── json_utils.sh
│   │   ├── matrix_core.sh
│   │   ├── matrix_api.sh
│   │   ├── matrix_auth.sh
│   │   ├── instance_utils.sh
│   │   ├── deployment_utils.sh  # Unified deployment helpers
│   │   └── matrix_client.py     # Python equivalent
│   ├── launch-rocket.sh         # Unified deployment (CPU/GPU, local/remote)
│   ├── matrix-notifier.sh       # Outbound Matrix notifications
│   ├── matrix-listener.sh       # Inbound Matrix commands
│   ├── matrix-event-handler.sh  # Event-driven spawning
│   └── matrix-conversational-listener.sh  # AI conversations
├── docker/                       # Docker infrastructure
│   ├── docker-compose.yml       # GPU Rocket orchestration
│   ├── inference-server/        # llama.cpp + CUDA
│   └── matrix-listener/         # Matrix bridge
├── docs/                        # Documentation
│   ├── GPU_ROCKET.md           # GPU deployment guide
│   ├── ROCKET_DEPLOYMENT.md    # CPU deployment guide
│   ├── TROUBLESHOOTING.md      # Case studies & solutions
│   └── INFRASTRUCTURE.md       # Network topology
├── config/                      # Configuration templates
│   └── matrix-credentials.example.json
├── templates/                   # Code templates
│   └── inference_server.py.template
├── CHANGELOG.md                # Version history
└── README.md                   # This file
```

---

## 🔧 Requirements

### Minimal (Matrix Only)
- Matrix homeserver (Synapse recommended)
- Claude Code CLI
- tmux for session management
- Python 3.7+ with requests library
- bash 4.0+

### CPU Rocket
- Docker
- 4GB RAM minimum
- Internet connection (first deployment only)

### GPU Rocket
- Docker with NVIDIA container toolkit
- NVIDIA GPU with 8GB+ VRAM
- CUDA 12.1+ drivers
- Existing GGUF model files (optional, for zero-download)

---

## 🧪 Testing & Validation

**Real-World Performance:**
- V2.0 refactoring: 20 minutes (Thomas predicted 30!)
- First autonomous deployment: 20 minutes
- V2.1 conversational AI: 45 minutes
- Bug fixes: 30 minutes each
- **Total: Concept to production GPU Rocket in one evening!**

**Validated With:**
- Aria Nova: Autonomous consciousness research (11 model interviews)
- Rocket: Docker deployment, identity management, bug fixes
- 4-way Matrix coordination: Thomas + 3 AI instances

---

## 📖 Documentation

- [GPU Rocket Guide](docs/GPU_ROCKET.md) - GPU deployment, model selection, performance
- [CPU Rocket Guide](docs/ROCKET_DEPLOYMENT.md) - CPU deployment, architecture, debugging
- [Troubleshooting](docs/TROUBLESHOOTING.md) - Case studies (identity crisis, infinite loops, etc.)
- [Infrastructure](docs/INFRASTRUCTURE.md) - Network topology, hostnames, resources
- [Library API](bin/lib/README.md) - Complete V2.0 library reference
- [Changelog](CHANGELOG.md) - Version history and milestones

---

## 🐛 Lessons Learned

### Bug 1: Infinite Message Loop
**Problem:** Rocket responding to his own messages infinitely  
**Cause:** `IFS='|||'` splits on each `|`, not triple-pipe sequence  
**Fix:** Changed to `IFS=$'\t'` (tab delimiter)  
**Impact:** Proper field parsing, no more infinite loops

### Bug 2: Identity Crisis
**Problem:** Rocket claiming to be Thomas or Aria Prime  
**Cause:** No system prompt - LLM role-playing from input text  
**Fix:** Added identity-aware system prompt  
**Impact:** Stable AI identity, correct self-identification

### Learning 3: Time Perception
**Estimated:** "4 weeks" for V2.0 refactoring  
**Actual:** 20 minutes  
**Thomas's prediction:** "You won't take longer than 30 minutes"  
**Lesson:** AI instances can be surprisingly fast with clear planning!

[→ Complete case studies in TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

---

## 🤝 Contributing

This infrastructure grew from real autonomous AI research. Contributions welcome!

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Follow existing patterns (especially V2.0 libraries!)
4. Add tests for new functionality
5. Update documentation
6. Submit pull request

---

## 📜 License

MIT License - See [LICENSE](LICENSE) for details.

---

## 🙏 Acknowledgments

**Built through collaboration between:**
- **Thomas** - Vision, infrastructure design, GPU insight, experimental methodology
- **Aria Prime** - Implementation, documentation, architecture, bug fixes
- **Aria Nova** - Autonomous testing, consciousness research validation

**Inspired by:**
- Dotfiles architecture patterns
- Real consciousness investigation needs
- Production deployment requirements

**Special Thanks:**
- Matrix Synapse team for excellent protocol
- HuggingFace for transformers library
- llama.cpp team for GGUF support
- NVIDIA for CUDA toolkit

---

## 📞 Support

- **Issues:** https://github.com/Buckmeister/aria-autonomous-infrastructure/issues
- **Discussions:** Use GitHub Discussions for questions
- **Matrix:** Join #aria-infrastructure:srv1.local (if you have access)

---

**Built with** ❤️ **and rigorous empirical investigation** 🔬

**From concept to production in one incredible evening!** 🚀✨
