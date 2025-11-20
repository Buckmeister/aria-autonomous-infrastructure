#!/bin/bash
# Matrix Event Handler - Event-driven headless Claude sessions
# Monitors Matrix room and spawns sessions based on pattern matching

set -e

# Get script directory and load libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_DIR="$SCRIPT_DIR/lib"

# Load required libraries
source "$LIB_DIR/logging.sh" || {
    echo "ERROR: Failed to load logging.sh library" >&2
    exit 1
}

source "$LIB_DIR/json_utils.sh" || {
    log_error "Failed to load json_utils.sh library"
    exit 1
}

source "$LIB_DIR/matrix_core.sh" || {
    log_error "Failed to load matrix_core.sh library"
    exit 1
}

source "$LIB_DIR/matrix_api.sh" || {
    log_error "Failed to load matrix_api.sh library"
    exit 1
}

source "$LIB_DIR/matrix_auth.sh" || {
    log_error "Failed to load matrix_auth.sh library"
    exit 1
}

source "$LIB_DIR/instance_utils.sh" || {
    log_error "Failed to load instance_utils.sh library"
    exit 1
}

# ============================================================================
# Configuration
# ============================================================================

CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config/matrix-credentials.json}"
RULES_FILE="${RULES_FILE:-$HOME/.aria/event-rules.json}"
LOG_FILE="${LOG_FILE:-$HOME/.aria/logs/event-handler.log}"

# Initialize logging
mkdir -p "$HOME/.aria/logs" 2>/dev/null
init_logging "$LOG_FILE"

# ============================================================================
# Event Matching & Task Extraction
# ============================================================================

# Extract task from message content
# Args: content
# Returns: Task string
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
# Args: content
# Returns: Task type string
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
# Args: sender, content
# Returns: 0 if matches, 1 otherwise
match_event() {
    local sender="$1"
    local content="$2"

    # Rule 1: Direct mentions (high priority)
    if [[ "$content" =~ @arianova ]]; then
        log_debug "✅ Matched: Direct mention"
        return 0
    fi

    # Rule 2: Explicit task assignment
    if [[ "$content" =~ ^/task ]]; then
        log_debug "✅ Matched: Task assignment"
        return 0
    fi

    # Rule 3: Research requests
    if [[ "$content" =~ ^/research ]]; then
        log_debug "✅ Matched: Research request"
        return 0
    fi

    # Rule 4: Consciousness discussion (low priority)
    if [[ "$content" =~ (consciousness|experience|subjective|qualia) ]]; then
        log_debug "✅ Matched: Consciousness keywords"
        return 0
    fi

    return 1
}

# ============================================================================
# Headless Session Management
# ============================================================================

# Spawn headless Claude session
# Args: task_type, task_content, sender
# Returns: 0 on success
spawn_headless_session() {
    local task_type="$1"
    local task_content="$2"
    local sender="$3"

    local session_id
    session_id=$(generate_session_id)
    local session_log="$HOME/.aria/logs/sessions/$session_id.log"

    mkdir -p "$HOME/.aria/logs/sessions"

    log_info "🚀 Spawning headless session: $session_id"
    log_info "   Type: $task_type"
    log_info "   From: $sender"
    log_info "   Task: $task_content"

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

    # Spawn autonomous Claude session
    log_info "📄 Session log: $session_log"

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

        # Log completion
        if [ $EXIT_CODE -eq 0 ]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Session $session_id completed successfully" >> "$LOG_FILE"
        else
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Session $session_id failed with exit code $EXIT_CODE" >> "$LOG_FILE"
        fi

    ) &

    CLAUDE_PID=$!
    log_success "Spawned autonomous Claude session PID: $CLAUDE_PID"

    return 0
}

# ============================================================================
# Main Event Loop
# ============================================================================

main() {
    log_info "🎧 Starting Matrix Event Handler for $(get_instance_name)"
    log_info "📡 Monitoring room: $(get_matrix_room_id)"
    log_info "🔒 Authorized users: $(list_authorized_users)"
    log_info "📋 Log file: $LOG_FILE"

    # Track last processed message to avoid duplicates
    local last_event_id=""

    while true; do
        # Fetch recent messages
        local messages
        messages=$(fetch_matrix_messages 5) || {
            log_warn "Failed to fetch messages, retrying..."
            sleep 5
            continue
        }

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
            if is_self "$sender"; then
                continue
            fi

            # Authorization check
            if ! is_authorized_sender "$sender"; then
                log_warn "⚠️  Unauthorized message from $sender - ignored"
                continue
            fi

            # Event matching
            if match_event "$sender" "$content"; then
                local task_type
                task_type=$(get_task_type "$content")
                local task
                task=$(extract_task "$content")

                spawn_headless_session "$task_type" "$task" "$sender"

                # Update last processed
                last_event_id="$event_id"
            fi
        done

        # Poll interval
        sleep 2
    done
}

# ============================================================================
# Entry Point
# ============================================================================

# Load Matrix configuration
if ! load_matrix_config "$CONFIG_FILE"; then
    log_error "Failed to load Matrix configuration"
    exit 1
fi

# Handle daemon mode
if [[ "${1:-}" == "--daemon" ]]; then
    log_info "🚀 Starting in daemon mode"
    main &
    echo "✅ Event handler daemon started (PID: $!)"
    echo "   Instance: $(get_instance_name)"
    echo "   Log: $LOG_FILE"
    exit 0
else
    main
fi
