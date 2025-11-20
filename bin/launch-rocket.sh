#!/bin/bash
# launch-rocket.sh - Deploy a conversational AI instance with local LLM
#
# This script automates the complete deployment of a "Rocket" conversational AI:
# - Creates Docker container with Ubuntu
# - Installs PyTorch CPU + Transformers
# - Downloads and serves an LLM via Flask inference API
# - Connects to Matrix with conversational listener
# - Provides the AI with identity context via system prompt
#
# Usage: ./launch-rocket.sh --name rocket-v2 --model Qwen/Qwen2.5-0.5B-Instruct \
#                            --matrix-server http://srv1:8008 \
#                            --matrix-user @rocket:srv1.local \
#                            --matrix-token syt_... \
#                            --matrix-room !abc:srv1.local

set -e

# Load shared deployment utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
source "$LIB_DIR/deployment_utils.sh"

# Default values
CONTAINER_NAME="rocket-instance"
MODEL_NAME="Qwen/Qwen2.5-0.5B-Instruct"
INFERENCE_PORT=8080
MEMORY_LIMIT="4g"
CPU_LIMIT="2"
MATRIX_SERVER=""
MATRIX_USER=""
MATRIX_TOKEN=""
MATRIX_ROOM=""
INSTANCE_NAME="Rocket"

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy a conversational AI instance with local LLM inference and Matrix integration.

Required Options:
  --matrix-server URL    Matrix homeserver URL (e.g., http://srv1:8008)
  --matrix-user ID       Matrix user ID (e.g., @rocket:srv1.local)
  --matrix-token TOKEN   Matrix access token
  --matrix-room ID       Matrix room ID (e.g., !abc:srv1.local)

Optional:
  --name NAME           Container name (default: rocket-instance)
  --model MODEL         HuggingFace model ID (default: Qwen/Qwen2.5-0.5B-Instruct)
  --port PORT           Inference API port (default: 8080)
  --memory LIMIT        Container memory limit (default: 4g)
  --cpus NUM            Container CPU limit (default: 2)
  --instance-name NAME  Display name for Matrix (default: Rocket)
  --help                Show this help message

Examples:
  # Basic deployment
  $0 --matrix-server http://srv1:8008 \\
     --matrix-user @rocket:srv1.local \\
     --matrix-token syt_cm9ja2V0_abc123 \\
     --matrix-room '!UCEurIvKNNMvYlrntC:srv1.local'

  # Custom model and container name
  $0 --name rocket-v2 \\
     --model microsoft/phi-2 \\
     --matrix-server http://srv1:8008 \\
     --matrix-user @rocketv2:srv1.local \\
     --matrix-token syt_... \\
     --matrix-room '!abc:srv1.local'

Models to try:
  - Qwen/Qwen2.5-0.5B-Instruct      (~500MB, very fast)
  - Qwen/Qwen2.5-1.5B-Instruct      (~1.5GB, balanced)
  - microsoft/phi-2                  (~2.7GB, high quality)
  - mistralai/Mistral-7B-Instruct-v0.2  (~14GB, powerful)

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --model)
            MODEL_NAME="$2"
            shift 2
            ;;
        --port)
            INFERENCE_PORT="$2"
            shift 2
            ;;
        --memory)
            MEMORY_LIMIT="$2"
            shift 2
            ;;
        --cpus)
            CPU_LIMIT="$2"
            shift 2
            ;;
        --matrix-server)
            MATRIX_SERVER="$2"
            shift 2
            ;;
        --matrix-user)
            MATRIX_USER="$2"
            shift 2
            ;;
        --matrix-token)
            MATRIX_TOKEN="$2"
            shift 2
            ;;
        --matrix-room)
            MATRIX_ROOM="$2"
            shift 2
            ;;
        --instance-name)
            INSTANCE_NAME="$2"
            shift 2
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if ! validate_required_params MATRIX_SERVER MATRIX_USER MATRIX_TOKEN MATRIX_ROOM; then
    show_usage
    exit 1
fi

# Display configuration summary
log_info "🚀 Rocket Deployment Configuration"
display_config_summary \
    "Container:       $CONTAINER_NAME" \
    "Model:           $MODEL_NAME" \
    "Inference Port:  $INFERENCE_PORT" \
    "Memory Limit:    $MEMORY_LIMIT" \
    "CPU Limit:       $CPU_LIMIT" \
    "Matrix Server:   $MATRIX_SERVER" \
    "Matrix User:     $MATRIX_USER" \
    "Matrix Room:     $MATRIX_ROOM" \
    "Instance Name:   $INSTANCE_NAME"

# Validate Docker is running
validate_docker

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

# Step 5: Download model (this is the longest step)
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

# Final status
echo
log_success "🎉 Rocket deployment complete!"
echo
echo "Container Details:"
echo "  Name:               $CONTAINER_NAME"
echo "  Status:             $(docker inspect -f '{{.State.Status}}' "$CONTAINER_NAME")"
echo "  Memory Limit:       $MEMORY_LIMIT"
echo "  CPU Limit:          $CPU_LIMIT"
echo
echo "Services:"
echo "  Inference API:      http://localhost:$INFERENCE_PORT"
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
echo
echo "Try asking in Matrix: '@${MATRIX_USER##@} Who are you?'"
echo

