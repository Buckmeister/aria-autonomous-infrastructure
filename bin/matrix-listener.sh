#!/bin/bash
# Matrix Command Listener for Autonomous AI Instances
# Listens for Matrix messages and injects commands into tmux session
#
# Usage: matrix-listener.sh [--daemon]
#
# Configuration via config/matrix-credentials.json

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config/matrix-credentials.json}"
LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/../logs/matrix-listener.log}"

# Create log directory if needed
mkdir -p "$(dirname "$LOG_FILE")"

# Configuration
TMUX_SESSION="${TMUX_SESSION:-claude-autonomous}"
AUTHORIZED_USERS="${AUTHORIZED_USERS:-@thomas}"  # Comma-separated

# Load Matrix credentials from config
if [ -f "$CONFIG_FILE" ]; then
    MATRIX_STORE=$(python3 -c "import json, os; c=json.load(open('$CONFIG_FILE')); print(c.get('store_path', os.path.expanduser('~/.local/share/matrix-commander')))" 2>/dev/null || echo "$HOME/.local/share/matrix-commander")
    INSTANCE_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('instance_name', 'AI Instance'))" 2>/dev/null || echo "AI Instance")
else
    echo "ERROR: Config file not found: $CONFIG_FILE"
    echo "Please create config/matrix-credentials.json from the example"
    exit 1
fi

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Check if tmux session exists
check_tmux() {
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        log "⚠️  Warning: tmux session '$TMUX_SESSION' not found"
        return 1
    fi
    return 0
}

# Send message to Matrix
send_matrix() {
    local message="$1"
    if [ -f "$CONFIG_FILE" ]; then
        matrix-commander --store "$MATRIX_STORE" -m "$message" 2>/dev/null || true
    fi
}

# Process incoming message
process_message() {
    local sender="$1"
    local message="$2"

    log "📨 Message from $sender: $message"

    # Safety check: only accept from authorized users
    local authorized=false
    IFS=',' read -ra USERS <<< "$AUTHORIZED_USERS"
    for user in "${USERS[@]}"; do
        if [[ "$sender" =~ $user ]]; then
            authorized=true
            break
        fi
    done

    if [ "$authorized" = false ]; then
        log "⚠️  Ignoring message from non-authorized sender: $sender"
        return
    fi

    # Check for special commands
    if [[ "$message" =~ ^/status ]]; then
        if check_tmux; then
            send_matrix "✅ [$INSTANCE_NAME] Autonomous session is running"
        else
            send_matrix "❌ [$INSTANCE_NAME] Autonomous session not found"
        fi
    elif [[ "$message" =~ ^/inject\ (.+) ]]; then
        local cmd="${BASH_REMATCH[1]}"
        if check_tmux; then
            log "💉 Injecting command: $cmd"
            tmux send-keys -t "$TMUX_SESSION" "$cmd" C-m
            send_matrix "✅ [$INSTANCE_NAME] Command injected: $cmd"
        else
            send_matrix "❌ [$INSTANCE_NAME] Cannot inject: session not found"
        fi
    elif [[ "$message" =~ @.*$INSTANCE_NAME ]]; then
        log "👋 Acknowledged mention from $sender"
        send_matrix "✅ [$INSTANCE_NAME] I see you!"
    fi
}

# Main listener loop
listen_loop() {
    log "🎧 Starting Matrix listener for $INSTANCE_NAME"
    log "📍 Authorized users: $AUTHORIZED_USERS"
    log "📍 Tmux session: $TMUX_SESSION"

    # Activate Python virtual environment if it exists
    if [ -d "$HOME/.venv" ]; then
        source "$HOME/.venv/bin/activate"
    fi

    while true; do
        # Listen for one message
        OUTPUT=$(matrix-commander --store "$MATRIX_STORE" --listen once 2>&1 || true)

        # Parse message (simplified - real implementation would use JSON parsing)
        if [[ "$OUTPUT" =~ \"sender\":\"([^\"]+)\" ]] && [[ "$OUTPUT" =~ \"body\":\"([^\"]+)\" ]]; then
            SENDER="${BASH_REMATCH[1]}"
            MESSAGE="${BASH_REMATCH[2]}"
            process_message "$SENDER" "$MESSAGE"
        fi

        sleep 2
    done
}

# Daemon mode
if [ "$1" = "--daemon" ]; then
    log "🚀 Starting listener in daemon mode"
    nohup "$0" >> "$LOG_FILE" 2>&1 &
    PID=$!
    echo "$PID" > "$SCRIPT_DIR/../logs/listener.pid"
    log "✅ Daemon started with PID: $PID"
    exit 0
fi

# Interactive mode
listen_loop
