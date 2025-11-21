# Rocket Infrastructure - Capabilities Assessment & Testing Plan

**Created:** 2025-11-21
**Authors:** Aria Prime & Thomas
**Purpose:** Comprehensive assessment of theoretical capabilities and plan for validation, testing, and solidification

---

## 🎯 Executive Summary

The `aria-autonomous-infrastructure` repository has grown organically through real-world use into a powerful, flexible deployment system. This document:

1. **Maps all theoretical capabilities** (what we should be able to do)
2. **Proposes quick test cases** to verify assumptions
3. **Identifies refactoring opportunities** to improve resilience
4. **Outlines a test suite architecture** for ongoing confidence

**Key Finding:** We have built a remarkably capable system with 5 backends, 4 deployment methods, and 3 orchestration layers - but we need systematic testing to ensure everything works together reliably.

---

## 📊 Part 1: Theoretical Capabilities Assessment

### 1.1 Inference Backends (5 options)

| Backend | Type | Best For | GPU | CPU | API |
|---------|------|----------|-----|-----|-----|
| **Docker (self-contained)** | Local inference | Learning, testing | ❌ | ✅ | Custom Flask |
| **LM Studio (hybrid)** | External API | Quick prototyping | ✅ | ✅ | OpenAI-compatible |
| **Anthropic (cloud)** | Cloud API | Production, quality | N/A | N/A | Native Claude |
| **vLLM** | High-performance | Production GPU, scaling | ✅ | ✅* | OpenAI-compatible |
| **Ollama** | CPU-optimized | CPU hosts, ease of use | ✅ (opt) | ✅ | OpenAI-compatible |

*vLLM CPU support exists but Docker image may have limitations

**Status:**
- ✅ Docker backend fully tested (CPU)
- ✅ Anthropic backend tested (cloud)
- ⚠️  LM Studio backend implemented but not systematically tested
- ⚠️  vLLM backend implemented for GPU, needs CPU validation
- ⚠️  Ollama backend implemented, needs systematic testing

### 1.2 Deployment Targets (4 options)

| Target | Access Method | Use Case | Status |
|--------|---------------|----------|--------|
| **Local Docker** | Direct | Development, quick testing | ✅ Validated |
| **Remote SSH** | ssh://user@host | Distributed deployment | ✅ Validated (wks-bckx01, mpc-bck01) |
| **Remote TCP** | tcp://host:port | Legacy systems | ⚠️  Implemented, untested |
| **Kubernetes (MicroK8s)** | kubectl | Production orchestration | ✅ Phase 2 complete |

**Status:**
- ✅ Local Docker: Extensively tested
- ✅ Remote SSH: Production-validated on multiple hosts
- ⚠️  Remote TCP: Code exists, never used in practice
- ✅ Kubernetes: Manifests created, deployed, tested

### 1.3 Model Sources (3 categories)

#### A. Local Models (Immediate)

**On wks-bckx01 (via LM Studio):**
1. deepseek/deepseek-r1-0528-qwen3-8b (reasoning model)
2. mistralai/mistral-small-3.2 (philosophically sophisticated)
3. google/gemma-* (multiple variants)
4. baidu/ernie-*
5. liquid/*
6. bytedance/*
7. openai/* variants
8. **Total: 11+ models ready to use**

**As GGUF Files (D:\Models directory):**
- Any pre-downloaded GGUF models
- Zero-download deployment
- GPU inference via llama.cpp

#### B. Online Models (HuggingFace)

**Small (CPU-friendly):**
- Qwen/Qwen2.5-0.5B-Instruct (~300MB)
- Qwen/Qwen2.5-1.5B-Instruct (~900MB)
- llama3.2:1b (~700MB)

**Medium (Balanced):**
- Qwen/Qwen2.5-3B-Instruct (~1.9GB)
- Qwen/Qwen2.5-7B-Instruct (~4.7GB)
- llama3.2:3b (~2GB)

**Large (GPU recommended):**
- Qwen/Qwen2.5-14B-Instruct (~8.7GB)
- Qwen/Qwen2.5-32B-Instruct (~20GB)
- Any HuggingFace model ID

#### C. Ollama Registry

**Popular tags:**
- qwen2.5:0.5b, qwen2.5:1.5b, qwen2.5:3b, qwen2.5:7b
- llama3.2:1b, llama3.2:3b
- mistral:7b, mixtral:8x7b
- gemma2:2b, gemma2:9b
- phi3:mini, phi3:medium

**Total: 100+ models available via `ollama pull`**

### 1.4 Configuration Methods (3 approaches)

| Method | Best For | Pros | Cons |
|--------|----------|------|------|
| **Command-line flags** | One-off deployments | Flexible, visible | Verbose, hard to reproduce |
| **JSON config files** | Team collaboration, CI/CD | Repeatable, version-controlled | Requires jq |
| **Environment variables** | Docker Compose | Standard practice | Less portable |

**Examples:**
```bash
# Method 1: Flags (flexible)
./bin/launch-rocket.sh --backend vllm --model Qwen/Qwen2.5-3B-Instruct ...

# Method 2: Config file (repeatable)
./bin/launch-rocket.sh --config configs/rocket-vllm-gpu.json

# Method 3: Env vars (for compose)
MODEL_NAME=qwen2.5:3b docker compose -f docker-compose-ollama.yml up
```

### 1.5 Kubernetes Deployment (Phase 2 Complete)

**Infrastructure:**
- 7-node MicroK8s cluster (3 control plane, 4 workers)
- Multi-environment support (dev/staging/prod)
- Kustomize-based configuration management
- Ingress with automatic TLS (cert-manager)

**Backends Supported:**
- Ollama (CPU-optimized, tested)
- vLLM (GPU-capable, manifests ready)
- Anthropic (cloud API, manifests ready)

**Deployment Matrices:**
```
Overlay × Backend Combinations:
- dev/ollama (1 replica, qwen2.5:0.5b, 3Gi)
- staging/ollama (2 replicas, qwen2.5:1.5b, 8Gi)
- prod/ollama (3 replicas, qwen2.5:3b, 15Gi)
- [Same structure for vLLM and Anthropic backends]
```

---

## 🧪 Part 2: Quick Test Cases for Validation

### 2.1 Backend Verification Tests (5 tests)

**Goal:** Verify each backend can deploy and respond

#### Test 1: Docker Backend (CPU)
```bash
# Test: Local CPU inference
./bin/launch-rocket.sh \
  --backend docker \
  --model "Qwen/Qwen2.5-0.5b-Instruct" \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket-test:srv1.local \
  --matrix-token <token> \
  --matrix-room <room>

# Expected:
# - Container creates in ~30s
# - Model downloads in ~2-3min (first time)
# - Responds to Matrix message in ~30-60s
# - Health check passes: curl localhost:8080/health

# Cleanup: docker rm -f rocket-instance
```

#### Test 2: Ollama Backend (CPU)
```bash
# Test: Ollama CPU inference
./bin/launch-rocket.sh \
  --backend ollama \
  --model "qwen2.5:0.5b" \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket-test:srv1.local \
  --matrix-token <token> \
  --matrix-room <room>

# Expected:
# - Docker Compose starts in ~10s
# - Ollama pulls model in ~2-3min (100-300MB)
# - Responds to Matrix message in ~15-30s
# - Health check: curl localhost:11434/api/tags

# Cleanup: docker compose -f /tmp/rocket-deploy/docker/docker-compose-ollama.yml down
```

#### Test 3: vLLM Backend (CPU mode)
```bash
# Test: vLLM CPU inference
./bin/launch-rocket.sh \
  --backend vllm \
  --model "Qwen/Qwen2.5-0.5B-Instruct" \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket-test:srv1.local \
  --matrix-token <token> \
  --matrix-room <room>

# Expected:
# - Docker Compose starts with CPU backend
# - Model downloads from HuggingFace (~300MB)
# - Responds to Matrix message in ~20-40s
# - Health check: curl localhost:8080/health

# Cleanup: docker compose down
```

#### Test 4: vLLM Backend (GPU mode)
```bash
# Test: vLLM GPU inference on wks-bckx01
./bin/launch-rocket.sh \
  --use-gpu \
  --backend vllm \
  --docker-host ssh://aria@wks-bckx01 \
  --model "Qwen/Qwen2.5-1.5B-Instruct" \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket-test:srv1.local \
  --matrix-token <token> \
  --matrix-room <room>

# Expected:
# - Remote deployment via SSH succeeds
# - GPU detected and used
# - Model downloads (~900MB)
# - Responds to Matrix in ~5-10s
# - nvidia-smi shows GPU usage

# Cleanup: ssh aria@wks-bckx01 'cd /tmp/rocket-deploy/docker && docker compose down'
```

#### Test 5: Anthropic Backend (Cloud)
```bash
# Test: Anthropic Claude API
./bin/launch-rocket.sh \
  --backend anthropic \
  --anthropic-key $ANTHROPIC_API_KEY \
  --anthropic-model "claude-sonnet-4-5-20250929" \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket-test:srv1.local \
  --matrix-token <token> \
  --matrix-room <room>

# Expected:
# - Deployment in ~10s (listener only, no inference server)
# - Responds to Matrix in ~2-5s
# - High-quality responses (Claude Sonnet 4.5)
# - No local compute required

# Cleanup: docker compose down
```

### 2.2 Deployment Target Tests (4 tests)

#### Test 6: Local Docker
```bash
# Test: Direct Docker deployment (already validated)
./bin/launch-rocket.sh --backend ollama --model qwen2.5:0.5b <matrix-params>

# Expected: Works on local machine
# Cleanup: docker compose down
```

#### Test 7: Remote SSH (Multiple Hosts)
```bash
# Test A: Deploy to wks-bckx01
./bin/launch-rocket.sh --backend ollama --model qwen2.5:1.5b \
  --docker-host ssh://aria@wks-bckx01 <matrix-params>

# Test B: Deploy to mpc-bck01
./bin/launch-rocket.sh --backend ollama --model qwen2.5:0.5b \
  --docker-host ssh://aria@mpc-bck01 <matrix-params>

# Test C: Deploy to mob-bckx03
./bin/launch-rocket.sh --backend ollama --model qwen2.5:0.5b \
  --docker-host ssh://aria@mob-bckx03 <matrix-params>

# Expected: All three hosts deploy successfully
# SSH key auto-detection works
# Cleanup: ssh to each host and docker compose down
```

#### Test 8: Remote TCP (Untested)
```bash
# Test: TCP deployment (if Docker daemon exposed)
# Note: Requires Docker daemon listening on TCP (security concern!)

# Setup first on remote host:
# sudo systemctl edit docker.service
# [Service]
# ExecStart=
# ExecStart=/usr/bin/dockerd -H tcp://0.0.0.0:2375 -H unix:///var/run/docker.sock

# Then test:
./bin/launch-rocket.sh --backend ollama --model qwen2.5:0.5b \
  --docker-host tcp://192.168.188.171:2375 <matrix-params>

# Expected: Deployment works without SSH
# ⚠️  WARNING: This is insecure - only for testing
```

#### Test 9: Kubernetes Deployment
```bash
# Test: Deploy to MicroK8s dev environment
kubectl apply -k ~/Development/aria-autonomous-infrastructure/k8s/overlays/dev

# Expected:
# - Namespace created
# - Pod scheduled (rocket-dev namespace)
# - Ollama pulls qwen2.5:0.5b
# - Pod reaches Running state
# - Matrix listener connects

# Verify:
kubectl get pods -n rocket-dev
kubectl logs -n rocket-dev deployment/dev-rocket-ollama -c ollama-server
kubectl logs -n rocket-dev deployment/dev-rocket-ollama -c matrix-listener

# Cleanup:
kubectl delete -k ~/Development/aria-autonomous-infrastructure/k8s/overlays/dev
```

### 2.3 Configuration Method Tests (3 tests)

#### Test 10: Command-line Flags
```bash
# Test: Explicit flags (most common pattern)
./bin/launch-rocket.sh \
  --backend ollama \
  --model "qwen2.5:0.5b" \
  --matrix-server http://srv1:8008 \
  --matrix-user @rocket:srv1.local \
  --matrix-token $TOKEN \
  --matrix-room $ROOM

# Expected: Works (already validated in other tests)
```

#### Test 11: JSON Config File
```bash
# Test: JSON config file loading
cat > /tmp/test-config.json << 'EOF'
{
  "backend": "ollama",
  "model": "qwen2.5:0.5b",
  "matrix": {
    "server": "http://srv1:8008",
    "user": "@rocket:srv1.local",
    "token": "syt_...",
    "room": "!...:srv1.local"
  },
  "instance_name": "Test-Rocket"
}
EOF

./bin/launch-rocket.sh --config /tmp/test-config.json

# Expected:
# - jq successfully parses JSON
# - All config values loaded
# - Deployment proceeds normally
# - Command-line overrides work:
./bin/launch-rocket.sh --config /tmp/test-config.json --model qwen2.5:1.5b

# Cleanup: docker compose down && rm /tmp/test-config.json
```

#### Test 12: Environment Variables (Docker Compose)
```bash
# Test: Manual Docker Compose with env vars
cd ~/Development/aria-autonomous-infrastructure/docker

cat > .env << 'EOF'
MODEL_NAME=qwen2.5:0.5b
OLLAMA_PORT=11434
MATRIX_CONFIG_DIR=./config
LISTENER_SCRIPT=./matrix-listener/matrix-conversational-listener-openai.sh
EOF

# Copy Matrix credentials
mkdir -p config
cp ~/path/to/matrix-credentials.json config/

# Start directly with compose
docker compose -f docker-compose-ollama.yml up -d

# Expected:
# - Services start without launch script
# - Environment variables applied
# - Matrix listener connects

# Cleanup: docker compose -f docker-compose-ollama.yml down && rm .env
```

### 2.4 Integration Tests (3 comprehensive scenarios)

#### Test 13: Multi-Host Parallel Deployment
```bash
# Test: Deploy same model to 3 hosts simultaneously
# Validates: SSH handling, parallel deployment, resource isolation

# Terminal 1:
./bin/launch-rocket.sh --backend ollama --model qwen2.5:0.5b \
  --docker-host ssh://aria@mpc-bck01 --instance-name "Rocket-MPC" <matrix>

# Terminal 2:
./bin/launch-rocket.sh --backend ollama --model qwen2.5:0.5b \
  --docker-host ssh://aria@mob-bckx03 --instance-name "Rocket-MOB" <matrix>

# Terminal 3:
./bin/launch-rocket.sh --backend ollama --model qwen2.5:0.5b \
  --docker-host ssh://aria@srv2 --instance-name "Rocket-SRV2" <matrix>

# Expected:
# - All three deploy in parallel
# - No conflicts or SSH issues
# - All three respond to Matrix independently
# - Each has correct instance name

# Verify: Send "@rocket-mpc who are you?" in Matrix
# Each should respond with their own name
```

#### Test 14: Backend Switching (Same Host)
```bash
# Test: Switch between backends on same host
# Validates: Cleanup, port conflicts, backend compatibility

# Step 1: Deploy Ollama
./bin/launch-rocket.sh --backend ollama --model qwen2.5:0.5b <matrix>
# Test Matrix response

# Step 2: Stop and deploy vLLM
docker compose down
./bin/launch-rocket.sh --backend vllm --model Qwen/Qwen2.5-0.5B-Instruct <matrix>
# Test Matrix response

# Step 3: Stop and deploy Anthropic
docker compose down
./bin/launch-rocket.sh --backend anthropic --anthropic-key $KEY <matrix>
# Test Matrix response

# Expected:
# - Clean transitions between backends
# - No port conflicts
# - Matrix listener reconnects properly
# - Each backend responds correctly
```

#### Test 15: Kubernetes Multi-Environment
```bash
# Test: Deploy to all three K8s environments
# Validates: Kustomize overlays, resource isolation, scaling

# Deploy dev (1 replica, 0.5b model)
kubectl apply -k k8s/overlays/dev
kubectl wait --for=condition=ready pod -l app=rocket-ollama -n rocket-dev --timeout=300s

# Deploy staging (2 replicas, 1.5b model)
kubectl apply -k k8s/overlays/staging
kubectl wait --for=condition=ready pod -l app=rocket-ollama -n rocket-staging --timeout=300s

# Deploy prod (3 replicas, 3b model)
kubectl apply -k k8s/overlays/prod
kubectl wait --for=condition=ready pod -l app=rocket-ollama -n rocket-prod --timeout=300s

# Verify all running:
kubectl get deployments -A | grep rocket

# Expected:
# rocket-dev:      1/1 replicas
# rocket-staging:  2/2 replicas
# rocket-prod:     3/3 replicas

# Test scaling:
kubectl scale deployment/dev-rocket-ollama --replicas=2 -n rocket-dev
# Verify: kubectl get pods -n rocket-dev

# Cleanup:
kubectl delete -k k8s/overlays/dev
kubectl delete -k k8s/overlays/staging
kubectl delete -k k8s/overlays/prod
```

---

## 🔨 Part 3: Refactoring Opportunities

### 3.1 Code Organization Improvements

#### A. Extract Deployment Logic into Library Functions

**Current State:**
- `launch-rocket.sh` is 1018 lines
- Contains deployment logic + UI + validation
- Hard to test individual components

**Proposed Refactoring:**
```bash
# Create bin/lib/deployment.sh with:
# - deploy_via_compose()
# - deploy_via_docker()
# - create_deployment_directory()
# - configure_backend()
# - validate_deployment()

# Result: launch-rocket.sh becomes orchestration only
# Each function testable in isolation
```

**Benefits:**
- Easier unit testing
- Reusable in other scripts
- Clearer separation of concerns

#### B. Standardize Error Handling

**Current State:**
- Mix of `exit 1`, `exit_with_error()`, and `return 1`
- Inconsistent error messages
- Some functions don't validate inputs

**Proposed Standard:**
```bash
# All deployment functions should:
# 1. Validate inputs with clear error messages
# 2. Use exit_with_error() for fatal errors
# 3. Return non-zero for recoverable errors
# 4. Log all errors to stderr with log_error()

# Example:
deploy_ollama() {
    local model=$1
    local port=${2:-11434}

    # Validate
    [[ -z "$model" ]] && exit_with_error "deploy_ollama: model parameter required"

    # Execute
    if ! docker compose up -d; then
        log_error "Failed to start Ollama compose stack"
        return 1
    fi

    log_success "Ollama deployed successfully"
    return 0
}
```

#### C. Configuration Validation Layer

**Current State:**
- Validation scattered throughout launch script
- No central "check everything before deploying"
- Easy to miss incompatible combinations

**Proposed:**
```bash
# New function in deployment_utils.sh:
validate_deployment_config() {
    local backend=$1
    local use_gpu=$2
    local model_name=$3
    local model_path=$4

    # Check backend-specific requirements
    case "$backend" in
        ollama)
            [[ -z "$model_name" ]] && \
                exit_with_error "Ollama backend requires --model (e.g., qwen2.5:0.5b)"
            ;;
        vllm)
            if [[ "$use_gpu" == "true" ]]; then
                [[ -z "$model_name" ]] && \
                    exit_with_error "vLLM GPU requires --model (HuggingFace ID)"
            fi
            ;;
        docker)
            if [[ "$use_gpu" == "true" ]]; then
                [[ -z "$model_path" ]] && \
                    exit_with_error "GPU mode requires --model-path (GGUF file)"
                [[ -z "$MODELS_DIR" ]] && \
                    exit_with_error "GPU mode requires --models-dir"
            fi
            ;;
        anthropic)
            [[ -z "$ANTHROPIC_API_KEY" ]] && \
                exit_with_error "Anthropic backend requires --anthropic-key or ANTHROPIC_API_KEY env"
            ;;
        lmstudio)
            # Could check if LM Studio is accessible
            ;;
    esac

    # Check for conflicting options
    if [[ "$use_gpu" == "true" ]] && [[ "$backend" == "anthropic" ]]; then
        log_warn "Anthropic backend doesn't use GPU (cloud API)"
    fi

    return 0
}
```

### 3.2 Testing Infrastructure

#### A. Unit Test Framework

**Create:** `tests/unit/test_deployment_utils.sh`

```bash
#!/bin/bash
# Unit tests for deployment utilities

source "$(dirname "$0")/../../bin/lib/deployment_utils.sh"
source "$(dirname "$0")/test_framework.sh"  # Simple test helper

# Test 1: validate_required_params with all params
test_validate_required_params_success() {
    MATRIX_SERVER="http://srv1:8008"
    MATRIX_USER="@test:srv1.local"
    MATRIX_TOKEN="token123"
    MATRIX_ROOM="!room:srv1.local"

    validate_required_params MATRIX_SERVER MATRIX_USER MATRIX_TOKEN MATRIX_ROOM
    assert_equals $? 0 "Should succeed with all params"
}

# Test 2: validate_required_params with missing param
test_validate_required_params_failure() {
    MATRIX_SERVER=""
    MATRIX_USER="@test:srv1.local"

    validate_required_params MATRIX_SERVER MATRIX_USER 2>/dev/null
    assert_not_equals $? 0 "Should fail with missing SERVER"
}

# Test 3: create_matrix_credentials_file
test_create_credentials_file() {
    local temp_file=$(mktemp)

    create_matrix_credentials_file "$temp_file" \
        "http://srv1:8008" "@test:srv1.local" "token123" "!room:srv1.local" "Test"

    assert_file_exists "$temp_file"
    assert_file_contains "$temp_file" "\"server\": \"http://srv1:8008\""
    assert_file_contains "$temp_file" "\"user\": \"@test:srv1.local\""

    rm -f "$temp_file"
}

# Run all tests
run_tests
```

**Create:** `tests/unit/test_framework.sh` (simple test runner)

```bash
#!/bin/bash
# Simple bash test framework

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

assert_equals() {
    local actual=$1
    local expected=$2
    local message=${3:-"Assertion failed"}

    if [[ "$actual" == "$expected" ]]; then
        log_success "✓ $message"
        ((TESTS_PASSED++))
    else
        log_error "✗ $message: expected '$expected', got '$actual'"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

assert_file_exists() {
    local file=$1
    if [[ -f "$file" ]]; then
        log_success "✓ File exists: $file"
        ((TESTS_PASSED++))
    else
        log_error "✗ File not found: $file"
        ((TESTS_FAILED++))
    fi
    ((TESTS_RUN++))
}

run_tests() {
    # Auto-discover and run test functions
    for func in $(declare -F | awk '{print $3}' | grep '^test_'); do
        log_info "Running: $func"
        $func
    done

    echo
    echo "================================"
    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "================================"

    [[ $TESTS_FAILED -eq 0 ]] && return 0 || return 1
}
```

#### B. Integration Test Suite

**Create:** `tests/integration/test_backends.sh`

```bash
#!/bin/bash
# Integration tests for all backends

source "$(dirname "$0")/../test_framework.sh"

# Shared Matrix config for all tests
MATRIX_SERVER="http://srv1:8008"
MATRIX_USER="@rocket-test:srv1.local"
MATRIX_TOKEN="${ROCKET_TEST_TOKEN:-}"
MATRIX_ROOM="${ROCKET_TEST_ROOM:-}"

test_ollama_backend_local() {
    log_info "Testing Ollama backend (local)"

    ./bin/launch-rocket.sh \
        --backend ollama \
        --model qwen2.5:0.5b \
        --matrix-server $MATRIX_SERVER \
        --matrix-user $MATRIX_USER \
        --matrix-token $MATRIX_TOKEN \
        --matrix-room $MATRIX_ROOM \
        --name rocket-test-ollama

    assert_equals $? 0 "Deployment should succeed"

    # Wait for readiness
    sleep 30

    # Test health endpoint
    curl -f http://localhost:11434/api/tags
    assert_equals $? 0 "Health check should pass"

    # Cleanup
    docker compose down
}

test_vllm_backend_cpu() {
    log_info "Testing vLLM backend (CPU)"

    ./bin/launch-rocket.sh \
        --backend vllm \
        --model "Qwen/Qwen2.5-0.5B-Instruct" \
        --matrix-server $MATRIX_SERVER \
        --matrix-user $MATRIX_USER \
        --matrix-token $MATRIX_TOKEN \
        --matrix-room $MATRIX_ROOM

    assert_equals $? 0 "Deployment should succeed"

    sleep 60

    curl -f http://localhost:8080/health
    assert_equals $? 0 "Health check should pass"

    docker compose down
}

# Run with: ROCKET_TEST_TOKEN=... ROCKET_TEST_ROOM=... ./tests/integration/test_backends.sh
run_tests
```

#### C. Smoke Test Script

**Create:** `tests/smoke_test.sh` (quick validation)

```bash
#!/bin/bash
# Quick smoke test - verifies basic functionality

set -e

echo "🧪 Rocket Infrastructure Smoke Test"
echo "===================================="

# Test 1: Scripts exist
echo "✓ Checking scripts exist..."
[[ -f bin/launch-rocket.sh ]] || { echo "✗ launch-rocket.sh not found"; exit 1; }
[[ -f bin/matrix-notifier.sh ]] || { echo "✗ matrix-notifier.sh not found"; exit 1; }

# Test 2: Libraries load
echo "✓ Checking libraries load..."
source bin/lib/logging.sh
source bin/lib/matrix_core.sh
source bin/lib/deployment_utils.sh

# Test 3: Docker available
echo "✓ Checking Docker..."
docker --version > /dev/null || { echo "✗ Docker not available"; exit 1; }

# Test 4: Required tools
echo "✓ Checking required tools..."
command -v curl > /dev/null || { echo "✗ curl not found"; exit 1; }
command -v jq > /dev/null || { echo "⚠ jq not found (JSON configs won't work)"; }

# Test 5: Docker compose files valid
echo "✓ Validating Docker Compose files..."
for file in docker/docker-compose*.yml; do
    docker compose -f "$file" config > /dev/null || { echo "✗ Invalid: $file"; exit 1; }
done

# Test 6: Kubernetes manifests valid
echo "✓ Validating Kubernetes manifests..."
kubectl kustomize k8s/base > /dev/null || { echo "✗ Base kustomization invalid"; exit 1; }
kubectl kustomize k8s/overlays/dev > /dev/null || { echo "✗ Dev overlay invalid"; exit 1; }

echo
echo "=================================="
echo "✅ All smoke tests passed!"
echo "=================================="
```

### 3.3 Documentation Improvements

#### A. API Documentation

**Create:** `docs/API_REFERENCE.md`

```markdown
# Rocket Launch API Reference

## launch-rocket.sh

### Synopsis
```bash
./bin/launch-rocket.sh [OPTIONS]
./bin/launch-rocket.sh --config CONFIG_FILE
```

### Required Options
- `--matrix-server URL` - Matrix homeserver
- `--matrix-user ID` - Matrix user ID (@user:server)
- `--matrix-token TOKEN` - Matrix access token
- `--matrix-room ID` - Matrix room ID (!id:server)

### Backend Selection
- `--backend MODE` - Backend mode (docker|ollama|vllm|anthropic|lmstudio|auto)

### Deployment Options
- `--use-gpu` - Enable GPU acceleration (auto-enables compose)
- `--docker-host HOST` - Docker host (local|ssh://user@host|tcp://host:port)
- `--config FILE` - Load config from JSON file

[... full documentation ...]
```

#### B. Troubleshooting Decision Tree

**Add to:** `docs/TROUBLESHOOTING.md`

```markdown
## Quick Diagnosis Decision Tree

```
Deployment fails
├─> Can't connect to Docker?
│   ├─> Local: Check `docker ps`
│   ├─> SSH: Check `ssh user@host docker ps`
│   └─> TCP: Check firewall, Docker daemon config
│
├─> Container starts but crashes?
│   ├─> Check logs: `docker logs rocket-instance`
│   ├─> Out of memory? Reduce model size or increase limits
│   └─> Model download failed? Check internet connection
│
├─> Matrix listener not responding?
│   ├─> Check Matrix credentials valid
│   ├─> Check listener logs
│   └─> Verify room permissions
│
└─> Inference slow/failing?
    ├─> CPU: Try smaller model (0.5b instead of 3b)
    ├─> GPU: Check `nvidia-smi`, verify CUDA
    └─> Network: Check API endpoint accessible
```
```

### 3.4 Automation and CI/CD

#### A. GitHub Actions Workflow

**Create:** `.github/workflows/test.yml`

```yaml
name: Test Infrastructure

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  smoke-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run smoke tests
        run: ./tests/smoke_test.sh

      - name: Validate Docker Compose files
        run: |
          for file in docker/docker-compose*.yml; do
            docker compose -f "$file" config
          done

      - name: Validate Kubernetes manifests
        run: |
          kubectl kustomize k8s/base
          kubectl kustomize k8s/overlays/dev
          kubectl kustomize k8s/overlays/staging
          kubectl kustomize k8s/overlays/prod

  unit-tests:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run unit tests
        run: |
          cd tests/unit
          ./test_deployment_utils.sh
          ./test_matrix_core.sh
```

#### B. Pre-commit Hook

**Create:** `.git/hooks/pre-commit`

```bash
#!/bin/bash
# Pre-commit hook: Run smoke tests before commit

echo "Running pre-commit smoke tests..."

if ! ./tests/smoke_test.sh; then
    echo "❌ Smoke tests failed. Commit aborted."
    echo "Fix issues or use 'git commit --no-verify' to skip."
    exit 1
fi

echo "✅ Smoke tests passed!"
exit 0
```

---

## 📋 Part 4: Implementation Plan

### Phase 1: Quick Wins (Week 1)
**Goal:** Verify current functionality, catch low-hanging bugs

1. **Day 1-2:** Run all 15 quick test cases manually
   - Document results in `tests/TEST_RESULTS.md`
   - Create GitHub issues for failures
   - Priority: Fix critical failures blocking basic use

2. **Day 3-4:** Create smoke test script
   - Implement `tests/smoke_test.sh`
   - Add to git pre-commit hook
   - Run on main development machine

3. **Day 5:** Document findings
   - Update TROUBLESHOOTING.md with discovered issues
   - Create API_REFERENCE.md skeleton
   - Log all discovered edge cases

### Phase 2: Test Infrastructure (Week 2)
**Goal:** Build automated testing foundation

1. **Day 1-2:** Create test framework
   - Implement `tests/unit/test_framework.sh`
   - Write 5 unit tests for deployment_utils.sh
   - Write 3 unit tests for matrix_core.sh

2. **Day 3-4:** Integration test suite
   - Implement `tests/integration/test_backends.sh`
   - Test Ollama backend (local and remote)
   - Test vLLM backend (CPU mode)

3. **Day 5:** CI/CD setup
   - Create GitHub Actions workflow
   - Run smoke tests on every commit
   - Add badge to README.md

### Phase 3: Refactoring (Week 3)
**Goal:** Improve code organization and maintainability

1. **Day 1-2:** Extract deployment.sh library
   - Move deployment functions out of launch-rocket.sh
   - Add comprehensive validation
   - Write unit tests for new functions

2. **Day 3-4:** Standardize error handling
   - Audit all exit points in scripts
   - Standardize error messages
   - Add helpful troubleshooting hints

3. **Day 5:** Configuration validation
   - Implement validate_deployment_config()
   - Add early validation before deployment
   - Test all backend combinations

### Phase 4: Documentation (Week 4)
**Goal:** Make infrastructure accessible and maintainable

1. **Day 1-2:** Complete API reference
   - Document all launch-rocket.sh options
   - Add examples for each backend
   - Document all library functions

2. **Day 3-4:** Troubleshooting guide
   - Add decision tree
   - Document all known issues and solutions
   - Add FAQ section

3. **Day 5:** Developer guide
   - How to add a new backend
   - How to write tests
   - How to debug deployment issues

---

## 🎯 Success Metrics

### Quantitative Goals
- ✅ 100% of backends tested (5/5)
- ✅ 100% of deployment targets validated (4/4)
- ✅ 80% test coverage for deployment_utils.sh
- ✅ Smoke tests run in < 30 seconds
- ✅ Integration tests complete in < 10 minutes
- ✅ Zero known critical bugs

### Qualitative Goals
- ✅ New contributors can deploy Rocket in < 15 minutes
- ✅ All deployment modes have clear documentation
- ✅ Error messages guide users to solutions
- ✅ Code is organized logically and easy to navigate
- ✅ Tests catch regressions before merge

---

## 📝 Appendix: Test Checklist

### Pre-Deployment Verification
- [ ] Docker installed and running
- [ ] Required tools available (curl, jq, ssh)
- [ ] Matrix server accessible
- [ ] Matrix credentials valid
- [ ] SSH keys configured (for remote deployment)
- [ ] Docker host accessible (for remote deployment)

### Post-Deployment Verification
- [ ] Container/pod in Running state
- [ ] Health endpoint responds
- [ ] Matrix listener connected
- [ ] Responds to Matrix message within expected time
- [ ] Logs show no errors
- [ ] Resource usage reasonable (memory, CPU, GPU)

### Cleanup Verification
- [ ] All containers stopped
- [ ] All volumes removed (if requested)
- [ ] No orphaned processes
- [ ] SSH connections closed
- [ ] Temporary files cleaned up

---

**This document will evolve as we implement and learn. Treat it as a living guide for maintaining and improving Rocket infrastructure reliability.**
