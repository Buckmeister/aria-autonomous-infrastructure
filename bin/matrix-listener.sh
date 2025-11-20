#!/bin/bash
# Matrix Command Listener for Autonomous AI Instances
# Listens for Matrix messages and injects commands into tmux session
#
# Usage: matrix-listener.sh [--daemon]
#
# Configuration via config/matrix-credentials.json

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
LOG_FILE="${LOG_FILE:-$SCRIPT_DIR/../logs/matrix-listener.log}"
TMUX_SESSION="${TMUX_SESSION:-claude-autonomous}"

# Initialize logging
mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null
init_logging "$LOG_FILE"

# ============================================================================
# Helper Functions
# ============================================================================

# Check if tmux session exists
# Returns: 0 if exists, 1 otherwise
check_tmux() {
    if ! tmux has-session -t "$TMUX_SESSION" 2>/dev/null; then
        log_warn "tmux session '$TMUX_SESSION' not found"
        return 1
    fi
    return 0
}

# Process incoming message
# Args: sender, message
process_message() {
    local sender="$1"
    local message="$2"

    log_info "Message from $sender: $message"

    # Safety check: only accept from authorized users
    if ! is_authorized_sender "$sender"; then
        log_warn "Ignoring message from non-authorized sender: $sender"
        return 1
    fi

    local instance_name
    instance_name=$(get_instance_name)

    # Check for special commands
    if [[ "$message" =~ ^/status ]]; then
        if check_tmux; then
            send_event_notification "Success" "Autonomous session is running"
        else
            send_event_notification "Error" "Autonomous session not found"
        fi

    elif [[ "$message" =~ ^/inject[[:space:]]+(.+) ]]; then
        local cmd="${BASH_REMATCH[1]}"

        if check_tmux; then
            log_info "Injecting command: $cmd"
            tmux send-keys -t "$TMUX_SESSION" "$cmd" C-m
            send_event_notification "Success" "Command injected: $cmd"
        else
            send_event_notification "Error" "Cannot inject: session not found"
        fi

    elif [[ "$message" =~ @.*$instance_name ]]; then
        log_info "Acknowledged mention from $sender"
        send_event_notification "Info" "I see you!"
    fi

    return 0
}

# ============================================================================
# Main Listener Loop
# ============================================================================

listen_loop() {
    log_info "Starting Matrix listener for $(get_instance_name)"
    log_info "Authorized users: $(list_authorized_users)"
    log_info "Tmux session: $TMUX_SESSION"
    log_info "Log file: $LOG_FILE"

    # Activate Python virtual environment if it exists
    if [ -d "$HOME/.venv" ]; then
        source "$HOME/.venv/bin/activate"
        log_debug "Activated Python venv at $HOME/.venv"
    fi

    # Check matrix-commander availability
    if ! command -v matrix-commander >/dev/null 2>&1; then
        log_error "matrix-commander not found in PATH"
        log_error "Please install matrix-commander or activate the correct venv"
        exit 1
    fi

    # Get matrix-commander store path
    local matrix_store
    matrix_store=$(parse_json_field "$CONFIG_FILE" "store_path")
    matrix_store="${matrix_store:-$HOME/.local/share/matrix-commander}"

    log_debug "Using matrix-commander store: $matrix_store"

    while true; do
        # Listen for one message
        local output
        output=$(matrix-commander --store "$matrix_store" --listen once 2>&1 || true)

        # Parse message (simplified - real implementation would use JSON parsing)
        if [[ "$output" =~ \"sender\":\"([^\"]+)\" ]] && [[ "$output" =~ \"body\":\"([^\"]+)\" ]]; then
            local sender="${BASH_REMATCH[1]}"
            local msg_body="${BASH_REMATCH[2]}"

            process_message "$sender" "$msg_body"
        fi

        sleep 2
    done
}

# ============================================================================
# Main
# ============================================================================

# Load Matrix configuration
if ! load_matrix_config "$CONFIG_FILE"; then
    log_error "Failed to load Matrix configuration"
    exit 1
fi

# Daemon mode
if [ "$1" = "--daemon" ]; then
    log_info "Starting listener in daemon mode"

    # Create PID file directory
    mkdir -p "$SCRIPT_DIR/../logs" 2>/dev/null

    # Start in background
    nohup "$0" >> "$LOG_FILE" 2>&1 &
    PID=$!

    echo "$PID" > "$SCRIPT_DIR/../logs/listener.pid"
    echo "✅ Matrix listener daemon started"
    echo "   PID: $PID"
    echo "   Log: $LOG_FILE"
    echo "   Instance: $(get_instance_name)"

    exit 0
fi

# Interactive mode
listen_loop
