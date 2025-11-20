#!/bin/bash
# Matrix Notifier for Claude Code Hooks
# Sends notifications to Matrix when Claude Code events occur
#
# Usage: matrix-notifier.sh <event-type> [message]
#
# Configuration:
#   Set environment variables or use config/matrix-credentials.json
#
# Integration with Claude Code hooks in ~/.claude/settings.json:
# {
#   "hooks": {
#     "Stop": { "command": "~/path/to/matrix-notifier.sh Stop" },
#     "SessionStart": { "command": "~/path/to/matrix-notifier.sh SessionStart" }
#   }
# }

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

source "$LIB_DIR/instance_utils.sh" || {
    log_error "Failed to load instance_utils.sh library"
    exit 1
}

# ============================================================================
# Main Script
# ============================================================================

# Parse command line
EVENT_TYPE="${1:-Unknown}"
MESSAGE_TEXT="${2:-}"

# Determine config file location
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config/matrix-credentials.json}"

# Load Matrix configuration
if ! load_matrix_config "$CONFIG_FILE"; then
    log_error "Failed to load Matrix configuration from: $CONFIG_FILE"
    log_error "Please ensure config/matrix-credentials.json exists and is valid"
    exit 1
fi

# Format message based on event type
MESSAGE=$(format_event_message "$EVENT_TYPE" "$MESSAGE_TEXT")

# Send to Matrix
log_debug "Sending notification: $MESSAGE"

if send_matrix_message "$MESSAGE" >/dev/null 2>&1; then
    log_debug "Notification sent successfully"
    exit 0
else
    log_error "Failed to send notification"
    exit 1
fi
