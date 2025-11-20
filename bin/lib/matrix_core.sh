#!/bin/bash
# ============================================================================
# Matrix Core Library for Aria Autonomous Infrastructure
# ============================================================================
#
# Core Matrix configuration loading and validation
#
# Usage:
#   source "$(dirname $0)/lib/matrix_core.sh"
#   load_matrix_config "$CONFIG_FILE"
#   validate_matrix_config
#
# Features:
# - Single source of truth for configuration
# - Validation of required fields
# - Clear error messages
# - Exports variables for other scripts
# ============================================================================

# Prevent multiple loading
[[ -n "$ARIA_MATRIX_CORE_LOADED" ]] && return 0
readonly ARIA_MATRIX_CORE_LOADED=1

# Get library directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load dependencies
if [[ -z "$ARIA_JSON_UTILS_LOADED" ]]; then
    source "$LIB_DIR/json_utils.sh" || {
        echo "ERROR: Failed to load json_utils.sh" >&2
        return 1
    }
fi

if [[ -z "$ARIA_LOGGING_LOADED" ]]; then
    source "$LIB_DIR/logging.sh" || {
        echo "ERROR: Failed to load logging.sh" >&2
        return 1
    }
fi

# ============================================================================
# Configuration Variables (exported after loading)
# ============================================================================

MATRIX_SERVER=""
MATRIX_USER_ID=""
MATRIX_ACCESS_TOKEN=""
MATRIX_ROOM=""
INSTANCE_NAME=""

# Default config file location
DEFAULT_CONFIG_FILE="$(cd "$LIB_DIR/.." && pwd)/../config/matrix-credentials.json"

# ============================================================================
# Public API
# ============================================================================

# Load Matrix configuration from credentials file
# Args: config_file_path (optional, defaults to ../config/matrix-credentials.json)
# Sets: MATRIX_SERVER, MATRIX_USER_ID, MATRIX_ACCESS_TOKEN, MATRIX_ROOM, INSTANCE_NAME
# Returns: 0 on success, 1 on error
load_matrix_config() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"

    log_debug "Loading Matrix config from: $config_file"

    if [[ ! -f "$config_file" ]]; then
        log_error "Matrix config file not found: $config_file"
        log_error "Please create config/matrix-credentials.json from the example"
        return 1
    fi

    # Validate JSON structure first
    if ! validate_json_file "$config_file"; then
        log_error "Invalid JSON in config file: $config_file"
        return 1
    fi

    # Load all fields
    MATRIX_SERVER=$(parse_json_field "$config_file" "homeserver")
    MATRIX_USER_ID=$(parse_json_field "$config_file" "user_id")
    MATRIX_ACCESS_TOKEN=$(parse_json_field "$config_file" "access_token")
    MATRIX_ROOM=$(parse_json_field "$config_file" "room_id")
    INSTANCE_NAME=$(parse_json_field "$config_file" "instance_name")

    # Set defaults for optional fields
    INSTANCE_NAME="${INSTANCE_NAME:-AI Instance}"

    # Validate required fields
    if ! validate_matrix_config; then
        return 1
    fi

    # Export for use by other scripts
    export MATRIX_SERVER MATRIX_USER_ID MATRIX_ACCESS_TOKEN MATRIX_ROOM INSTANCE_NAME

    log_debug "Matrix config loaded successfully"
    log_debug "  Server: $MATRIX_SERVER"
    log_debug "  User: $MATRIX_USER_ID"
    log_debug "  Room: $MATRIX_ROOM"
    log_debug "  Instance: $INSTANCE_NAME"

    return 0
}

# Validate that all required Matrix config fields are set
# Returns: 0 if valid, 1 if invalid
validate_matrix_config() {
    local missing=()

    [[ -z "$MATRIX_SERVER" ]] && missing+=("homeserver")
    [[ -z "$MATRIX_USER_ID" ]] && missing+=("user_id")
    [[ -z "$MATRIX_ACCESS_TOKEN" ]] && missing+=("access_token")
    [[ -z "$MATRIX_ROOM" ]] && missing+=("room_id")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required Matrix config fields: ${missing[*]}"
        log_error "Please check your config/matrix-credentials.json file"
        return 1
    fi

    return 0
}

# Get configured instance name with fallback
# Returns: Instance name string
get_instance_name() {
    echo "${INSTANCE_NAME:-AI Instance}"
}

# Get Matrix server URL
# Returns: Server URL string
get_matrix_server() {
    echo "${MATRIX_SERVER}"
}

# Get Matrix user ID
# Returns: User ID string
get_matrix_user_id() {
    echo "${MATRIX_USER_ID}"
}

# Get Matrix room ID
# Returns: Room ID string
get_matrix_room_id() {
    echo "${MATRIX_ROOM}"
}

# Check if Matrix configuration is loaded
# Returns: 0 if loaded, 1 if not
is_matrix_config_loaded() {
    if [[ -n "$MATRIX_SERVER" ]] && \
       [[ -n "$MATRIX_USER_ID" ]] && \
       [[ -n "$MATRIX_ACCESS_TOKEN" ]] && \
       [[ -n "$MATRIX_ROOM" ]]; then
        return 0
    fi
    return 1
}
