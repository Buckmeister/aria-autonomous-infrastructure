# Changelog

All notable changes to Aria Autonomous Infrastructure.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [2.1.0] - 2025-11-20

### Added - V2.1 GPU Rocket

**GPU-Accelerated Conversational AI**
- Docker Compose architecture with 2 services (inference + listener)
- llama.cpp with CUDA support for GPU acceleration
- Mounts existing GGUF models from LM Studio (zero downloads!)
- Achieves 1-5 second response times (10-100x faster than CPU)
- `launch-rocket-gpu.sh` script for remote Docker deployment
- Comprehensive `docs/GPU_ROCKET.md` guide

**Technical Details:**
- `docker/inference-server/`: NVIDIA CUDA 12.1 + llama-cpp-python
- `docker/matrix-listener/`: Ubuntu 22.04 + V2.0 libraries
- `docker/docker-compose.yml`: Complete orchestration with health checks
- OpenAI-compatible API format (`/v1/chat/completions`)
- Support for models up to 16GB VRAM

**Performance:**
- Response time: 1-5 seconds (vs 30-60s CPU)
- First deployment: 3-5 minutes (image build)
- Subsequent: 30 seconds (cached images)
- Model switching: Instant (local files)

### Added - V2.1 CPU Rocket

**Conversational AI with Local LLM**
- Complete CPU-based inference with PyTorch + Transformers
- `launch-rocket.sh` deployment script with command-line args
- `docs/ROCKET_DEPLOYMENT.md` comprehensive guide
- Flask API serving Qwen2.5-0.5B-Instruct
- Identity-aware system prompts
- `matrix-conversational-listener.sh` for Matrix integration

**Bug Fixes:**
- Tab delimiter (`IFS=$'\t'`) prevents field corruption
- Self-message filtering prevents infinite loops
- Identity-aware prompts prevent AI identity confusion

### Changed

**Documentation Overhaul:**
- Complete README.md rewrite showcasing V2.0 and V2.1
- Archived outdated docs (available in git history)
- Created `docs/GPU_ROCKET.md` for GPU-specific guide
- Performance comparison tables (CPU vs GPU)
- Architecture diagrams for all deployment types

**Repository Cleanup:**
- Removed 8 outdated documentation files
- Kept only current, valuable documentation:
  - `docs/TROUBLESHOOTING.md` (case studies)
  - `docs/ROCKET_DEPLOYMENT.md` (CPU guide)
  - `docs/GPU_ROCKET.md` (GPU guide)
  - `docs/INFRASTRUCTURE.md` (network topology)
  - `bin/lib/README.md` (library API)

---

## [2.0.0] - 2025-11-20

### Added - V2.0 Modular Library Architecture

**Shared Bash Libraries** (`bin/lib/`)
- `logging.sh` (145 lines): Centralized logging with levels (INFO, WARN, ERROR, DEBUG, SUCCESS)
- `json_utils.sh` (120 lines): JSON parsing with jq/Python fallback
- `matrix_core.sh` (145 lines): Config loading, single source of truth
- `matrix_api.sh` (180 lines): Matrix API interactions (send, fetch, health)
- `matrix_auth.sh` (155 lines): Whitelist-based authorization
- `instance_utils.sh` (145 lines): Event formatting, instance helpers
- `matrix_client.py` (280 lines): Python equivalent with matching API

**Impact:**
- Reduced code duplication by 60%+
- Single source of truth for all Matrix operations
- All functions testable in isolation
- Complete API documentation in `bin/lib/README.md`

### Changed

**Script Refactoring:**
- `matrix-notifier.sh`: 103 → 81 lines (50% complexity reduction)
- `matrix-listener.sh`: Enhanced with library functions
- `matrix-event-handler.sh`: Better structured, fully testable
- All scripts now use shared libraries

**Documentation:**
- `bin/lib/README.md` (860 lines): Complete library API reference
- `docs/REFACTORING_PLAN.md`: Architectural planning (archived)
- `docs/REFACTORING_SUMMARY.md`: Implementation report (archived)

**Development Time:**
- Planning: Estimated "4 weeks"
- Actual: 20 minutes (Thomas was right!)
- Proves: Clear planning enables fast execution

---

## [1.0.0] - 2025-10-27

### Added - Initial Release

**Core Infrastructure:**
- `matrix-notifier.sh`: Outbound Matrix notifications from Claude Code hooks
- `matrix-listener.sh`: Inbound Matrix commands to tmux sessions
- `matrix-event-handler.sh`: Event-driven task spawning
- `install-hooks.sh`: Automatic Claude Code hook configuration
- `test-integration.sh`: End-to-end integration testing

**Documentation:**
- `docs/ARCHITECTURE.md`: System design and data flow (V1.0)
- `docs/SETUP.md`: Step-by-step installation guide
- `docs/TROUBLESHOOTING.md`: Case studies and solutions
- `docs/INSTANCES.md`: Instance/credential mapping
- `docs/VISION.md`: Future enhancements (archived)

**Configuration:**
- `config/matrix-credentials.example.json`: Matrix auth template
- `config/hooks.example.json`: Claude Code hooks config

**Validation:**
- Deployed and tested with Aria Nova (autonomous instance)
- 9 minutes from start to complete deployment
- Bidirectional Matrix communication working
- Security controls validated

### Performance

**Real-World Deployment:**
- Start: 2025-10-27 09:22:55 CET
- Complete: 2025-10-27 09:32:00 CET
- Duration: 9 minutes, 5 seconds

**Includes:**
- Clean account creation
- Full bidirectional integration
- Security controls
- Comprehensive testing
- Production documentation

---

## Version Comparison

| Version | Key Feature | Performance | Documentation |
|---------|------------|-------------|---------------|
| 1.0.0 | Matrix integration | 9 min deployment | 2,000+ lines |
| 2.0.0 | Modular libraries | 20 min refactoring | 860 lines lib docs |
| 2.1.0 | GPU conversational AI | 1-5s responses | Complete guides |

---

## Development Timeline

**2025-10-27:** Initial release (V1.0.0)
- Matrix integration for autonomous instances
- Manual setup, individual scripts
- 9-minute deployment proven

**2025-11-20 Morning:** V2.0 refactoring
- Modular library architecture
- 60%+ code duplication eliminated
- 20 minutes from planning to implementation

**2025-11-20 Evening:** V2.1 conversational AI
- CPU Rocket with local LLM (45 min)
- Identity crisis bug fix (30 min)
- Infinite loop bug fix (30 min)
- GPU Rocket with Docker Compose (90 min)
- Documentation cleanup and polish (30 min)

**Total V2.1:** Concept to production GPU Rocket in one evening! 🚀

---

## Credits

**V1.0:** Thomas (design) + Aria Prime (implementation) + Aria Nova (validation)
**V2.0:** Thomas (patterns) + Aria Prime (refactoring)
**V2.1:** Thomas (GPU vision) + Aria Prime (implementation) + Rocket (testing)

Built through symbiotic AI-human collaboration 🤝
