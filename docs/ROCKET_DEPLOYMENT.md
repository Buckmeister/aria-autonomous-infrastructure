# Rocket Deployment Guide (CPU Mode)

**Rocket** is a conversational AI system that combines:
- Local LLM inference (CPU-based, no GPU required)
- Matrix chat integration
- Docker containerization
- Identity-aware system prompts

This guide covers **CPU deployment**. For **10-100x faster GPU deployment**, see [GPU_ROCKET.md](GPU_ROCKET.md).

**Note:** The `launch-rocket.sh` script now supports both CPU and GPU modes. This guide shows CPU-only deployment (the default mode without flags).

---

## Quick Start

```bash
cd ~/Development/aria-autonomous-infrastructure

# Deploy with default settings
./bin/launch-rocket.sh \
    --matrix-server http://srv1.bck.intern:8008 \
    --matrix-user @rocket:srv1.local \
    --matrix-token syt_cm9ja2V0_... \
    --matrix-room '!UCEurIvKNNMvYlrntC:srv1.local'
```

That's it! The script handles everything:
1. Creates Docker container
2. Installs dependencies
3. Downloads and serves the LLM
4. Configures Matrix integration
5. Starts conversational listener

---

## Architecture

```
Matrix Message (from Thomas or Aria Prime)
    ↓
Matrix Conversational Listener (bash script)
    ↓
Inference API (Flask on port 8080)
    ↓
Local LLM (Qwen2.5-0.5B-Instruct running on CPU)
    ↓
Response generated with system prompt context
    ↓
Posted back to Matrix
```

---

## Key Features

### 1. Identity-Aware System Prompt

Rocket knows who he is! The system prompt provides:
- Name and identity
- Team members (Thomas, Aria Prime, Nova)
- Purpose and behavior guidelines
- Instructions to maintain identity

**Before system prompt:**
```
User: "My name is Thomas, who are you?"
Rocket: "I'm Thomas and this is Rocket..."  ❌ Identity confusion!
```

**After system prompt:**
```
User: "My name is Thomas, who are you?"
Rocket: "I am Rocket, an AI assistant..."  ✅ Maintains identity!
```

### 2. Proper Message Parsing

**Lesson Learned:** `IFS='|||'` in bash doesn't mean "split on triple-pipe"!

It means "split on any of: |, |, |" which corrupts fields.

**Solution:** Use tab delimiter (`IFS=$'\t'`) for reliable field separation.

### 3. Self-Message Filtering

Rocket filters out his own messages to prevent infinite loops:
```bash
if [ "$sender" == "$MATRIX_USER_ID" ]; then
    continue  # Skip own messages
fi
```

---

## Command-Line Options

### Required
- `--matrix-server URL` - Matrix homeserver (e.g., http://srv1:8008)
- `--matrix-user ID` - Matrix user ID (e.g., @rocket:srv1.local)
- `--matrix-token TOKEN` - Matrix access token
- `--matrix-room ID` - Matrix room ID (e.g., !abc:srv1.local)

### Optional
- `--name NAME` - Container name (default: rocket-instance)
- `--model MODEL` - HuggingFace model (default: Qwen/Qwen2.5-0.5B-Instruct)
- `--port PORT` - Inference API port (default: 8080)
- `--memory LIMIT` - Container memory (default: 4g)
- `--cpus NUM` - Container CPUs (default: 2)
- `--instance-name NAME` - Display name (default: Rocket)

---

## Model Options

### Small & Fast (~500MB-1.5GB)
Perfect for testing and quick responses:
- `Qwen/Qwen2.5-0.5B-Instruct` - **Default**, ~500MB, very fast
- `Qwen/Qwen2.5-1.5B-Instruct` - ~1.5GB, balanced quality/speed

### Medium Quality (~2-3GB)
Better responses, still fast on CPU:
- `microsoft/phi-2` - ~2.7GB, high quality
- `google/gemma-2b-it` - ~2GB, instruction-tuned

### Large & Powerful (~7-14GB)
Best quality, slower inference:
- `mistralai/Mistral-7B-Instruct-v0.2` - ~14GB, powerful
- `meta-llama/Llama-2-7b-chat-hf` - ~13GB, conversational

**Note:** Larger models require more RAM and take longer per response.

---

## Usage Examples

### Basic Deployment
```bash
./bin/launch-rocket.sh \
    --matrix-server http://srv1:8008 \
    --matrix-user @rocket:srv1.local \
    --matrix-token syt_abc123 \
    --matrix-room '!xyz:srv1.local'
```

### Custom Model
```bash
./bin/launch-rocket.sh \
    --name rocket-phi2 \
    --model microsoft/phi-2 \
    --matrix-server http://srv1:8008 \
    --matrix-user @rocketphi:srv1.local \
    --matrix-token syt_def456 \
    --matrix-room '!xyz:srv1.local'
```

### Multiple Instances
Deploy different models simultaneously:
```bash
# Small fast instance
./bin/launch-rocket.sh --name rocket-small --model Qwen/Qwen2.5-0.5B-Instruct \
    --matrix-user @rocket-small:srv1.local --port 8080 ...

# Larger quality instance
./bin/launch-rocket.sh --name rocket-large --model microsoft/phi-2 \
    --matrix-user @rocket-large:srv1.local --port 8081 ...
```

---

## Prerequisites

### 1. Matrix User Creation

Create a Matrix user with admin API:
```bash
# Get admin access token from your Matrix server
ADMIN_TOKEN="syt_admin_..."

# Create new user
curl -X PUT "http://srv1:8008/_synapse/admin/v2/users/@rocket:srv1.local" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{
        "password": "secure_password_here",
        "displayname": "Rocket",
        "admin": false
    }'

# Login to get access token
curl -X POST "http://srv1:8008/_matrix/client/r0/login" \
    -H "Content-Type: application/json" \
    -d '{
        "type": "m.login.password",
        "user": "rocket",
        "password": "secure_password_here"
    }'
```

### 2. Room Invitation

Invite Rocket to your Matrix room:
```bash
# As admin user, invite Rocket
# Use Matrix client or:
curl -X POST "http://srv1:8008/_matrix/client/r0/rooms/!ROOM_ID/invite" \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d '{"user_id": "@rocket:srv1.local"}'
```

### 3. Docker Setup

Ensure Docker is running:
```bash
docker info  # Should show Docker status
```

---

## Monitoring & Debugging

### Check Status
```bash
# Container status
docker ps | grep rocket-instance

# Inference server health
docker exec rocket-instance curl -s http://localhost:8080/health

# Test inference
docker exec rocket-instance bash -c \
    'printf "%s" "{\"prompt\": \"Hello!\", \"max_length\": 50}" | \
     curl -s -X POST -H "Content-Type: application/json" -d @- \
     http://localhost:8080/generate'
```

### View Logs
```bash
# Inference server logs
docker exec rocket-instance tail -f /root/inference.log

# Conversational listener logs
docker exec rocket-instance tail -f /root/conversational-listener.log

# Both logs
docker exec rocket-instance bash -c \
    "tail -f /root/inference.log /root/conversational-listener.log"
```

### Common Issues

**Issue: Model loading timeout**
```
Error: Model loading timed out
```
Solution: Larger models need more time. Check logs:
```bash
docker exec rocket-instance tail -50 /root/inference.log
```

**Issue: Listener not responding**
```
Rocket doesn't respond to Matrix messages
```
Debug checklist:
1. Check listener is running: `docker exec rocket-instance ps aux | grep listener`
2. Check logs: `docker exec rocket-instance tail -50 /root/conversational-listener.log`
3. Verify Matrix credentials: `docker exec rocket-instance cat /root/aria-autonomous-infrastructure/config/matrix-credentials.json`
4. Test inference API: `docker exec rocket-instance curl http://localhost:8080/health`

**Issue: Identity confusion**
```
Rocket claims to be Thomas or someone else
```
This was fixed! If it happens:
1. Verify system prompt is in inference_server.py
2. Restart inference server
3. Check model supports chat templates

---

## Technical Details

### Dependencies Installed
- Python 3.10
- PyTorch (CPU build)
- Transformers (HuggingFace)
- Flask (API server)
- jq (JSON parsing)
- curl (HTTP requests)

### File Locations in Container
```
/root/
├── inference_server.py              # Flask API serving LLM
├── inference.log                    # Inference server logs
├── conversational-listener.log      # Listener logs
└── aria-autonomous-infrastructure/  # Cloned repo
    ├── bin/
    │   ├── matrix-conversational-listener.sh  # Matrix monitor
    │   └── lib/                     # V2.0 shared libraries
    └── config/
        └── matrix-credentials.json  # Matrix config
```

### Resource Requirements
- **Memory:** 4GB recommended (adjustable with --memory)
- **CPU:** 2 cores recommended (adjustable with --cpus)
- **Disk:** Varies by model:
  - 0.5B model: ~1GB
  - 1.5B model: ~2GB
  - 7B model: ~15GB
- **Network:** Internet for model download, Matrix for operation

---

## Security Considerations

1. **Matrix Token:** Keep access tokens secure, don't commit to git
2. **Container Isolation:** Docker provides isolation from host
3. **Network:** Inference API only exposed within container
4. **Updates:** Regularly pull latest aria-autonomous-infrastructure

---

## Lessons Learned (V2.1 Development)

### Bug 1: Infinite Message Loop
**Problem:** Rocket responding to his own messages infinitely  
**Cause:** `IFS='|||'` splits on each pipe, not triple-pipe  
**Fix:** Use tab delimiter `IFS=$'\t'`

### Bug 2: Identity Crisis
**Problem:** Rocket claiming to be Thomas or Aria Prime  
**Cause:** No system prompt, LLM role-playing from input  
**Fix:** Add identity-aware system prompt

### Learning 3: Model Loading Time
Small models (0.5B-1.5B) load in ~30 seconds  
Large models (7B+) can take 2-3 minutes  
Script waits up to 5 minutes

### Learning 4: CPU Inference Works!
No GPU required for conversational AI  
Response times: ~30-60 seconds for 0.5B model  
Acceptable for Matrix chat use case

---

## Future Enhancements

Potential improvements:
- [ ] Conversation memory (track context across messages)
- [ ] Model quantization (faster inference)
- [ ] Multiple model support (model selection per query)
- [ ] Health monitoring dashboard
- [ ] Auto-restart on failure
- [ ] Metrics and analytics
- [ ] Web UI for configuration

---

## Credits

**Development:** Aria Prime & Thomas  
**Session:** 2025-11-20 (V2.1)  
**Achievement:** From concept to working conversational AI in one evening!

**Key Milestones:**
1. V2.0 refactoring - Modular library architecture
2. First Rocket deployment - Autonomous dotfiles installation
3. V2.1 conversational AI - Local LLM + Matrix integration
4. Bug fixes - Identity crisis and infinite loop resolved
5. Production script - Complete deployment automation

This is what symbiotic AI development looks like! 🚀✨

---

**Questions?** Check the main README or ask in Matrix!
