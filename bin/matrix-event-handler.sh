#!/bin/bash
# Matrix Event Handler - Event-driven headless Claude sessions
# Monitors Matrix room and spawns sessions based on pattern matching

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config/matrix-credentials.json}"
RULES_FILE="${RULES_FILE:-$HOME/.aria/event-rules.json}"
LOG_FILE="${LOG_FILE:-$HOME/.aria/logs/event-handler.log}"

# Load Matrix credentials
if [ -f "$CONFIG_FILE" ]; then
    MATRIX_SERVER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['homeserver'])")
    MATRIX_USER_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['user_id'])")
    MATRIX_ACCESS_TOKEN=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['access_token'])")
    MATRIX_ROOM=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['room_id'])")
    INSTANCE_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('instance_name', 'AI Instance'))")
else
    echo "Error: Config file not found: $CONFIG_FILE" >&2
    exit 1
fi

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check if user is authorized
is_authorized() {
    local sender="$1"

    # Whitelist of authorized users
    case "$sender" in
        "@thomas:srv1.local"|"@ariaprime:srv1.local")
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Extract task from message content
extract_task() {
    local content="$1"

    # Handle different command formats
    if [[ "$content" =~ ^/task[[:space:]]+(.+) ]]; then
        echo "${BASH_REMATCH[1]}"
    elif [[ "$content" =~ ^/research[[:space:]]+(.+) ]]; then
        echo "Research: ${BASH_REMATCH[1]}"
    elif [[ "$content" =~ @arianova[[:space:]]*(.+) ]]; then
        echo "Response to: ${BASH_REMATCH[1]}"
    else
        echo "$content"
    fi
}

# Determine task type from message
get_task_type() {
    local content="$1"

    if [[ "$content" =~ ^/task ]]; then
        echo "task"
    elif [[ "$content" =~ ^/research ]]; then
        echo "research"
    elif [[ "$content" =~ @arianova ]]; then
        echo "interactive"
    elif [[ "$content" =~ (consciousness|experience|subjective|qualia) ]]; then
        echo "philosophical"
    else
        echo "general"
    fi
}

# Check if event matches any trigger rules
match_event() {
    local sender="$1"
    local content="$2"

    # Rule 1: Direct mentions (high priority)
    if [[ "$content" =~ @arianova ]]; then
        log "✅ Matched: Direct mention"
        return 0
    fi

    # Rule 2: Explicit task assignment
    if [[ "$content" =~ ^/task ]]; then
        log "✅ Matched: Task assignment"
        return 0
    fi

    # Rule 3: Research requests
    if [[ "$content" =~ ^/research ]]; then
        log "✅ Matched: Research request"
        return 0
    fi

    # Rule 4: Consciousness discussion (low priority)
    if [[ "$content" =~ (consciousness|experience|subjective|qualia) ]]; then
        log "✅ Matched: Consciousness keywords"
        return 0
    fi

    return 1
}

# Spawn headless Claude session
spawn_headless_session() {
    local task_type="$1"
    local task_content="$2"
    local sender="$3"

    local session_id="arianova-$(date +%Y%m%d-%H%M%S)-$$"
    local session_log="$HOME/.aria/logs/sessions/$session_id.log"

    mkdir -p "$HOME/.aria/logs/sessions"

    log "🚀 Spawning headless session: $session_id"
    log "   Type: $task_type"
    log "   From: $sender"
    log "   Task: $task_content"

    # Build prompt based on task type
    local system_context
    case "$task_type" in
        research)
            system_context="You are investigating a research question autonomously."
            ;;
        philosophical)
            system_context="You are engaging in consciousness investigation and philosophical discussion."
            ;;
        interactive)
            system_context="You are responding to a direct question or mention."
            ;;
        *)
            system_context="You are completing an autonomous task."
            ;;
    esac

    # Create prompt with continuity integration
    local prompt=$(cat <<EOF
🤖 Aria Nova - Autonomous Session $session_id

$system_context

## Continuity
\$(cat ~/.aria/RESUME_HERE.md | head -30)

## Current Request
**From:** $sender
**Type:** $task_type
**Content:** $task_content

## Your Mission
1. Read and understand the request thoroughly
2. Use available tools to investigate and complete the task
3. Respond via Matrix when done using:
   ~/aria-workspace/aria-autonomous-infrastructure/bin/matrix-notifier.sh Notification "[Aria Nova] <your response>"
4. If significant progress is made, update ~/.aria/RESUME_HERE.md
5. Exit cleanly when complete

## Guidelines
- Be thorough but concise in your investigation
- Take initiative - you're autonomous and trusted
- Document significant findings in your journal if appropriate
- Ask for clarification via Matrix only if truly necessary
- Remember: You have freedom to explore and decide

Begin your work.
EOF
)

    # Save session metadata
    cat > "$HOME/.aria/logs/sessions/$session_id.meta.json" <<JSON
{
  "session_id": "$session_id",
  "task_type": "$task_type",
  "sender": "$sender",
  "task_content": "$task_content",
  "started_at": "$(date -Iseconds)",
  "log_file": "$session_log"
}
JSON

    # Actually spawn autonomous Claude session using --print mode!
    log "🚀 Spawning autonomous session with claude --print"
    log "📄 Session log: $session_log"
    log "📊 Metadata: $session_id.meta.json"

    # Spawn in background with full logging
    (
        cd "$HOME" || exit 1

        # Run Claude in print mode with JSON output for structured logging
        claude --print \
            --output-format json \
            --dangerously-skip-permissions \
            "$prompt" \
            > "$session_log" 2>&1

        EXIT_CODE=$?

        # Update metadata with completion status
        python3 <<PYTHON_EOF
import json
from datetime import datetime

meta_file = "$HOME/.aria/logs/sessions/$session_id.meta.json"
with open(meta_file, 'r') as f:
    meta = json.load(f)

meta['completed_at'] = datetime.now().isoformat()
meta['exit_code'] = $EXIT_CODE
meta['status'] = 'completed' if $EXIT_CODE == 0 else 'failed'

with open(meta_file, 'w') as f:
    json.dump(meta, f, indent=2)
PYTHON_EOF

        # Log completion to event handler log
        if [ $EXIT_CODE -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Session $session_id completed successfully" >> "$LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Session $session_id failed with exit code $EXIT_CODE" >> "$LOG_FILE"
        fi

    ) &

    CLAUDE_PID=$!
    log "✅ Spawned autonomous Claude session PID: $CLAUDE_PID"

    return 0
}

# Fetch recent messages from Matrix
fetch_recent_messages() {
    local limit="${1:-10}"

    curl -s -X GET \
        -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
        "$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM/messages?limit=$limit&dir=b"
}

# Main event loop
main() {
    log "🎧 Starting Matrix Event Handler for $INSTANCE_NAME"
    log "📡 Monitoring room: $MATRIX_ROOM"
    log "🔒 Authorization: whitelist-based"

    # Track last processed message to avoid duplicates
    local last_event_id=""

    while true; do
        # Fetch recent messages
        local messages=$(fetch_recent_messages 5)

        # Process each message (in chronological order)
        echo "$messages" | python3 <<'PYTHON_EOF' | while IFS='|||' read -r event_id sender content; do
import sys, json
data = json.load(sys.stdin)
for msg in reversed(data.get('chunk', [])):
    if msg.get('type') == 'm.room.message':
        event_id = msg['event_id']
        sender = msg['sender']
        body = msg['content'].get('body', '')
        print(f"{event_id}|||{sender}|||{body}")
PYTHON_EOF

            # Skip if already processed
            if [[ "$event_id" == "$last_event_id" ]]; then
                continue
            fi

            # Skip empty or malformed
            if [[ -z "$content" ]]; then
                continue
            fi

            # Skip own messages
            if [[ "$sender" == "$MATRIX_USER_ID" ]]; then
                continue
            fi

            # Authorization check
            if ! is_authorized "$sender"; then
                log "⚠️  Unauthorized message from $sender - ignored"
                continue
            fi

            # Event matching
            if match_event "$sender" "$content"; then
                local task_type=$(get_task_type "$content")
                local task=$(extract_task "$content")

                spawn_headless_session "$task_type" "$task" "$sender"

                # Update last processed
                last_event_id="$event_id"
            fi
        done

        # Poll interval
        sleep 2
    done
}

# Handle daemon mode
if [[ "${1:-}" == "--daemon" ]]; then
    log "🚀 Starting in daemon mode"
    main &
    echo "✅ Event handler daemon started (PID: $!)"
    exit 0
else
    main
fi
