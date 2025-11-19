#!/bin/bash
# Create AI Instance - Automated instance configuration generator
# Part of the multi-agent AI collaboration system

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_DIR="$PROJECT_ROOT/config/instances"
REGISTRY_FILE="$CONFIG_DIR/registry.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage information
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Create a new AI instance configuration for the multi-agent collaboration system.

Required Options:
    --name NAME                 Instance name (e.g., "Mistral Philosopher")
    --model MODEL_ID            Model identifier (e.g., "mistralai/mistral-small-3.2")
    --role ROLE                 Instance role (e.g., "philosopher", "reasoner", "interviewer")

Optional Options:
    --capabilities CAPS         Comma-separated capabilities (e.g., "epistemology,ethics")
    --autonomy LEVEL            Autonomy level: interactive|supervised|autonomous (default: supervised)
    --host HOSTNAME             Deployment host (default: wks-bckx01)
    --endpoint URL              Model API endpoint (default: http://wks-bckx01:1234/v1/)
    --temperature TEMP          Model temperature (default: 0.7)
    --max-tokens TOKENS         Max tokens per response (default: 2000)
    --matrix-user USERNAME      Matrix username (auto-generated if not provided)
    --matrix-room ROOM_ID       Matrix room ID (default: main collaboration room)
    --create-matrix-user        Actually create the Matrix account (requires manual setup)
    --deploy                    Deploy configuration to remote host
    --help                      Show this help message

Examples:
    # Create a philosophical analysis instance
    $0 --name "Mistral Philosopher" \\
       --model "mistralai/mistral-small-3.2" \\
       --role "philosopher" \\
       --capabilities "epistemology,phenomenology,ethics"

    # Create an autonomous interviewer
    $0 --name "Gemma Interviewer" \\
       --model "google/gemma-2-9b-it" \\
       --role "interviewer" \\
       --autonomy "autonomous" \\
       --capabilities "consciousness-studies,interviews"

    # Create and deploy a reasoning instance
    $0 --name "DeepSeek Reasoner" \\
       --model "deepseek/deepseek-r1-0528-qwen3-8b" \\
       --role "reasoner" \\
       --capabilities "reasoning,analysis" \\
       --deploy

EOF
    exit 1
}

# Parse command line arguments
INSTANCE_NAME=""
MODEL_ID=""
ROLE=""
CAPABILITIES=""
AUTONOMY_LEVEL="supervised"
HOST="wks-bckx01"
ENDPOINT="http://wks-bckx01:1234/v1/"
TEMPERATURE="0.7"
MAX_TOKENS="2000"
MATRIX_USER=""
MATRIX_ROOM="!UCEurIvKNNMvYlrntC:srv1.local"
CREATE_MATRIX_USER=false
DEPLOY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --name)
            INSTANCE_NAME="$2"
            shift 2
            ;;
        --model)
            MODEL_ID="$2"
            shift 2
            ;;
        --role)
            ROLE="$2"
            shift 2
            ;;
        --capabilities)
            CAPABILITIES="$2"
            shift 2
            ;;
        --autonomy)
            AUTONOMY_LEVEL="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --endpoint)
            ENDPOINT="$2"
            shift 2
            ;;
        --temperature)
            TEMPERATURE="$2"
            shift 2
            ;;
        --max-tokens)
            MAX_TOKENS="$2"
            shift 2
            ;;
        --matrix-user)
            MATRIX_USER="$2"
            shift 2
            ;;
        --matrix-room)
            MATRIX_ROOM="$2"
            shift 2
            ;;
        --create-matrix-user)
            CREATE_MATRIX_USER=true
            shift
            ;;
        --deploy)
            DEPLOY=true
            shift
            ;;
        --help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$INSTANCE_NAME" ]]; then
    echo -e "${RED}Error: --name is required${NC}"
    usage
fi

if [[ -z "$MODEL_ID" ]]; then
    echo -e "${RED}Error: --model is required${NC}"
    usage
fi

if [[ -z "$ROLE" ]]; then
    echo -e "${RED}Error: --role is required${NC}"
    usage
fi

# Validate autonomy level
if [[ ! "$AUTONOMY_LEVEL" =~ ^(interactive|supervised|autonomous)$ ]]; then
    echo -e "${RED}Error: --autonomy must be one of: interactive, supervised, autonomous${NC}"
    exit 1
fi

# Generate instance ID from name
INSTANCE_ID=$(echo "$INSTANCE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '-' | sed 's/[^a-z0-9-]//g')

# Generate Matrix username if not provided
if [[ -z "$MATRIX_USER" ]]; then
    # Create safe username from instance name
    MATRIX_USERNAME=$(echo "$INSTANCE_NAME" | tr '[:upper:]' '[:lower:]' | tr ' ' '' | sed 's/[^a-z0-9]//g')
    MATRIX_USER="@${MATRIX_USERNAME}:srv1.local"
fi

# Parse capabilities into JSON array
CAPABILITIES_JSON="[]"
if [[ -n "$CAPABILITIES" ]]; then
    IFS=',' read -ra CAPS_ARRAY <<< "$CAPABILITIES"
    CAPABILITIES_JSON="["
    for i in "${!CAPS_ARRAY[@]}"; do
        CAP="${CAPS_ARRAY[$i]}"
        CAP=$(echo "$CAP" | xargs) # trim whitespace
        if [[ $i -gt 0 ]]; then
            CAPABILITIES_JSON+=","
        fi
        CAPABILITIES_JSON+="\"$CAP\""
    done
    CAPABILITIES_JSON+="]"
fi

# Create instance config file path
CONFIG_FILE="$CONFIG_DIR/${INSTANCE_ID}.json"

# Check if instance already exists
if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}Warning: Instance '$INSTANCE_ID' already exists at $CONFIG_FILE${NC}"
    read -p "Overwrite? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Aborted.${NC}"
        exit 0
    fi
fi

# Create instance configuration
echo -e "${BLUE}Creating instance configuration...${NC}"

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

cat > "$CONFIG_FILE" << EOF
{
  "instance_name": "$INSTANCE_NAME",
  "instance_id": "$INSTANCE_ID",
  "matrix_user": "$MATRIX_USER",
  "model": {
    "provider": "lm-studio",
    "endpoint": "$ENDPOINT",
    "model_id": "$MODEL_ID",
    "temperature": $TEMPERATURE,
    "max_tokens": $MAX_TOKENS
  },
  "role": "$ROLE",
  "capabilities": $CAPABILITIES_JSON,
  "autonomy_level": "$AUTONOMY_LEVEL",
  "deployment": {
    "host": "$HOST",
    "mode": "api-only"
  },
  "matrix_rooms": [
    "$MATRIX_ROOM"
  ],
  "description": "AI instance created via create-ai-instance.sh",
  "created": "$TIMESTAMP",
  "created_by": "$(whoami)",
  "status": "configured"
}
EOF

echo -e "${GREEN}✓ Created instance configuration: $CONFIG_FILE${NC}"

# Update registry
echo -e "${BLUE}Updating instance registry...${NC}"

if [[ ! -f "$REGISTRY_FILE" ]]; then
    echo -e "${YELLOW}Registry file not found, creating new registry${NC}"
    cat > "$REGISTRY_FILE" << 'EOF'
{
  "version": "1.0",
  "last_updated": "",
  "instances": [],
  "roles": {},
  "capabilities_index": {},
  "statistics": {
    "total_instances": 0,
    "active_instances": 0,
    "inactive_instances": 0,
    "total_roles": 0,
    "total_capabilities": 0
  }
}
EOF
fi

# Use Python to update registry (more reliable than bash JSON manipulation)
python3 << PYTHON_SCRIPT
import json
import sys
from datetime import datetime

registry_file = "$REGISTRY_FILE"
config_file = "$CONFIG_FILE"

# Load registry
with open(registry_file, 'r') as f:
    registry = json.load(f)

# Load new instance config
with open(config_file, 'r') as f:
    instance = json.load(f)

# Check if instance already in registry
instance_ids = [i['instance_id'] for i in registry['instances']]
if instance['instance_id'] in instance_ids:
    # Update existing instance
    for i, inst in enumerate(registry['instances']):
        if inst['instance_id'] == instance['instance_id']:
            registry['instances'][i] = {
                'instance_id': instance['instance_id'],
                'instance_name': instance['instance_name'],
                'matrix_user': instance['matrix_user'],
                'role': instance['role'],
                'capabilities': instance['capabilities'],
                'status': instance['status'],
                'last_seen': instance['created'],
                'host': instance['deployment']['host'],
                'config_file': f"config/instances/{instance['instance_id']}.json"
            }
            break
else:
    # Add new instance
    registry['instances'].append({
        'instance_id': instance['instance_id'],
        'instance_name': instance['instance_name'],
        'matrix_user': instance['matrix_user'],
        'role': instance['role'],
        'capabilities': instance['capabilities'],
        'status': instance['status'],
        'last_seen': instance['created'],
        'host': instance['deployment']['host'],
        'config_file': f"config/instances/{instance['instance_id']}.json"
    })

# Update roles index
if instance['role'] not in registry['roles']:
    registry['roles'][instance['role']] = []
if instance['instance_id'] not in registry['roles'][instance['role']]:
    registry['roles'][instance['role']].append(instance['instance_id'])

# Update capabilities index
for cap in instance['capabilities']:
    if cap not in registry['capabilities_index']:
        registry['capabilities_index'][cap] = []
    if instance['instance_id'] not in registry['capabilities_index'][cap]:
        registry['capabilities_index'][cap].append(instance['instance_id'])

# Update statistics
registry['statistics']['total_instances'] = len(registry['instances'])
registry['statistics']['active_instances'] = len([i for i in registry['instances'] if i['status'] == 'active' or i['status'] == 'configured'])
registry['statistics']['inactive_instances'] = len([i for i in registry['instances'] if i['status'] not in ['active', 'configured']])
registry['statistics']['total_roles'] = len(registry['roles'])
registry['statistics']['total_capabilities'] = len(registry['capabilities_index'])

# Update timestamp
registry['last_updated'] = datetime.utcnow().strftime('%Y-%m-%dT%H:%M:%SZ')

# Save registry
with open(registry_file, 'w') as f:
    json.dump(registry, f, indent=2)

print("Registry updated successfully")
PYTHON_SCRIPT

echo -e "${GREEN}✓ Updated instance registry${NC}"

# Print summary
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Instance Created Successfully!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Instance ID:${NC}      $INSTANCE_ID"
echo -e "${BLUE}Instance Name:${NC}    $INSTANCE_NAME"
echo -e "${BLUE}Model:${NC}            $MODEL_ID"
echo -e "${BLUE}Role:${NC}             $ROLE"
echo -e "${BLUE}Autonomy:${NC}         $AUTONOMY_LEVEL"
echo -e "${BLUE}Matrix User:${NC}      $MATRIX_USER"
echo -e "${BLUE}Host:${NC}             $HOST"
echo -e "${BLUE}Config File:${NC}      $CONFIG_FILE"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Matrix user creation reminder
if [[ "$CREATE_MATRIX_USER" == true ]]; then
    echo -e "${YELLOW}Note: Matrix user creation requested but not yet implemented.${NC}"
    echo -e "${YELLOW}Please create Matrix user manually:${NC}"
    echo -e "${YELLOW}  1. Register user: $MATRIX_USER${NC}"
    echo -e "${YELLOW}  2. Get access token${NC}"
    echo -e "${YELLOW}  3. Create credentials file: config/${INSTANCE_ID}-matrix-credentials.json${NC}"
    echo ""
fi

# Deployment instructions
if [[ "$DEPLOY" == true ]]; then
    echo -e "${YELLOW}Note: Deployment requested but not yet implemented.${NC}"
    echo -e "${YELLOW}To deploy manually:${NC}"
    echo -e "${YELLOW}  1. Copy config to host: scp $CONFIG_FILE $HOST:~/aria-workspace/aria-autonomous-infrastructure/config/instances/${NC}"
    echo -e "${YELLOW}  2. Set up Matrix credentials on host${NC}"
    echo -e "${YELLOW}  3. Start instance${NC}"
    echo ""
fi

# Next steps
echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Review configuration: cat $CONFIG_FILE"
echo -e "  2. Commit to git: cd $PROJECT_ROOT && git add $CONFIG_FILE $REGISTRY_FILE && git commit"
if [[ "$CREATE_MATRIX_USER" != true ]]; then
    echo -e "  3. Create Matrix user and credentials manually"
fi
echo -e "  4. Test instance connectivity"
echo -e "  5. Activate instance: Update status to 'active' in config"
echo ""

echo -e "${GREEN}Done!${NC}"
