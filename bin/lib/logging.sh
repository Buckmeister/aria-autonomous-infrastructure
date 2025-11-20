#!/bin/bash
# ============================================================================
# Logging Library for Aria Autonomous Infrastructure
# ============================================================================
#
# Provides centralized logging with levels, timestamps, and file handling
#
# Usage:
#   source "$(dirname $0)/lib/logging.sh"
#   init_logging [log_file_path]
#   log_info "Starting process"
#   log_error "Something went wrong"
#
# Features:
# - Log levels: INFO, WARN, ERROR, DEBUG
# - Timestamps on all messages
# - Optional file logging
# - Debug mode support (DEBUG=1)
# - Consistent formatting across all scripts
# ============================================================================

# Prevent multiple loading
[[ -n "$ARIA_LOGGING_LOADED" ]] && return 0
readonly ARIA_LOGGING_LOADED=1

# Default log file (can be overridden)
LOG_FILE="${LOG_FILE:-}"

# ============================================================================
# Public API
# ============================================================================

# Initialize logging system
# Args: log_file_path (optional)
# Returns: 0 on success
init_logging() {
    local log_file="${1:-}"

    if [[ -n "$log_file" ]]; then
        LOG_FILE="$log_file"

        # Create log directory if needed
        local log_dir
        log_dir="$(dirname "$LOG_FILE")"
        mkdir -p "$log_dir" 2>/dev/null || {
            echo "Warning: Failed to create log directory: $log_dir" >&2
            LOG_FILE=""
            return 1
        }

        # Touch log file to ensure it's writable
        touch "$LOG_FILE" 2>/dev/null || {
            echo "Warning: Cannot write to log file: $LOG_FILE" >&2
            LOG_FILE=""
            return 1
        }
    fi

    return 0
}

# Log info message
# Args: message
# Returns: 0
log_info() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local message="[$timestamp] [INFO] $*"

    echo "$message"

    if [[ -n "$LOG_FILE" ]]; then
        echo "$message" >> "$LOG_FILE" 2>/dev/null
    fi

    return 0
}

# Log warning message
# Args: message
# Returns: 0
log_warn() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local message="[$timestamp] [WARN] $*"

    echo "$message" >&2

    if [[ -n "$LOG_FILE" ]]; then
        echo "$message" >> "$LOG_FILE" 2>/dev/null
    fi

    return 0
}

# Log error message
# Args: message
# Returns: 0
log_error() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local message="[$timestamp] [ERROR] $*"

    echo "$message" >&2

    if [[ -n "$LOG_FILE" ]]; then
        echo "$message" >> "$LOG_FILE" 2>/dev/null
    fi

    return 0
}

# Log debug message (only if DEBUG=1)
# Args: message
# Returns: 0
log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        local timestamp
        timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
        local message="[$timestamp] [DEBUG] $*"

        echo "$message" >&2

        if [[ -n "$LOG_FILE" ]]; then
            echo "$message" >> "$LOG_FILE" 2>/dev/null
        fi
    fi

    return 0
}

# Log success message with emoji
# Args: message
# Returns: 0
log_success() {
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    local message="[$timestamp] [✓] $*"

    echo "$message"

    if [[ -n "$LOG_FILE" ]]; then
        echo "$message" >> "$LOG_FILE" 2>/dev/null
    fi

    return 0
}

# ============================================================================
# Backward Compatibility
# ============================================================================

# Legacy log() function for scripts that use it
# Maps to log_info for consistency
log() {
    log_info "$@"
}
