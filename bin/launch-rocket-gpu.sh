#!/bin/bash
# launch-rocket-gpu.sh - Deploy GPU-accelerated Rocket via Docker Compose
#
# Deploys Rocket on remote Docker host with GPU support
# Uses existing model files from LM Studio (no downloads!)
# Supports rapid model switching via command-line

set -e

# Load shared deployment utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
source "$LIB_DIR/deployment_utils.sh"

# Defaults
DOCKER_HOST_SSH="Aria@wks-bckx01"
DOCKER_HOST_KEY="$HOME/.aria/ssh/aria_wks-bckx01"
MODELS_DIR="D:\\Models"  # Windows path
MATRIX_SERVER=""
MATRIX_USER=""
MATRIX_TOKEN=""
MATRIX_ROOM=""
INSTANCE_NAME="Rocket"
MODEL_PATH="/models/LM-Studio/lmstudio-community/gemma-3-12b-it-GGUF/gemma-3-12b-it-Q4_K_M.gguf"
N_GPU_LAYERS="-1"  # -1 = all layers on GPU
INFERENCE_PORT="8080"
DEPLOY_DIR="/tmp/rocket-gpu-deploy"

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy GPU-accelerated Rocket on wks-bckx01 via Docker Compose

Required:
  --matrix-server URL    Matrix homeserver (e.g., http://srv1:8008)
  --matrix-user ID       Matrix user ID (e.g., @rocket:srv1.local)
  --matrix-token TOKEN   Matrix access token
  --matrix-room ID       Matrix room ID

Optional:
  --model PATH          Model path in /models (default: gemma-3-12b-it)
  --list-models         List available models on wks-bckx01
  --gpu-layers N        GPU layers (-1=all, default: -1)
  --port PORT           Inference port (default: 8080)
  --instance-name NAME  Display name (default: Rocket)
  --docker-host USER@HOST   Docker host SSH (default: Aria@wks-bckx01)
  --help                Show this help

Examples:
  # List available models
  $0 --list-models

  # Deploy with default model (gemma-3-12b)
  $0 --matrix-server http://srv1:8008 \\
     --matrix-user @rocket:srv1.local \\
     --matrix-token syt_... \\
     --matrix-room '!abc:srv1.local'

  # Deploy with specific model
  $0 --model "/models/LM-Studio/lmstudio-community/Mistral-Small-3.2-24B-Instruct-2506-GGUF/Mistral-Small-3.2-24B-Instruct-2506-Q4_K_M.gguf" \\
     --matrix-server http://srv1:8008 \\
     --matrix-user @rocket2:srv1.local \\
     --matrix-token syt_... \\
     --matrix-room '!abc:srv1.local'

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --matrix-server) MATRIX_SERVER="$2"; shift 2 ;;
        --matrix-user) MATRIX_USER="$2"; shift 2 ;;
        --matrix-token) MATRIX_TOKEN="$2"; shift 2 ;;
        --matrix-room) MATRIX_ROOM="$2"; shift 2 ;;
        --model) MODEL_PATH="$2"; shift 2 ;;
        --list-models) LIST_MODELS=1; shift ;;
        --gpu-layers) N_GPU_LAYERS="$2"; shift 2 ;;
        --port) INFERENCE_PORT="$2"; shift 2 ;;
        --instance-name) INSTANCE_NAME="$2"; shift 2 ;;
        --docker-host) DOCKER_HOST_SSH="$2"; shift 2 ;;
        --help) show_usage; exit 0 ;;
        *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
    esac
done

# List models mode
if [[ -n "$LIST_MODELS" ]]; then
    log_info "📦 Available models on wks-bckx01:"
    ssh -i "$DOCKER_HOST_KEY" "$DOCKER_HOST_SSH" \
        'powershell "Get-ChildItem D:\Models\LM-Studio -Recurse -Include *.gguf | Select-Object Name,@{N=\"Size(GB)\";E={[math]::Round(\$_.Length/1GB,2)}},FullName | Format-Table -AutoSize"'
    exit 0
fi

# Validate required parameters
if ! validate_required_params MATRIX_SERVER MATRIX_USER MATRIX_TOKEN MATRIX_ROOM; then
    show_usage
    exit 1
fi

# Display configuration summary
log_info "🚀 Rocket GPU Deployment"
display_config_summary \
    "Docker Host:      $DOCKER_HOST_SSH" \
    "Model:            $MODEL_PATH" \
    "GPU Layers:       $N_GPU_LAYERS" \
    "Matrix Server:    $MATRIX_SERVER" \
    "Matrix User:      $MATRIX_USER" \
    "Matrix Room:      $MATRIX_ROOM" \
    "Instance Name:    $INSTANCE_NAME" \
    "Inference Port:   $INFERENCE_PORT"

# Check SSH connectivity
test_ssh_connection "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY"

# Create Matrix credentials file locally
MATRIX_CONFIG_FILE="$(mktemp -d)/matrix-credentials.json"
create_matrix_credentials_file "$MATRIX_CONFIG_FILE" "$MATRIX_SERVER" "$MATRIX_USER" "$MATRIX_TOKEN" "$MATRIX_ROOM" "$INSTANCE_NAME"

log_success "Matrix credentials prepared"

# Create deployment directory on remote host
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

rm -f "$MATRIX_CONFIG_FILE"

log_success "Configuration uploaded"

# Create .env file on remote host
log_info "⚙️  Creating environment configuration..."
ssh_exec "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY" "cat > $DEPLOY_DIR/.env << 'ENV_EOF'
MODEL_PATH=$MODEL_PATH
N_GPU_LAYERS=$N_GPU_LAYERS
N_CTX=4096
N_BATCH=512
N_THREADS=8
INFERENCE_PORT=$INFERENCE_PORT
MODELS_DIR=/d/Models
MATRIX_CONFIG_DIR=$DEPLOY_DIR/config
LISTENER_SCRIPT=$DEPLOY_DIR/matrix-listener/matrix-conversational-listener-openai.sh
ENV_EOF"

log_success "Environment configured"

# Deploy via docker-compose
log_info "🐳 Deploying via Docker Compose..."
log_info "   This may take a few minutes for first build..."

ssh_exec "$DOCKER_HOST_SSH" "$DOCKER_HOST_KEY" "cd $DEPLOY_DIR && docker-compose down 2>/dev/null || true && docker-compose up --build -d && echo 'Waiting for services to start...' && sleep 10 && docker-compose ps"

log_success "🎉 Deployment complete!"
echo
echo "Services deployed:"
echo "  Inference Server: http://wks-bckx01:$INFERENCE_PORT"
echo "  Matrix Listener:  Connected to $MATRIX_ROOM"
echo
echo "Useful commands:"
echo "  View logs:       ssh -i $DOCKER_HOST_KEY $DOCKER_HOST_SSH 'cd $DEPLOY_DIR && docker-compose logs -f'"
echo "  Check status:    ssh -i $DOCKER_HOST_KEY $DOCKER_HOST_SSH 'cd $DEPLOY_DIR && docker-compose ps'"
echo "  Stop services:   ssh -i $DOCKER_HOST_KEY $DOCKER_HOST_SSH 'cd $DEPLOY_DIR && docker-compose down'"
echo "  Restart:         ssh -i $DOCKER_HOST_KEY $DOCKER_HOST_SSH 'cd $DEPLOY_DIR && docker-compose restart'"
echo
echo "Try asking in Matrix: '@$MATRIX_USER Who are you?'"
echo
