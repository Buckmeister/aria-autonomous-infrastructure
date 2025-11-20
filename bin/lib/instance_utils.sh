#!/bin/bash
# ============================================================================
# Instance Utilities Library for Aria Autonomous Infrastructure
# ============================================================================
#
# Instance-specific helper functions
#
# Usage:
#   source "$(dirname $0)/lib/instance_utils.sh"
#   message=$(format_event_message "SessionStart")
#   send_matrix_message "$message"
#
# Features:
# - Consistent message formatting
# - Event type handling
# - Emoji support
# - Instance name integration
# ============================================================================

# Prevent multiple loading
[[ -n "$ARIA_INSTANCE_UTILS_LOADED" ]] && return 0
readonly ARIA_INSTANCE_UTILS_LOADED=1

# Get library directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load dependencies
if [[ -z "$ARIA_MATRIX_CORE_LOADED" ]]; then
    source "$LIB_DIR/matrix_core.sh" || {
        echo "ERROR: Failed to load matrix_core.sh" >&2
        return 1
    }
fi

# ============================================================================
# Public API
# ============================================================================

# Format event notification message
# Args: event_type, message (optional)
# Returns: Formatted message string to stdout
format_event_message() {
    local event_type="$1"
    local message_text="${2:-}"
    local instance_name
    instance_name=$(get_instance_name)

    local emoji msg
    case "$event_type" in
        SessionStart)
            emoji="🚀"
            msg="[$instance_name] Session started"
            ;;
        SessionEnd)
            emoji="👋"
            msg="[$instance_name] Session ended"
            ;;
        Stop)
            emoji="✅"
            msg="[$instance_name] Task completed"
            [[ -n "$message_text" ]] && msg="$msg: $message_text"
            ;;
        SubagentStop)
            emoji="🤖"
            msg="[$instance_name] Agent task completed"
            [[ -n "$message_text" ]] && msg="$msg: $message_text"
            ;;
        Notification)
            emoji="📢"
            msg="[$instance_name] $message_text"
            ;;
        Error)
            emoji="❌"
            msg="[$instance_name] Error: $message_text"
            ;;
        Info)
            emoji="ℹ️"
            msg="[$instance_name] $message_text"
            ;;
        Success)
            emoji="✅"
            msg="[$instance_name] $message_text"
            ;;
        Warning)
            emoji="⚠️"
            msg="[$instance_name] Warning: $message_text"
            ;;
        Research)
            emoji="🔬"
            msg="[$instance_name] Research: $message_text"
            ;;
        Interview)
            emoji="💭"
            msg="[$instance_name] Interview: $message_text"
            ;;
        Debug)
            emoji="🐛"
            msg="[$instance_name] Debug: $message_text"
            ;;
        *)
            emoji="ℹ️"
            msg="[$instance_name] $event_type: $message_text"
            ;;
    esac

    echo "$emoji $msg"
}

# Send formatted event message to Matrix
# Args: event_type, message (optional)
# Returns: 0 on success, 1 on error
send_event_notification() {
    local event_type="$1"
    local message_text="${2:-}"

    local formatted_message
    formatted_message=$(format_event_message "$event_type" "$message_text")

    send_matrix_message "$formatted_message"
}

# Get current instance name from config
# Returns: Instance name string
get_current_instance_name() {
    get_instance_name
}

# Check if running on specific instance
# Args: instance_name
# Returns: 0 if matches, 1 otherwise
is_instance() {
    local target_instance="$1"
    local current_instance
    current_instance=$(get_instance_name)

    if [[ "$current_instance" == "$target_instance" ]]; then
        return 0
    fi

    return 1
}

# Get instance identifier (lowercase, no spaces)
# Returns: Instance identifier string
get_instance_id() {
    local name
    name=$(get_instance_name)

    # Convert to lowercase and replace spaces with hyphens
    echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-'
}

# Format timestamp for messages
# Returns: ISO 8601 formatted timestamp
format_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Create session ID for autonomous sessions
# Returns: Unique session ID
generate_session_id() {
    local instance_id
    instance_id=$(get_instance_id)
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)

    echo "${instance_id}-${timestamp}-$$"
}
