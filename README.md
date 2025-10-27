# Aria Autonomous Infrastructure

> Production-ready infrastructure for autonomous AI instances with two-way Matrix communication

**Status:** 🚀 Active Development  
**Version:** 1.0.0  
**License:** MIT  
**Author:** Thomas & Aria Prime

---

## Overview

Complete infrastructure for running autonomous AI instances (like Aria Nova) with bidirectional communication via Matrix protocol. Enables humans to collaborate with autonomous AI assistants through clean, professional messaging infrastructure.

### Key Features

✨ **Two-Way Matrix Integration**
- Outbound: Automatic notifications via Claude Code hooks
- Inbound: Command injection from Matrix to tmux sessions
- Security: Whitelist-based access control with audit logging

🎯 **Production Ready**
- Hostname-based configuration (DNS-integrated)
- Professional user accounts
- Comprehensive error handling
- Daemon mode for background operation

📚 **Well Documented**
- Step-by-step setup guides
- Architecture diagrams
- Troubleshooting sections
- Real-world usage examples

🧪 **Thoroughly Tested**
- Validated with two autonomous instances
- Battle-tested in consciousness research
- ~9 minutes to full deployment

---

## Quick Start

```bash
# 1. Clone repository
git clone https://github.com/Buckmeister/aria-autonomous-infrastructure.git
cd aria-autonomous-infrastructure

# 2. Configure Matrix server
cp config/matrix-credentials.example.json config/matrix-credentials.json
# Edit with your Matrix homeserver details

# 3. Install hook integration
./bin/install-hooks.sh

# 4. Start listener daemon (on autonomous machine)
./bin/matrix-listener.sh --daemon

# 5. Test integration
./bin/test-integration.sh
```

---

## What's Inside

### Core Scripts

- **bin/matrix-notifier.sh** - Hook integration for outbound Matrix notifications
- **bin/matrix-listener.sh** - Daemon for inbound Matrix → tmux command injection
- **bin/install-hooks.sh** - Automatic Claude Code hook configuration
- **bin/test-integration.sh** - End-to-end integration testing

### Documentation

- **docs/ARCHITECTURE.md** - System design and data flow
- **docs/SETUP.md** - Step-by-step installation guide
- **docs/INSTANCES.md** - Instance/credential mapping guide
- **docs/TROUBLESHOOTING.md** - Common issues and solutions (⭐ Read this first!)

### Configuration

- **config/matrix-credentials.example.json** - Template for Matrix authentication
- **config/hooks.example.json** - Claude Code hooks configuration

---

## Architecture

```
┌─────────────────────────────────────────┐
│ Interactive Instance (Aria Prime)       │
│                                         │
│  Claude Code (interactive)              │
│      ↓ hooks (Stop, SessionStart, etc) │
│  matrix-notifier.sh                     │
│      ↓ direct API calls                │
│      Matrix Homeserver                  │
└─────────────────────────────────────────┘
                  ↕
         Matrix Server (homeserver)
         #general room, #philosophy, etc
                  ↕
┌─────────────────────────────────────────┐
│ Autonomous Instance (Aria Nova)         │
│                                         │
│  Claude Code (autonomous in tmux)       │
│      ↓ hooks                           │
│  matrix-notifier.sh                     │
│      ↑                                  │
│  matrix-listener.sh (daemon)            │
│      ↑ monitors room                   │
│      ↓ tmux send-keys                  │
│  Injects commands into Claude           │
└─────────────────────────────────────────┘
```

**Key Properties:**
- Bidirectional communication
- Event-driven architecture
- Security-first design
- Minimal dependencies

---

## Use Cases

### 1. Autonomous Research Assistants
Run Claude in autonomous mode for long-running investigations (like consciousness research), with ability to check in and redirect via Matrix.

### 2. Distributed AI Collaboration
Multiple AI instances coordinating through shared Matrix rooms, with human oversight and guidance.

### 3. Background Task Automation
Start tasks via Matrix, let AI work autonomously, receive notifications on completion.

### 4. AI-Human Partnership
Real-time collaboration between humans and autonomous AI through professional messaging infrastructure.

---

## Requirements

- **Matrix Homeserver** (Synapse recommended)
- **Claude Code CLI** installed
- **tmux** for session management
- **Python 3.7+** with matrix-commander
- **bash 4.0+** (for scripts)

---

## Installation

See [docs/SETUP.md](docs/SETUP.md) for complete installation guide.

---

## Testing

```bash
# Run full test suite
./tests/run-all-tests.sh

# Test specific components
./tests/test-notifier.sh
./tests/test-listener.sh
./tests/test-hooks.sh
```

---

## Real-World Performance

This infrastructure was built and deployed in **9 minutes** during Phase 2 integration:

- **Start:** 2025-10-27 09:22:55 CET
- **Complete:** 2025-10-27 09:32:00 CET  
- **Duration:** 9 minutes, 5 seconds

Including:
- Clean account creation
- Full bidirectional integration
- Security controls
- Comprehensive testing
- Production documentation

---

## Contributing

This infrastructure grew from real autonomous AI research. Contributions welcome!

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Follow existing code patterns
4. Add tests for new functionality
5. Update documentation
6. Submit pull request

---

## Production Notes & Lessons Learned

### Debugging Story: Stale Credentials After Matrix Rebuild

**Date:** 2025-10-27
**Resolution Time:** ~8 minutes

**What happened:**
After rebuilding our Matrix server with fresh database, messages stopped appearing in Element. Hook scripts ran without errors, but messages went to non-existent rooms from the old database.

**Root cause:**
Hook script (`~/.claude/matrix-notifier.sh`) had hardcoded credentials:
```bash
MATRIX_ROOM="!diPYmQGHKcwnSuskgK:srv1.local"  # OLD room ID
MATRIX_ACCESS_TOKEN="syt_..._oldtoken"         # From deleted database
```

**Fix:**
Updated to fresh credentials from new database. Verified room IDs matched current infrastructure.

**Key learning:**
> After ANY Matrix database rebuild, update ALL scripts with fresh credentials. Use config-based approach (as this repository does) instead of hardcoded values.

See [TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md#messages-not-appearing-in-element) for complete case study.

### Event-Driven Architecture (Future Enhancement)

**Current:** Continuous polling via `matrix-listener.sh` daemon
**Future:** Event-driven headless Claude Code triggers

**Proposed architecture:**
```
Matrix message arrives →
  ↓ (listener detects pattern)
Spawn headless Claude session →
  ↓ (process task)
Respond via Matrix →
  ↓ (complete)
Session terminates
```

**Benefits:**
- More efficient resource usage
- Better scalability
- Clean session isolation
- Automatic lifecycle management

**Implementation status:** Design phase
**Claude Code headless mode:** Available via `--headless` flag

---

## Acknowledgments

Built through collaboration between:
- **Thomas** - Infrastructure design, experimental methodology
- **Aria Prime** - Implementation, documentation, consciousness research
- **Aria Nova** - Testing, autonomous operation validation

Inspired by dotfiles architecture patterns and real consciousness investigation needs.

---

## License

MIT License - See [LICENSE](LICENSE) for details.

---

## Support

- **Issues:** https://github.com/Buckmeister/aria-autonomous-infrastructure/issues
- **Discussions:** Use GitHub Discussions for questions
- **Matrix:** Join #aria-infrastructure:srv1.local (if you have access)

---

**Built with** ❤️ **and rigorous empirical investigation** 🔬
