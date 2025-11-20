#!/bin/bash
# launch-rocket-gpu.sh - Deploy GPU-accelerated Rocket via Docker Compose
# 
# Deploys Rocket on remote Docker host with GPU support
# Uses existing model files from LM Studio (no downloads!)
# Supports rapid model switching via command-line

set -e

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

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

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
if [[ -z "$MATRIX_SERVER" ]] || [[ -z "$MATRIX_USER" ]] || [[ -z "$MATRIX_TOKEN" ]] || [[ -z "$MATRIX_ROOM" ]]; then
    log_error "Missing required Matrix parameters"
    show_usage
    exit 1
fi

log_info "🚀 Rocket GPU Deployment"
echo "Docker Host:      $DOCKER_HOST_SSH"
echo "Model:            $MODEL_PATH"
echo "GPU Layers:       $N_GPU_LAYERS"
echo "Matrix Server:    $MATRIX_SERVER"
echo "Matrix User:      $MATRIX_USER"
echo "Matrix Room:      $MATRIX_ROOM"
echo "Instance Name:    $INSTANCE_NAME"
echo "Inference Port:   $INFERENCE_PORT"
echo

# Check SSH connectivity
log_info "🔌 Testing SSH connection to $DOCKER_HOST_SSH..."
if ! ssh -i "$DOCKER_HOST_KEY" "$DOCKER_HOST_SSH" "echo Connected" > /dev/null 2>&1; then
    log_error "Cannot connect to $DOCKER_HOST_SSH"
    exit 1
fi
log_success "SSH connection OK"

# Create Matrix credentials file locally
MATRIX_CONFIG_FILE="$(mktemp -d)/matrix-credentials.json"
cat > "$MATRIX_CONFIG_FILE" << MATRIX_EOF
{
  "homeserver": "$MATRIX_SERVER",
  "user_id": "$MATRIX_USER",
  "access_token": "$MATRIX_TOKEN",
  "room_id": "$MATRIX_ROOM",
  "instance_name": "$INSTANCE_NAME"
}
MATRIX_EOF

log_success "Matrix credentials prepared"

# Create deployment directory on remote host
log_info "📁 Creating deployment directory on remote host..."
ssh -i "$DOCKER_HOST_KEY" "$DOCKER_HOST_SSH" "mkdir -p $DEPLOY_DIR/config"

# Copy docker-compose files to remote host
log_info "📤 Uploading Docker configuration..."
scp -i "$DOCKER_HOST_KEY" -r \
    ~/Development/aria-autonomous-infrastructure/docker/* \
    "$DOCKER_HOST_SSH:$DEPLOY_DIR/"

# Copy Matrix credentials
scp -i "$DOCKER_HOST_KEY" "$MATRIX_CONFIG_FILE" \
    "$DOCKER_HOST_SSH:$DEPLOY_DIR/config/matrix-credentials.json"

rm -f "$MATRIX_CONFIG_FILE"

log_success "Configuration uploaded"

# Create .env file on remote host
log_info "⚙️  Creating environment configuration..."
ssh -i "$DOCKER_HOST_KEY" "$DOCKER_HOST_SSH" "cat > $DEPLOY_DIR/.env" << ENV_EOF
MODEL_PATH=$MODEL_PATH
N_GPU_LAYERS=$N_GPU_LAYERS
N_CTX=4096
N_BATCH=512
N_THREADS=8
INFERENCE_PORT=$INFERENCE_PORT
MODELS_DIR=/d/Models
MATRIX_CONFIG_DIR=$DEPLOY_DIR/config
LISTENER_SCRIPT=$DEPLOY_DIR/matrix-listener/matrix-conversational-listener-openai.sh
ENV_EOF

log_success "Environment configured"

# Deploy via docker-compose
log_info "🐳 Deploying via Docker Compose..."
log_info "   This may take a few minutes for first build..."

ssh -i "$DOCKER_HOST_KEY" "$DOCKER_HOST_SSH" << REMOTE_EOF
cd $DEPLOY_DIR
docker-compose down 2>/dev/null || true
docker-compose up --build -d
echo "Waiting for services to start..."
sleep 10
docker-compose ps
REMOTE_EOF

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
