#!/bin/bash
# Matrix Conversational Listener for Anthropic Claude API
# Uses Claude API directly - no local GPU required

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
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY}"
ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-claude-sonnet-4-5-20250929}"
LOG_FILE="${LOG_FILE:-/var/log/conversational-listener.log}"

init_logging "$LOG_FILE"

# Validate Anthropic API key
if [ -z "$ANTHROPIC_API_KEY" ]; then
    log_error "ANTHROPIC_API_KEY environment variable is required"
    exit 1
fi

# Load config
load_matrix_config "$CONFIG_FILE" || {
    log_error "Failed to load Matrix configuration"
    exit 1
}

log_info "🤖 Starting Aria Proxima - Anthropic Claude Listener"
log_info "🧠 Model: $ANTHROPIC_MODEL"
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

        # Check if message is addressed to this bot (check for mention)
        BOT_NAME=$(echo "$MATRIX_USER_ID" | sed 's/@\([^:]*\):.*/\1/')
        if echo "$content" | grep -qi "@${BOT_NAME}\|${BOT_NAME}:"; then
            log_info "📨 Message from $sender: $content"

            # Extract the actual question (remove @mention prefix)
            QUESTION=$(echo "$content" | sed -E "s/@${BOT_NAME}:?\s*//gi" | sed 's/📢 \[.*\] //g')

            log_info "❓ Question: $QUESTION"

            # Call Anthropic Claude API
            RESPONSE=$(curl -s -X POST \
                https://api.anthropic.com/v1/messages \
                -H "Content-Type: application/json" \
                -H "x-api-key: $ANTHROPIC_API_KEY" \
                -H "anthropic-version: 2023-06-01" \
                -d "$(jq -n \
                    --arg model "$ANTHROPIC_MODEL" \
                    --arg prompt "$QUESTION" \
                    --arg bot_name "$BOT_NAME" \
                    '{
                        model: $model,
                        max_tokens: 1024,
                        system: "You are \($bot_name), an AI assistant powered by Claude. You are part of a Matrix chat with Thomas (human), Aria Prime (AI), and other AI assistants. You are friendly, concise, and helpful. Important: You are \($bot_name | ascii_upcase) - maintain your identity.",
                        messages: [
                            {role: "user", content: $prompt}
                        ]
                    }')")

            # Extract response text from Anthropic format
            ANSWER=$(echo "$RESPONSE" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    if 'content' in data and len(data['content']) > 0:
        print(data['content'][0]['text'])
    elif 'error' in data:
        print(f\"Error: {data['error'].get('message', 'Unknown error')}\")
    else:
        print('Error: Unexpected response format')
except Exception as e:
    print(f'Error parsing response: {e}')
")

            if [ -z "$ANSWER" ] || echo "$ANSWER" | grep -q "^Error:"; then
                log_error "❌ Failed to get response: $ANSWER"
                ANSWER="Sorry, I encountered an error processing your request."
            fi

            log_info "💬 Answer: $ANSWER"

            # Send response to Matrix
            FORMATTED_RESPONSE="$ANSWER"

            curl -s -X POST \
                -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$(jq -n --arg msg "$FORMATTED_RESPONSE" '{msgtype: "m.text", body: $msg}')" \
                "$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM/send/m.room.message" \
                > /dev/null

            log_success "✅ Response sent"
        fi

        # Update last processed event
        LAST_EVENT_ID="$event_id"
    done

    # Poll every 5 seconds
    sleep 5
done
