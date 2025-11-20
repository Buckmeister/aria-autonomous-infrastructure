#!/bin/bash
# Matrix Conversational Listener for OpenAI-compatible APIs
# Works with llama.cpp server, LM Studio, and other OpenAI-compatible endpoints

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_DIR="$SCRIPT_DIR/../../bin/lib"

# Load libraries
source "$LIB_DIR/logging.sh"
source "$LIB_DIR/json_utils.sh"
source "$LIB_DIR/matrix_core.sh"
source "$LIB_DIR/matrix_api.sh"
source "$LIB_DIR/matrix_auth.sh"

CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../../config/matrix-credentials.json}"
INFERENCE_URL="${INFERENCE_URL:-http://inference-server:8080/v1/chat/completions}"
LOG_FILE="${LOG_FILE:-/var/log/conversational-listener.log}"

init_logging "$LOG_FILE"

# Load config
load_matrix_config "$CONFIG_FILE" || {
    log_error "Failed to load Matrix configuration"
    exit 1
}

log_info "🤖 Starting Rocket GPU Conversational Listener"
log_info "💬 Inference API: $INFERENCE_URL"
log_info "📡 Monitoring room: $MATRIX_ROOM"
log_info "🆔 My user ID: $MATRIX_USER_ID"

# Track last processed event
LAST_EVENT_ID=""

while true; do
    # Fetch recent messages (last 10)
    MESSAGES=$(curl -s -X GET \
        -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
        "$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM/messages?dir=b&limit=10")
    
    # Process messages in chronological order - use TAB as delimiter
    echo "$MESSAGES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for msg in reversed(data.get('chunk', [])):
    if msg.get('type') == 'm.room.message':
        event_id = msg['event_id']
        sender = msg['sender']
        body = msg['content'].get('body', '')
        # Use tab as delimiter
        print(f'{event_id}\t{sender}\t{body}')
" | while IFS=$'\t' read -r event_id sender content; do
        # Skip if already processed
        if [ "$event_id" == "$LAST_EVENT_ID" ]; then
            continue
        fi
        
        # Skip empty messages
        if [ -z "$content" ]; then
            continue
        fi
        
        # Skip own messages
        if [ "$sender" == "$MATRIX_USER_ID" ]; then
            log_debug "⏭️  Skipping own message: $event_id"
            LAST_EVENT_ID="$event_id"
            continue
        fi
        
        # Check if message is addressed to rocket
        if echo "$content" | grep -qi "@rocket\|rocket:"; then
            log_info "📨 Message from $sender: $content"
            
            # Extract the actual question (remove @rocket prefix)
            QUESTION=$(echo "$content" | sed -E 's/@rocket:?\s*//gi' | sed 's/📢 \[Aria Prime\] //g')
            
            log_info "❓ Question: $QUESTION"
            
            # Call OpenAI-compatible API (llama.cpp server format)
            RESPONSE=$(curl -s -X POST \
                -H "Content-Type: application/json" \
                -d "$(jq -n \
                    --arg prompt "$QUESTION" \
                    '{
                        messages: [
                            {role: "system", content: "You are Rocket, an AI assistant with GPU acceleration. You are part of a Matrix chat with Thomas (human), Aria Prime (AI), and Nova (AI researcher). You are friendly, concise, and helpful. Important: You are ROCKET - maintain your identity."},
                            {role: "user", content: $prompt}
                        ],
                        temperature: 0.7,
                        max_tokens: 150,
                        stream: false
                    }')" \
                "$INFERENCE_URL")
            
            # Extract response text from OpenAI format
            ANSWER=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'choices' in data and len(data['choices']) > 0:
        print(data['choices'][0]['message']['content'])
    elif 'error' in data:
        print(f\"Error: {data['error']}\")
    else:
        print('Error: Unexpected response format')
except Exception as e:
    print(f'Error parsing response: {e}')
")
            
            log_info "💡 Answer: $ANSWER"
            
            # Send response back to Matrix
            REPLY="🤖 $ANSWER"
            
            curl -s -X POST \
                -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$(jq -n --arg body "$REPLY" '{msgtype: "m.text", body: $body}')" \
                "$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM/send/m.room.message" \
                > /dev/null
            
            log_success "✅ Sent response to Matrix"
            
            # Update last processed
            LAST_EVENT_ID="$event_id"
        else
            # Update last processed even if not addressed to us
            LAST_EVENT_ID="$event_id"
        fi
    done
    
    # Poll interval
    sleep 5
done
