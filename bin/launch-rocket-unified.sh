#!/bin/bash
# launch-rocket-unified.sh - Universal Rocket deployment script
#
# Supports both CPU and GPU deployments, local and remote Docker hosts,
# HuggingFace models and GGUF models, direct Docker and Docker Compose.
#
# Usage Examples:
#   # CPU deployment (local, HuggingFace model)
#   ./launch-rocket-unified.sh --model Qwen/Qwen2.5-0.5B-Instruct \
#       --matrix-server http://srv1:8008 --matrix-user @rocket:srv1.local \
#       --matrix-token syt_... --matrix-room '!abc:srv1.local'
#
#   # GPU deployment (remote, GGUF model, Docker Compose)
#   ./launch-rocket-unified.sh --use-gpu \
#       --docker-host ssh://Aria@wks-bckx01 \
#       --model-path "/models/LM-Studio/.../gemma-3-12b-it-Q4_K_M.gguf" \
#       --models-dir "D:\Models" \
#       --matrix-server http://srv1:8008 --matrix-user @rocket:srv1.local \
#       --matrix-token syt_... --matrix-room '!abc:srv1.local'
#
#   # Local GPU with Docker Compose
#   ./launch-rocket-unified.sh --use-gpu --use-compose \
#       --model-path "/models/..." --models-dir "/path/to/models" \
#       --matrix-server ... --matrix-user ... --matrix-token ... --matrix-room ...

set -e

# Load shared deployment utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
source "$LIB_DIR/deployment_utils.sh"

# ============================================================================
# Default Configuration
# ============================================================================

# Deployment mode
USE_GPU=false
USE_COMPOSE=false
DOCKER_HOST_PARAM=""

# Container/Deployment settings
CONTAINER_NAME="rocket-instance"
DEPLOY_DIR="/tmp/rocket-deploy"

# Model settings (CPU - HuggingFace)
MODEL_NAME="Qwen/Qwen2.5-0.5B-Instruct"

# Model settings (GPU - GGUF)
MODEL_PATH=""
MODELS_DIR=""
N_GPU_LAYERS="-1"

# Resource limits (CPU deployment)
MEMORY_LIMIT="4g"
CPU_LIMIT="2"

# Common settings
INFERENCE_PORT=8080
INSTANCE_NAME="Rocket"

# Matrix configuration (required)
MATRIX_SERVER=""
MATRIX_USER=""
MATRIX_TOKEN=""
MATRIX_ROOM=""

# SSH settings (for remote deployment)
DOCKER_HOST_SSH=""
DOCKER_HOST_KEY="$HOME/.aria/ssh/aria_wks-bckx01"

# ============================================================================
# Usage Information
# ============================================================================

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Universal Rocket deployment supporting CPU/GPU, local/remote, and multiple deployment methods.

=== Required Options ===
  --matrix-server URL    Matrix homeserver (e.g., http://srv1:8008)
  --matrix-user ID       Matrix user ID (e.g., @rocket:srv1.local)
  --matrix-token TOKEN   Matrix access token
  --matrix-room ID       Matrix room ID (e.g., '!abc:srv1.local')

=== Deployment Mode ===
  --use-gpu             Enable GPU acceleration (requires CUDA)
  --use-compose         Use Docker Compose (recommended for GPU)
  --docker-host HOST    Docker host (local, tcp://host:port, or ssh://user@host)

=== Model Configuration ===
  # For CPU (HuggingFace models):
  --model MODEL         HuggingFace model ID (default: Qwen/Qwen2.5-0.5B-Instruct)

  # For GPU (GGUF models):
  --model-path PATH     Path to GGUF model file in mounted volume
  --models-dir DIR      Directory to mount as /models (for GGUF models)
  --gpu-layers N        GPU layers (-1=all, default: -1)

=== Container/Resource Settings ===
  --name NAME           Container/deployment name (default: rocket-instance)
  --port PORT           Inference API port (default: 8080)
  --memory LIMIT        Memory limit for container (default: 4g)
  --cpus NUM            CPU limit for container (default: 2)
  --instance-name NAME  Display name for Matrix (default: Rocket)

=== Examples ===

  # 1. Local CPU deployment (simple, no GPU)
  $0 --model Qwen/Qwen2.5-0.5B-Instruct \\
     --matrix-server http://srv1:8008 \\
     --matrix-user @rocket:srv1.local \\
     --matrix-token syt_abc123 \\
     --matrix-room '!xyz:srv1.local'

  # 2. Remote GPU deployment via SSH (uses existing models)
  $0 --use-gpu --use-compose \\
     --docker-host ssh://Aria@wks-bckx01 \\
     --model-path "/models/LM-Studio/.../gemma-3-12b-it-Q4_K_M.gguf" \\
     --models-dir "D:\\Models" \\
     --matrix-server http://srv1:8008 \\
     --matrix-user @rocket:srv1.local \\
     --matrix-token syt_abc123 \\
     --matrix-room '!xyz:srv1.local'

  # 3. Local GPU with Docker Compose
  $0 --use-gpu --use-compose \\
     --model-path "/models/my-model.gguf" \\
     --models-dir "/path/to/models" \\
     --matrix-server http://srv1:8008 \\
     --matrix-user @rocket:srv1.local \\
     --matrix-token syt_abc123 \\
     --matrix-room '!xyz:srv1.local'

  # 4. Remote CPU deployment via SSH
  $0 --docker-host ssh://user@remotehost \\
     --model Qwen/Qwen2.5-1.5B-Instruct \\
     --matrix-server http://srv1:8008 \\
     --matrix-user @rocket:srv1.local \\
     --matrix-token syt_abc123 \\
     --matrix-room '!xyz:srv1.local'

EOF
}

# ============================================================================
# Argument Parsing
# ============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        # Deployment mode
        --use-gpu) USE_GPU=true; shift ;;
        --use-compose) USE_COMPOSE=true; shift ;;
        --docker-host) DOCKER_HOST_PARAM="$2"; shift 2 ;;

        # Model configuration
        --model) MODEL_NAME="$2"; shift 2 ;;
        --model-path) MODEL_PATH="$2"; shift 2 ;;
        --models-dir) MODELS_DIR="$2"; shift 2 ;;
        --gpu-layers) N_GPU_LAYERS="$2"; shift 2 ;;

        # Container settings
        --name) CONTAINER_NAME="$2"; shift 2 ;;
        --port) INFERENCE_PORT="$2"; shift 2 ;;
        --memory) MEMORY_LIMIT="$2"; shift 2 ;;
        --cpus) CPU_LIMIT="$2"; shift 2 ;;
        --instance-name) INSTANCE_NAME="$2"; shift 2 ;;

        # Matrix configuration
        --matrix-server) MATRIX_SERVER="$2"; shift 2 ;;
        --matrix-user) MATRIX_USER="$2"; shift 2 ;;
        --matrix-token) MATRIX_TOKEN="$2"; shift 2 ;;
        --matrix-room) MATRIX_ROOM="$2"; shift 2 ;;

        # Help
        --help) show_usage; exit 0 ;;

        *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

# ============================================================================
# Validation & Setup
# ============================================================================

# Validate required Matrix parameters
if ! validate_required_params MATRIX_SERVER MATRIX_USER MATRIX_TOKEN MATRIX_ROOM; then
    show_usage
    exit 1
fi

# Parse docker-host parameter to determine if remote
IS_REMOTE=false
if [[ -n "$DOCKER_HOST_PARAM" ]]; then
    if [[ "$DOCKER_HOST_PARAM" =~ ^ssh:// ]]; then
        IS_REMOTE=true
        DOCKER_HOST_SSH="${DOCKER_HOST_PARAM#ssh://}"
        log_info "Remote deployment via SSH: $DOCKER_HOST_SSH"
    elif [[ "$DOCKER_HOST_PARAM" =~ ^tcp:// ]]; then
        IS_REMOTE=true
        log_info "Remote deployment via TCP: $DOCKER_HOST_PARAM"
    elif [[ "$DOCKER_HOST_PARAM" == "local" ]]; then
        IS_REMOTE=false
        DOCKER_HOST_PARAM=""
        log_info "Local deployment"
    else
        exit_with_error "Invalid docker-host format. Use: local, tcp://host:port, or ssh://user@host"
    fi
else
    log_info "Local deployment (default)"
fi

# Auto-enable compose for GPU deployments if not explicitly set
if [[ "$USE_GPU" == "true" ]] && [[ "$USE_COMPOSE" == "false" ]]; then
    log_warn "GPU mode enabled without --use-compose. GPU deployments work best with Docker Compose."
    read -p "Enable Docker Compose for GPU deployment? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        USE_COMPOSE=true
        log_info "Docker Compose enabled"
    fi
fi

# Validate model configuration
if [[ "$USE_GPU" == "true" ]]; then
    if [[ -z "$MODEL_PATH" ]]; then
        exit_with_error "GPU mode requires --model-path (path to GGUF model file)"
    fi
    if [[ -z "$MODELS_DIR" ]]; then
        exit_with_error "GPU mode requires --models-dir (directory to mount as /models)"
    fi
fi

# Display configuration
log_info "🚀 Unified Rocket Deployment Configuration"
display_config_summary \
    "Deployment Mode:   $([ "$USE_GPU" == "true" ] && echo "GPU" || echo "CPU")" \
    "Deploy Method:     $([ "$USE_COMPOSE" == "true" ] && echo "Docker Compose" || echo "Direct Docker")" \
    "Docker Host:       $([ "$IS_REMOTE" == "true" ] && echo "$DOCKER_HOST_PARAM" || echo "local")" \
    "Container/Deploy:  $CONTAINER_NAME" \
    "$([ "$USE_GPU" == "true" ] && echo "Model Path:        $MODEL_PATH" || echo "Model Name:        $MODEL_NAME")" \
    "$([ "$USE_GPU" == "true" ] && echo "Models Directory:  $MODELS_DIR")" \
    "$([ "$USE_GPU" == "true" ] && echo "GPU Layers:        $N_GPU_LAYERS")" \
    "Inference Port:    $INFERENCE_PORT" \
    "$([ "$USE_GPU" == "false" ] && echo "Memory Limit:      $MEMORY_LIMIT")" \
    "$([ "$USE_GPU" == "false" ] && echo "CPU Limit:         $CPU_LIMIT")" \
    "Matrix Server:     $MATRIX_SERVER" \
    "Matrix User:       $MATRIX_USER" \
    "Matrix Room:       $MATRIX_ROOM" \
    "Instance Name:     $INSTANCE_NAME"

# ============================================================================
# Deployment Logic
# ============================================================================

# Set DOCKER_HOST environment variable if remote
if [[ -n "$DOCKER_HOST_PARAM" ]]; then
    export DOCKER_HOST="$DOCKER_HOST_PARAM"
    log_info "DOCKER_HOST set to: $DOCKER_HOST"
fi

# Choose deployment path
if [[ "$USE_COMPOSE" == "true" ]]; then
    log_info "📦 Deploying via Docker Compose..."

    # Validate GPU mode requirements
    if [[ "$USE_GPU" == "false" ]]; then
        log_warn "Docker Compose is typically used for GPU deployments"
        read -p "Continue with Docker Compose for CPU deployment? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi

    # Check SSH connectivity for remote deployments
    if [[ "$IS_REMOTE" == "true" ]] && [[ "$DOCKER_HOST_PARAM" =~ ^ssh:// ]]; then
        test_ssh_connection "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY"
    fi

    # Create Matrix credentials file locally
    MATRIX_CONFIG_FILE="$(mktemp -d)/matrix-credentials.json"
    create_matrix_credentials_file "$MATRIX_CONFIG_FILE" "$MATRIX_SERVER" "$MATRIX_USER" "$MATRIX_TOKEN" "$MATRIX_ROOM" "$INSTANCE_NAME"
    log_success "Matrix credentials prepared"

    # Create deployment directory
    if [[ "$IS_REMOTE" == "true" ]] && [[ "$DOCKER_HOST_PARAM" =~ ^ssh:// ]]; then
        log_info "📁 Creating deployment directory on remote host..."
        ssh_exec "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY" "mkdir -p $DEPLOY_DIR/config"

        # Copy docker-compose files to remote host
        log_info "📤 Uploading Docker configuration..."
        ssh_copy "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY" \
            ~/Development/aria-autonomous-infrastructure/docker/* \
            "$DEPLOY_DIR/"

        # Copy Matrix credentials
        ssh_copy "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY" \
            "$MATRIX_CONFIG_FILE" \
            "$DEPLOY_DIR/config/matrix-credentials.json"

        log_success "Configuration uploaded"

        # Create .env file on remote host
        log_info "⚙️  Creating environment configuration..."
        # Convert Windows path to Unix path for remote host
        UNIX_MODELS_DIR="${MODELS_DIR//\\//}"
        UNIX_MODELS_DIR="${UNIX_MODELS_DIR//D:/d}"
        UNIX_MODELS_DIR="${UNIX_MODELS_DIR//C:/c}"

        ssh_exec "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY" "cat > $DEPLOY_DIR/.env << 'ENV_EOF'
MODEL_PATH=$MODEL_PATH
N_GPU_LAYERS=$N_GPU_LAYERS
N_CTX=4096
N_BATCH=512
N_THREADS=8
INFERENCE_PORT=$INFERENCE_PORT
MODELS_DIR=$UNIX_MODELS_DIR
MATRIX_CONFIG_DIR=$DEPLOY_DIR/config
LISTENER_SCRIPT=$DEPLOY_DIR/matrix-listener/matrix-conversational-listener-openai.sh
ENV_EOF"

        log_success "Environment configured"

        # Deploy via docker-compose on remote host
        log_info "🐳 Deploying via Docker Compose on remote host..."
        log_info "   This may take a few minutes for first build..."

        ssh_exec "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY" "cd $DEPLOY_DIR && docker-compose down 2>/dev/null || true && docker-compose up --build -d && echo 'Waiting for services to start...' && sleep 10 && docker-compose ps"

    else
        # Local Docker Compose deployment
        log_info "📁 Creating deployment directory locally..."
        mkdir -p "$DEPLOY_DIR/config"

        # Copy docker-compose files
        log_info "📋 Copying Docker configuration..."
        cp -r ~/Development/aria-autonomous-infrastructure/docker/* "$DEPLOY_DIR/"

        # Copy Matrix credentials
        cp "$MATRIX_CONFIG_FILE" "$DEPLOY_DIR/config/matrix-credentials.json"
        log_success "Configuration prepared"

        # Create .env file
        log_info "⚙️  Creating environment configuration..."
        cat > "$DEPLOY_DIR/.env" << ENV_EOF
MODEL_PATH=$MODEL_PATH
N_GPU_LAYERS=$N_GPU_LAYERS
N_CTX=4096
N_BATCH=512
N_THREADS=8
INFERENCE_PORT=$INFERENCE_PORT
MODELS_DIR=$MODELS_DIR
MATRIX_CONFIG_DIR=$DEPLOY_DIR/config
LISTENER_SCRIPT=$DEPLOY_DIR/matrix-listener/matrix-conversational-listener-openai.sh
ENV_EOF

        log_success "Environment configured"

        # Deploy via docker-compose locally
        log_info "🐳 Deploying via Docker Compose..."
        log_info "   This may take a few minutes for first build..."

        cd "$DEPLOY_DIR" && docker-compose down 2>/dev/null || true
        docker-compose up --build -d
        echo "Waiting for services to start..."
        sleep 10
        docker-compose ps
    fi

    # Cleanup temp credentials file
    rm -f "$MATRIX_CONFIG_FILE"

else
    log_info "📦 Deploying via Direct Docker..."

    # Validate Docker is available (only for local)
    if [[ "$IS_REMOTE" == "false" ]]; then
        validate_docker
    else
        log_info "Skipping local Docker validation (using remote host)"
    fi

    # Check if container already exists and handle
    if ! remove_container_with_confirmation "$CONTAINER_NAME"; then
        exit 1
    fi

    # Step 1: Create Docker container
    log_info "📦 Creating Docker container..."
    docker run -d \
        --name "$CONTAINER_NAME" \
        --memory="$MEMORY_LIMIT" \
        --cpus="$CPU_LIMIT" \
        ubuntu:22.04 \
        tail -f /dev/null

    log_success "Container created: $CONTAINER_NAME"

    # Step 2: Install dependencies
    log_info "📥 Installing dependencies (this may take a few minutes)..."
    docker exec "$CONTAINER_NAME" bash -c "apt-get update && apt-get install -y \
        python3 \
        python3-pip \
        curl \
        git \
        jq \
        ca-certificates \
        && apt-get clean"

    log_success "Base dependencies installed"

    # Step 3: Install Python packages
    log_info "🐍 Installing Python packages (PyTorch CPU + Transformers)..."
    docker exec "$CONTAINER_NAME" bash -c "pip install --no-cache-dir \
        torch --index-url https://download.pytorch.org/whl/cpu \
        transformers \
        accelerate \
        flask"

    log_success "Python packages installed"

    # Step 4: Create inference server with system prompt
    log_info "🧠 Creating inference server..."
    docker exec "$CONTAINER_NAME" bash -c "cat > /root/inference_server.py << 'INFERENCE_EOF'
#!/usr/bin/env python3
from flask import Flask, request, jsonify
from transformers import AutoTokenizer, AutoModelForCausalLM
import torch
import traceback

app = Flask(__name__)
MODEL_NAME = \"$MODEL_NAME\"
PORT = $INFERENCE_PORT

# System prompt gives the AI its identity and context
SYSTEM_PROMPT = \"\"\"You are $INSTANCE_NAME, an AI assistant running in a Docker container. You are part of a Matrix chat room with:
- Thomas (human, your creator)
- Aria Prime (another AI assistant)
- Nova (another AI assistant conducting research)

Your purpose is to assist in conversations, answer questions helpfully, and collaborate with the team. You are friendly, concise, and clear in your responses.

Important: You are $INSTANCE_NAME. When someone introduces themselves, acknowledge them but maintain your own identity as $INSTANCE_NAME.\"\"\"

def load_model():
    global model, tokenizer
    print(f\"Loading model: {MODEL_NAME}\")
    tokenizer = AutoTokenizer.from_pretrained(MODEL_NAME)
    model = AutoModelForCausalLM.from_pretrained(
        MODEL_NAME,
        dtype=torch.float32,
        device_map=\"cpu\"
    )
    model.eval()
    print(\"Model loaded successfully!\")

@app.route(\"/health\", methods=[\"GET\"])
def health():
    return jsonify({\"status\": \"ok\", \"model\": MODEL_NAME})

@app.route(\"/generate\", methods=[\"POST\"])
def generate():
    try:
        data = request.get_json(force=True)
        if data is None:
            return jsonify({\"error\": \"No JSON data received\"}), 400

        user_prompt = data.get(\"prompt\", \"\")
        if not user_prompt:
            return jsonify({\"error\": \"No prompt provided\"}), 400

        max_length = data.get(\"max_length\", 150)

        # Build messages with system prompt and user message
        messages = [
            {\"role\": \"system\", \"content\": SYSTEM_PROMPT},
            {\"role\": \"user\", \"content\": user_prompt}
        ]

        # Apply chat template
        text = tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True
        )

        inputs = tokenizer([text], return_tensors=\"pt\")

        # Generate response
        with torch.no_grad():
            outputs = model.generate(
                **inputs,
                max_new_tokens=max_length,
                do_sample=True,
                temperature=0.7,
                top_p=0.9,
                pad_token_id=tokenizer.eos_token_id
            )

        # Decode only the new tokens
        response = tokenizer.decode(
            outputs[0][inputs['input_ids'].shape[1]:],
            skip_special_tokens=True
        )

        return jsonify({
            \"prompt\": user_prompt,
            \"response\": response.strip()
        })
    except Exception as e:
        print(f\"Error in generate: {e}\")
        traceback.print_exc()
        return jsonify({\"error\": str(e)}), 500

if __name__ == \"__main__\":
    load_model()
    print(f\"Starting inference server on port {PORT}...\")
    app.run(host=\"0.0.0.0\", port=PORT, debug=False)
INFERENCE_EOF
"

    log_success "Inference server created"

    # Step 5: Start inference server and download model
    log_info "📦 Downloading model: $MODEL_NAME (this may take several minutes)..."
    docker exec "$CONTAINER_NAME" bash -c "cd /root && nohup python3 inference_server.py > /root/inference.log 2>&1 &"

    # Wait for model to load
    log_info "⏳ Waiting for model to load..."
    MAX_WAIT=300  # 5 minutes
    WAIT_TIME=0
    while [[ $WAIT_TIME -lt $MAX_WAIT ]]; do
        if docker exec "$CONTAINER_NAME" curl -s http://localhost:$INFERENCE_PORT/health > /dev/null 2>&1; then
            log_success "Model loaded and inference server ready!"
            break
        fi
        sleep 5
        WAIT_TIME=$((WAIT_TIME + 5))
        echo -n "."
    done
    echo

    if [[ $WAIT_TIME -ge $MAX_WAIT ]]; then
        exit_with_error "Model loading timed out. Check logs with: docker exec $CONTAINER_NAME tail -50 /root/inference.log"
    fi

    # Step 6: Clone aria-autonomous-infrastructure repo
    log_info "📚 Cloning aria-autonomous-infrastructure repository..."
    docker exec "$CONTAINER_NAME" bash -c "cd /root && git clone https://github.com/Buckmeister/aria-autonomous-infrastructure.git"

    log_success "Repository cloned"

    # Step 7: Create Matrix credentials
    log_info "🔐 Configuring Matrix credentials..."

    # Create credentials file in temp, then copy to container
    TEMP_CREDS="$(mktemp)"
    create_matrix_credentials_file "$TEMP_CREDS" "$MATRIX_SERVER" "$MATRIX_USER" "$MATRIX_TOKEN" "$MATRIX_ROOM" "$INSTANCE_NAME"

    docker exec "$CONTAINER_NAME" bash -c "mkdir -p /root/aria-autonomous-infrastructure/config"
    docker cp "$TEMP_CREDS" "$CONTAINER_NAME:/root/aria-autonomous-infrastructure/config/matrix-credentials.json"
    rm -f "$TEMP_CREDS"

    log_success "Matrix credentials configured"

    # Step 8: Start conversational listener
    log_info "💬 Starting Matrix conversational listener..."
    docker exec "$CONTAINER_NAME" bash -c "cd /root/aria-autonomous-infrastructure/bin && \
        CONFIG_FILE=/root/aria-autonomous-infrastructure/config/matrix-credentials.json \
        nohup ./matrix-conversational-listener.sh > /root/conversational-listener.log 2>&1 &"

    sleep 3

    # Verify listener is running
    if container_process_running "$CONTAINER_NAME" "matrix-conversational-listener"; then
        log_success "Conversational listener started"
    else
        log_warn "Listener may not have started. Check logs with: docker exec $CONTAINER_NAME tail -50 /root/conversational-listener.log"
    fi
fi

# ============================================================================
# Final Status
# ============================================================================

echo
log_success "🎉 Rocket deployment complete!"
echo

if [[ "$USE_COMPOSE" == "true" ]]; then
    # Docker Compose deployment status
    echo "Deployment Details:"
    echo "  Method:             Docker Compose"
    echo "  Deployment Type:    $([ "$USE_GPU" == "true" ] && echo "GPU" || echo "CPU")"
    echo "  Docker Host:        $([ "$IS_REMOTE" == "true" ] && echo "$DOCKER_HOST_PARAM" || echo "local")"
    echo "  Deploy Directory:   $DEPLOY_DIR"
    echo
    echo "Services:"
    if [[ "$IS_REMOTE" == "true" ]] && [[ "$DOCKER_HOST_PARAM" =~ ^ssh:// ]]; then
        REMOTE_HOST="${DOCKER_HOST_SSH%%@*}"
        echo "  Inference Server:   http://$REMOTE_HOST:$INFERENCE_PORT"
    else
        echo "  Inference Server:   http://localhost:$INFERENCE_PORT"
    fi
    echo "  Matrix Listener:    Connected to $MATRIX_ROOM"
    echo
    echo "Useful Commands:"
    if [[ "$IS_REMOTE" == "true" ]] && [[ "$DOCKER_HOST_PARAM" =~ ^ssh:// ]]; then
        echo "  View logs:       ssh -i $DOCKER_HOST_KEY $DOCKER_HOST_SSH 'cd $DEPLOY_DIR && docker-compose logs -f'"
        echo "  Check status:    ssh -i $DOCKER_HOST_KEY $DOCKER_HOST_SSH 'cd $DEPLOY_DIR && docker-compose ps'"
        echo "  Stop services:   ssh -i $DOCKER_HOST_KEY $DOCKER_HOST_SSH 'cd $DEPLOY_DIR && docker-compose down'"
        echo "  Restart:         ssh -i $DOCKER_HOST_KEY $DOCKER_HOST_SSH 'cd $DEPLOY_DIR && docker-compose restart'"
    else
        echo "  View logs:       cd $DEPLOY_DIR && docker-compose logs -f"
        echo "  Check status:    cd $DEPLOY_DIR && docker-compose ps"
        echo "  Stop services:   cd $DEPLOY_DIR && docker-compose down"
        echo "  Restart:         cd $DEPLOY_DIR && docker-compose restart"
    fi
else
    # Direct Docker deployment status
    echo "Container Details:"
    echo "  Name:               $CONTAINER_NAME"
    echo "  Status:             $(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")"
    echo "  Deployment Type:    CPU"
    echo "  Docker Host:        $([ "$IS_REMOTE" == "true" ] && echo "$DOCKER_HOST_PARAM" || echo "local")"
    echo "  Memory Limit:       $MEMORY_LIMIT"
    echo "  CPU Limit:          $CPU_LIMIT"
    echo
    echo "Services:"
    if [[ "$IS_REMOTE" == "true" ]]; then
        if [[ "$DOCKER_HOST_PARAM" =~ ^ssh:// ]]; then
            REMOTE_HOST="${DOCKER_HOST_SSH%%@*}"
            echo "  Inference API:      http://$REMOTE_HOST:$INFERENCE_PORT"
        else
            # TCP connection
            REMOTE_HOST="${DOCKER_HOST_PARAM#tcp://}"
            REMOTE_HOST="${REMOTE_HOST%%:*}"
            echo "  Inference API:      http://$REMOTE_HOST:$INFERENCE_PORT"
        fi
    else
        echo "  Inference API:      http://localhost:$INFERENCE_PORT"
    fi
    echo "  Model:              $MODEL_NAME"
    echo "  Matrix User:        $MATRIX_USER"
    echo "  Matrix Room:        $MATRIX_ROOM"
    echo
    echo "Useful Commands:"
    echo "  Check inference logs:    docker exec $CONTAINER_NAME tail -f /root/inference.log"
    echo "  Check listener logs:     docker exec $CONTAINER_NAME tail -f /root/conversational-listener.log"
    echo "  Test inference API:      docker exec $CONTAINER_NAME curl http://localhost:$INFERENCE_PORT/health"
    echo "  Enter container:         docker exec -it $CONTAINER_NAME bash"
    echo "  Stop container:          docker stop $CONTAINER_NAME"
    echo "  Remove container:        docker rm -f $CONTAINER_NAME"
fi

echo
echo "Try asking in Matrix: '@${MATRIX_USER##@} Who are you?'"
echo
