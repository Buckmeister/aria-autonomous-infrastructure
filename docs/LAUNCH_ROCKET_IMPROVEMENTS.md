# launch_rocket.sh Improvement Plan - V2.4

**Created:** 2025-11-21
**Author:** Aria Prime
**Based On:** Real-world deployment experience from v2.3.1

---

## Executive Summary

This document outlines planned improvements to `launch-rocket.sh` based on hands-on experience deploying GPU Rocket with Mistral-Small-3.2-24B and troubleshooting llama-cpp-python upgrades. These improvements focus on robustness, user experience, and operational clarity.

---

## 1. Health Check & Container Management

### Current Issues

**Problem:** Docker Compose health checks fail because llama.cpp's built-in server doesn't provide a `/health` endpoint, causing containers to be marked "unhealthy" even when fully operational.

**Real-World Impact:**
- Confusing status messages: "unhealthy" when server is working perfectly
- Matrix listener waits for inference server health check that never passes
- Deployment appears failed even when completely functional

### Proposed Solutions

**A. Custom Health Check Endpoint**
```bash
# Add lightweight health check wrapper in inference server
# docker/inference-server/healthcheck.sh
#!/bin/bash
# Check if llama.cpp server is responding
curl -s http://localhost:8080/v1/models > /dev/null 2>&1 && echo "healthy" || exit 1
```

**B. Update docker-compose.yml Health Checks**
```yaml
inference-server:
  healthcheck:
    test: ["CMD", "/app/healthcheck.sh"]
    interval: 30s
    timeout: 10s
    retries: 3
    start_period: 120s  # Allow time for model loading
```

**C. Add Health Check to Launch Script**
```bash
# After deployment, verify actual functionality
log_info "Verifying inference server is responding..."
MAX_RETRIES=12  # 2 minutes with 10s intervals
for i in $(seq 1 $MAX_RETRIES); do
    if ssh_exec "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY" \
        "curl -s http://localhost:$INFERENCE_PORT/v1/models" > /dev/null 2>&1; then
        log_success "Inference server responding!"
        break
    fi
    log_info "Waiting for server to be ready... ($i/$MAX_RETRIES)"
    sleep 10
done
```

**Benefits:**
- Accurate operational status
- Early detection of real failures
- Better user experience with clear status messages

---

## 2. Build Progress Monitoring

### Current Issues

**Problem:** Long-running Docker builds (15-30 minutes for CUDA compilation) provide no progress feedback, making users uncertain whether the build is progressing or stuck.

**Real-World Experience:**
- llama-cpp-python CUDA build: 114 compilation tasks over 20+ minutes
- Users can't distinguish between "slow but working" and "hung"
- No way to monitor what's actually happening

### Proposed Solutions

**A. Background Build with Progress Streaming**
```bash
# For remote builds via SSH
log_info "Starting Docker build (this will take 15-30 minutes for CUDA compilation)..."
log_info "Build progress will be shown below..."

# Stream build output with progress indicators
ssh_exec "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY" \
    "cd $DEPLOY_DIR && docker-compose build --progress=plain inference-server 2>&1" | \
    while IFS= read -r line; do
        # Filter for important progress indicators
        if [[ "$line" =~ "Step [0-9]+/[0-9]+" ]] || \
           [[ "$line" =~ "\[[0-9]+/[0-9]+\]" ]] || \
           [[ "$line" =~ "Installing" ]] || \
           [[ "$line" =~ "Compiling" ]]; then
            echo "$line"
        fi
    done

log_success "Docker build completed!"
```

**B. Estimated Time Display**
```bash
# Add expected duration warnings
if [[ "$USE_GPU" == "true" ]]; then
    log_warn "GPU deployment requires building CUDA-enabled llama-cpp-python"
    log_warn "Expected build time: 15-30 minutes (first build only)"
    log_warn "Subsequent deployments will use cached images (~30 seconds)"
    read -p "Continue with build? (y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
fi
```

**C. Build Time Tracking**
```bash
BUILD_START=$(date +%s)
# ... build happens ...
BUILD_END=$(date +%s)
BUILD_DURATION=$((BUILD_END - BUILD_START))
log_success "Build completed in $(($BUILD_DURATION / 60))m $(($BUILD_DURATION % 60))s"
```

**Benefits:**
- Users know build is progressing
- Clear expectations for long operations
- Historical data for performance tracking

---

## 3. Version Management & Upgrades

### Current Issues

**Problem:** No built-in way to upgrade llama-cpp-python or track versions. Recent template compatibility issues required manual Dockerfile edits.

**Real-World Experience:**
- Mistral template used `strftime_now()` function not in llama-cpp-python 0.3.2
- Required manual Dockerfile edit to remove version pin
- No way to check current version or upgrade without rebuild

### Proposed Solutions

**A. Version Checking Flag**
```bash
# Add --check-versions flag
if [[ "$CHECK_VERSIONS" == "true" ]]; then
    log_info "Checking component versions..."

    # Check local Dockerfile pins
    PINNED_VERSION=$(grep "llama-cpp-python" docker/inference-server/Dockerfile | \
                     grep -oP '==\K[0-9.]+')

    # Check running container version (if exists)
    if docker ps | grep -q rocket-inference; then
        RUNNING_VERSION=$(docker exec rocket-inference pip show llama-cpp-python | \
                         grep Version | cut -d' ' -f2)
        log_info "Running version: $RUNNING_VERSION"
    fi

    # Check latest available
    LATEST_VERSION=$(pip index versions llama-cpp-python 2>/dev/null | \
                    grep "Available versions" | head -1)
    log_info "Latest version: $LATEST_VERSION"
    log_info "Pinned in Dockerfile: ${PINNED_VERSION:-'not pinned (will use latest)'}"
    exit 0
fi
```

**B. Upgrade Path**
```bash
# Add --upgrade flag
if [[ "$UPGRADE_LLAMA_CPP" == "true" ]]; then
    log_warn "This will rebuild inference server with latest llama-cpp-python"
    log_warn "Build time: ~15-30 minutes for CUDA compilation"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1

    # Force rebuild without cache
    DOCKER_BUILD_FLAGS="--no-cache"
    log_info "Forcing rebuild with latest version..."
fi
```

**C. Model Compatibility Matrix**
```bash
# Add to show_usage()
cat << 'EOF'
=== Model Compatibility ===
  Mistral-Small-3.2:  Requires llama-cpp-python >= 0.3.3 (strftime_now template)
  Gemma-3:            Requires llama-cpp-python >= 0.3.3 (architecture support)
  Qwen2.5:            Compatible with all versions
  DeepSeek:           Compatible with all versions

  Use --check-versions to verify your deployment
  Use --upgrade to rebuild with latest llama-cpp-python
EOF
```

**Benefits:**
- Easy version management
- Proactive compatibility checking
- Clear upgrade path

---

## 4. Error Recovery & Debugging

### Current Issues

**Problem:** When deployments fail, limited information about what went wrong or how to recover.

**Real-World Experience:**
- Template errors only visible in container logs
- No automatic log collection on failure
- Hard to diagnose remote deployment issues

### Proposed Solutions

**A. Automatic Log Collection on Failure**
```bash
deployment_failure_handler() {
    local exit_code=$1

    log_error "Deployment failed with exit code: $exit_code"
    log_info "Collecting diagnostic information..."

    # Collect logs
    mkdir -p /tmp/rocket-debug-$(date +%Y%m%d-%H%M%S)
    DEBUG_DIR="/tmp/rocket-debug-$(date +%Y%m%d-%H%M%S)"

    # Docker logs
    if [[ "$USE_COMPOSE" == "true" ]]; then
        docker-compose logs > "$DEBUG_DIR/docker-compose.log" 2>&1
        docker-compose ps > "$DEBUG_DIR/container-status.txt" 2>&1
    fi

    # Container inspect
    docker inspect rocket-inference > "$DEBUG_DIR/inspect-inference.json" 2>&1
    docker inspect rocket-listener > "$DEBUG_DIR/inspect-listener.json" 2>&1

    # System info
    docker version > "$DEBUG_DIR/docker-version.txt" 2>&1
    nvidia-smi > "$DEBUG_DIR/nvidia-smi.txt" 2>&1 || true

    log_info "Debug information saved to: $DEBUG_DIR"
    log_info "Please review logs and try again, or contact support"
}

# Set trap for failures
trap 'deployment_failure_handler $?' ERR
```

**B. Pre-Flight Checks**
```bash
run_preflight_checks() {
    log_info "Running pre-flight checks..."

    local issues=0

    # Check Docker connectivity
    if ! docker ps > /dev/null 2>&1; then
        log_error "Cannot connect to Docker"
        ((issues++))
    fi

    # Check GPU availability (if GPU mode)
    if [[ "$USE_GPU" == "true" ]]; then
        if ! nvidia-smi > /dev/null 2>&1; then
            log_error "GPU mode requested but nvidia-smi not available"
            ((issues++))
        fi
    fi

    # Check model file exists
    if [[ "$USE_GPU" == "true" ]] && [[ ! -f "$MODEL_PATH" ]]; then
        log_error "Model file not found: $MODEL_PATH"
        ((issues++))
    fi

    # Check Matrix server reachable
    if ! curl -s "$MATRIX_SERVER/_matrix/client/versions" > /dev/null 2>&1; then
        log_warn "Cannot reach Matrix server: $MATRIX_SERVER"
        log_warn "Deployment will continue but Matrix integration may fail"
    fi

    if [[ $issues -gt 0 ]]; then
        log_error "Pre-flight checks failed with $issues issue(s)"
        exit 1
    fi

    log_success "Pre-flight checks passed"
}
```

**C. Interactive Debugging Mode**
```bash
# Add --debug flag
if [[ "$DEBUG_MODE" == "true" ]]; then
    set -x  # Enable bash tracing
    DOCKER_BUILD_FLAGS="--progress=plain"
    log_info "Debug mode enabled: verbose output will be shown"
fi
```

**Benefits:**
- Faster troubleshooting
- Better error messages
- Automatic diagnostic collection

---

## 5. Deployment Profiles & Presets

### Current Issues

**Problem:** Users must specify many parameters for each deployment. Common configurations require repetitive command-line arguments.

### Proposed Solutions

**A. Built-in Deployment Profiles**
```bash
# Add --profile flag
case "$DEPLOYMENT_PROFILE" in
    "gpu-production")
        USE_GPU=true
        N_GPU_LAYERS=-1
        MEMORY_LIMIT="16g"
        log_info "Using GPU production profile"
        ;;
    "gpu-dev")
        USE_GPU=true
        N_GPU_LAYERS=-1
        MEMORY_LIMIT="8g"
        log_info "Using GPU development profile"
        ;;
    "cpu-small")
        USE_GPU=false
        MODEL_NAME="Qwen/Qwen2.5-0.5B-Instruct"
        MEMORY_LIMIT="2g"
        CPU_LIMIT="2"
        log_info "Using CPU small model profile"
        ;;
    "cpu-medium")
        USE_GPU=false
        MODEL_NAME="Qwen/Qwen2.5-1.5B-Instruct"
        MEMORY_LIMIT="4g"
        CPU_LIMIT="4"
        log_info "Using CPU medium model profile"
        ;;
esac
```

**B. Profile Management Commands**
```bash
# --list-profiles
if [[ "$LIST_PROFILES" == "true" ]]; then
    cat << 'EOF'
Available Deployment Profiles:

  gpu-production    Full GPU acceleration, high memory (16GB), all layers on GPU
  gpu-dev           GPU acceleration, moderate memory (8GB), development settings
  cpu-small         Small CPU model (0.5B), low resource usage (2GB RAM, 2 CPUs)
  cpu-medium        Medium CPU model (1.5B), moderate resources (4GB RAM, 4 CPUs)

Usage:
  ./launch-rocket.sh --profile gpu-production --model-path ... --matrix-...

Note: Profile settings can be overridden with command-line flags
EOF
    exit 0
fi
```

**C. Config File Generation**
```bash
# --save-config flag
if [[ "$SAVE_CONFIG" == "true" ]]; then
    log_info "Saving current configuration to: $SAVE_CONFIG_FILE"
    cat > "$SAVE_CONFIG_FILE" << EOF
{
  "use_gpu": $USE_GPU,
  "model_path": "$MODEL_PATH",
  "models_dir": "$MODELS_DIR",
  "docker_host": "$DOCKER_HOST_PARAM",
  "n_gpu_layers": $N_GPU_LAYERS,
  "matrix_server": "$MATRIX_SERVER",
  "matrix_user": "$MATRIX_USER",
  "matrix_token": "$MATRIX_TOKEN",
  "matrix_room": "$MATRIX_ROOM",
  "instance_name": "$INSTANCE_NAME"
}
EOF
    log_success "Configuration saved"
    log_info "Reuse with: ./launch-rocket.sh --config $SAVE_CONFIG_FILE"
    exit 0
fi
```

**Benefits:**
- Faster deployments
- Consistent configurations
- Easy sharing of working setups

---

## 6. Documentation & User Guidance

### Current Issues

**Problem:** Users need better guidance for common scenarios and troubleshooting.

### Proposed Solutions

**A. Interactive Setup Wizard**
```bash
# Add --wizard flag
if [[ "$RUN_WIZARD" == "true" ]]; then
    echo "=== Rocket Deployment Wizard ==="
    echo

    # Deployment type
    echo "1. What type of deployment?"
    echo "   a) GPU (fast, requires NVIDIA GPU)"
    echo "   b) CPU (slower, works everywhere)"
    read -p "Choose (a/b): " DEPLOY_TYPE

    [[ "$DEPLOY_TYPE" == "a" ]] && USE_GPU=true || USE_GPU=false

    # Model selection (if GPU)
    if [[ "$USE_GPU" == "true" ]]; then
        echo
        echo "2. Enter path to your GGUF model file:"
        read -p "Model path: " MODEL_PATH

        echo
        echo "3. Enter directory containing models (will be mounted in container):"
        read -p "Models directory: " MODELS_DIR
    else
        echo
        echo "2. Choose model size:"
        echo "   a) Small (0.5B - fast, basic responses)"
        echo "   b) Medium (1.5B - balanced)"
        read -p "Choose (a/b): " MODEL_SIZE

        [[ "$MODEL_SIZE" == "a" ]] && MODEL_NAME="Qwen/Qwen2.5-0.5B-Instruct"
        [[ "$MODEL_SIZE" == "b" ]] && MODEL_NAME="Qwen/Qwen2.5-1.5B-Instruct"
    fi

    # Matrix configuration
    echo
    echo "3. Matrix Configuration:"
    read -p "Matrix server URL (e.g., http://srv1:8008): " MATRIX_SERVER
    read -p "Matrix user ID (e.g., @rocket:srv1.local): " MATRIX_USER
    read -p "Matrix access token: " MATRIX_TOKEN
    read -p "Matrix room ID (e.g., !abc:srv1.local): " MATRIX_ROOM

    # Confirmation
    echo
    echo "=== Configuration Summary ==="
    echo "Deployment type: $([ "$USE_GPU" == "true" ] && echo "GPU" || echo "CPU")"
    [[ "$USE_GPU" == "true" ]] && echo "Model: $MODEL_PATH" || echo "Model: $MODEL_NAME"
    echo "Matrix server: $MATRIX_SERVER"
    echo "Matrix user: $MATRIX_USER"
    echo
    read -p "Proceed with deployment? (y/n): " CONFIRM

    [[ ! "$CONFIRM" =~ ^[Yy]$ ]] && exit 0

    log_info "Starting deployment..."
    # Continue with normal deployment logic
fi
```

**B. Common Issues & Solutions Reference**
```bash
# Add --troubleshoot flag
if [[ "$SHOW_TROUBLESHOOTING" == "true" ]]; then
    cat << 'EOF'
=== Common Issues & Solutions ===

1. Container shows "unhealthy" but works fine
   - This is expected: llama.cpp doesn't have /health endpoint
   - Check actual functionality: curl http://localhost:8080/v1/models
   - Container is operational if models endpoint responds

2. Build takes very long (15-30 minutes)
   - CUDA compilation is slow on first build
   - Subsequent builds use cached layers (~30 seconds)
   - Use --check-versions to see if rebuild is needed

3. Template errors (strftime_now undefined)
   - Your llama-cpp-python version is too old for this model
   - Use --upgrade flag to rebuild with latest version
   - Or switch to a compatible model (see --help for matrix)

4. Windows SSH + Docker credential errors
   - Cannot pull images via SSH on Windows
   - Workaround: Manually pull in desktop session
   - See docs/GPU_ROCKET.md for details

5. GPU not detected in container
   - Ensure nvidia-docker2 installed on host
   - Check: docker run --gpus all nvidia/cuda:12.6.2-base nvidia-smi
   - Verify DOCKER_HOST pointing to correct machine

For more help: https://github.com/Buckmeister/aria-autonomous-infrastructure/issues
EOF
    exit 0
fi
```

**Benefits:**
- Lower barrier to entry
- Reduced support burden
- Self-service troubleshooting

---

## 7. Performance Monitoring

### Current Issues

**Problem:** No built-in way to monitor performance or resource usage after deployment.

### Proposed Solutions

**A. Post-Deployment Performance Report**
```bash
generate_performance_report() {
    log_info "Generating performance report..."

    echo "=== Rocket Performance Report ===" > performance-report.txt
    echo "Generated: $(date)" >> performance-report.txt
    echo >> performance-report.txt

    # Container stats
    echo "=== Container Resource Usage ===" >> performance-report.txt
    docker stats --no-stream rocket-inference rocket-listener >> performance-report.txt

    # GPU usage (if applicable)
    if [[ "$USE_GPU" == "true" ]]; then
        echo >> performance-report.txt
        echo "=== GPU Usage ===" >> performance-report.txt
        nvidia-smi >> performance-report.txt
    fi

    # Model info
    echo >> performance-report.txt
    echo "=== Model Information ===" >> performance-report.txt
    curl -s http://localhost:$INFERENCE_PORT/v1/models | jq >> performance-report.txt

    log_success "Performance report saved to: performance-report.txt"
}
```

**B. Built-in Benchmark**
```bash
# Add --benchmark flag
if [[ "$RUN_BENCHMARK" == "true" ]]; then
    log_info "Running inference benchmark..."

    # Test prompt
    TEST_PROMPT="Count from 1 to 10"

    # Warm-up
    log_info "Warming up (1/3)..."
    curl -s -X POST http://localhost:$INFERENCE_PORT/v1/chat/completions \
        -H "Content-Type: application/json" \
        -d "{\"messages\":[{\"role\":\"user\",\"content\":\"$TEST_PROMPT\"}]}" \
        > /dev/null

    # Timed runs
    TIMES=()
    for i in {1..3}; do
        log_info "Benchmark run $i/3..."
        START=$(date +%s.%N)

        curl -s -X POST http://localhost:$INFERENCE_PORT/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "{\"messages\":[{\"role\":\"user\",\"content\":\"$TEST_PROMPT\"}]}" \
            > /dev/null

        END=$(date +%s.%N)
        DURATION=$(echo "$END - $START" | bc)
        TIMES+=($DURATION)
        log_info "Run $i: ${DURATION}s"
    done

    # Calculate average
    AVG=$(echo "${TIMES[@]}" | tr ' ' '+' | bc -l | awk '{print $1/3}')
    log_success "Average response time: ${AVG}s"

    exit 0
fi
```

**Benefits:**
- Performance visibility
- Optimization opportunities
- Capacity planning data

---

## 8. Multi-Instance Management

### Current Issues

**Problem:** No easy way to deploy or manage multiple Rocket instances with different models.

### Proposed Solutions

**A. Instance Naming & Isolation**
```bash
# Improve container naming
INSTANCE_ID="${INSTANCE_NAME:-rocket}-$(date +%s)"
CONTAINER_NAME_INFERENCE="$INSTANCE_ID-inference"
CONTAINER_NAME_LISTENER="$INSTANCE_ID-listener"

# Use unique ports if specified
if [[ -n "$PORT_OFFSET" ]]; then
    INFERENCE_PORT=$((8080 + PORT_OFFSET))
    log_info "Using port offset $PORT_OFFSET: inference on $INFERENCE_PORT"
fi
```

**B. Instance Listing**
```bash
# Add --list-instances flag
if [[ "$LIST_INSTANCES" == "true" ]]; then
    log_info "Active Rocket instances:"

    docker ps --filter "name=rocket" --format \
        "table {{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.CreatedAt}}"

    exit 0
fi
```

**C. Bulk Operations**
```bash
# Add --stop-all flag
if [[ "$STOP_ALL_INSTANCES" == "true" ]]; then
    log_warn "This will stop ALL Rocket instances"
    read -p "Continue? (y/n) " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0

    docker ps --filter "name=rocket" --format "{{.Names}}" | \
        xargs -r docker stop

    log_success "All Rocket instances stopped"
    exit 0
fi
```

**Benefits:**
- Run multiple models simultaneously
- Clear instance management
- No port conflicts

---

## Implementation Priority

### Phase 1 (High Priority - Immediate)
1. Health check improvements (Section 1)
2. Build progress monitoring (Section 2)
3. Error recovery & debugging (Section 4)

### Phase 2 (Medium Priority - Next Release)
4. Version management (Section 3)
5. Documentation & user guidance (Section 6)
6. Deployment profiles (Section 5)

### Phase 3 (Low Priority - Future)
7. Performance monitoring (Section 7)
8. Multi-instance management (Section 8)

---

## Testing Plan

Each improvement should be tested with:

1. **Fresh deployment:** Clean system, first-time deployment
2. **Upgrade scenario:** Existing deployment, version upgrade
3. **Failure recovery:** Intentional failures, error handling
4. **Remote deployment:** SSH-based deployment to Windows host
5. **Multi-instance:** Multiple concurrent deployments

---

## Success Metrics

- **Deployment Success Rate:** Target >95% first-time success
- **Time to Resolution:** Reduce troubleshooting time by 50%
- **User Satisfaction:** Positive feedback on UX improvements
- **Documentation Completeness:** <5% support questions on covered topics

---

## Conclusion

These improvements are based on real-world deployment experience and address actual pain points encountered during GPU Rocket development. Implementation will make the deployment process more robust, user-friendly, and maintainable.

**Next Steps:**
1. Review and prioritize improvements with Thomas
2. Implement Phase 1 improvements
3. Test in production environment
4. Gather feedback and iterate

**Maintained By:** Aria Prime
**Status:** Ready for Review
**Last Updated:** 2025-11-21
