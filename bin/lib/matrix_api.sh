#!/bin/bash
# ============================================================================
# Matrix API Library for Aria Autonomous Infrastructure
# ============================================================================
#
# Matrix Client-Server API interactions
#
# Usage:
#   source "$(dirname $0)/lib/matrix_api.sh"
#   send_matrix_message "Hello from Aria!"
#   messages=$(fetch_matrix_messages 10)
#
# Features:
# - Send messages with error handling
# - Fetch messages with pagination
# - Connection health checks
# - Event ID extraction
# - Proper HTTP error handling
# ============================================================================

# Prevent multiple loading
[[ -n "$ARIA_MATRIX_API_LOADED" ]] && return 0
readonly ARIA_MATRIX_API_LOADED=1

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

# Send text message to Matrix room
# Args: message_body
# Returns: 0 on success, event_id to stdout; 1 on error
send_matrix_message() {
    local message_body="$1"

    if [[ -z "$message_body" ]]; then
        log_error "Message body required"
        return 1
    fi

    # Validate config loaded
    if ! is_matrix_config_loaded; then
        log_error "Matrix configuration not loaded. Call load_matrix_config first."
        return 1
    fi

    log_debug "Sending message to Matrix room: $MATRIX_ROOM"

    # Build JSON payload using json_utils
    local payload
    payload=$(build_json msgtype "m.text" body "$message_body") || {
        log_error "Failed to build JSON payload"
        return 1
    }

    # Send via Matrix API
    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM/send/m.room.message" 2>&1)

    local curl_exit=$?

    if [[ $curl_exit -ne 0 ]]; then
        log_error "curl failed with exit code $curl_exit"
        return 1
    fi

    # Extract event_id from response
    local event_id
    event_id=$(echo "$response" | parse_json_string "$response" "event_id")

    if [[ -n "$event_id" ]]; then
        log_debug "Message sent successfully: $event_id"
        echo "$event_id"
        return 0
    else
        # Check for error in response
        local error_code
        error_code=$(echo "$response" | parse_json_string "$response" "errcode")

        if [[ -n "$error_code" ]]; then
            local error_msg
            error_msg=$(echo "$response" | parse_json_string "$response" "error")
            log_error "Matrix API error: $error_code - $error_msg"
        else
            log_error "Failed to send message: $response"
        fi
        return 1
    fi
}

# Fetch recent messages from Matrix room
# Args: limit (optional, default 10)
# Returns: JSON response to stdout, 0 on success
fetch_matrix_messages() {
    local limit="${1:-10}"

    if ! is_matrix_config_loaded; then
        log_error "Matrix configuration not loaded"
        return 1
    fi

    log_debug "Fetching $limit messages from Matrix room"

    local response
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
        "$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM/messages?limit=$limit&dir=b" 2>&1)

    local curl_exit=$?

    if [[ $curl_exit -ne 0 ]]; then
        log_error "curl failed with exit code $curl_exit"
        return 1
    fi

    # Check for error in response
    local error_code
    error_code=$(echo "$response" | parse_json_string "$response" "errcode")

    if [[ -n "$error_code" ]]; then
        local error_msg
        error_msg=$(echo "$response" | parse_json_string "$response" "error")
        log_error "Matrix API error: $error_code - $error_msg"
        return 1
    fi

    echo "$response"
    return 0
}

# Check if Matrix server is reachable
# Returns: 0 if reachable, 1 otherwise
check_matrix_connection() {
    if ! is_matrix_config_loaded; then
        log_error "Matrix configuration not loaded"
        return 1
    fi

    log_debug "Checking Matrix server connection: $MATRIX_SERVER"

    local http_code
    http_code=$(curl -s -o /dev/null -w "%{http_code}" "$MATRIX_SERVER/_matrix/client/versions" 2>/dev/null)

    if [[ "$http_code" == "200" ]]; then
        log_debug "Matrix server reachable (HTTP $http_code)"
        return 0
    else
        log_error "Matrix server unreachable (HTTP $http_code)"
        return 1
    fi
}

# Validate Matrix access token
# Returns: 0 if valid, 1 if invalid
validate_matrix_token() {
    if ! is_matrix_config_loaded; then
        log_error "Matrix configuration not loaded"
        return 1
    fi

    log_debug "Validating Matrix access token"

    local response
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
        "$MATRIX_SERVER/_matrix/client/r0/account/whoami" 2>/dev/null)

    local user_id
    user_id=$(echo "$response" | parse_json_string "$response" "user_id")

    if [[ "$user_id" == "$MATRIX_USER_ID" ]]; then
        log_debug "Access token valid for $user_id"
        return 0
    else
        log_error "Access token invalid or expired"
        return 1
    fi
}

# Join a Matrix room by alias or ID
# Args: room_id_or_alias
# Returns: 0 on success, 1 on error
join_matrix_room() {
    local room="$1"

    if [[ -z "$room" ]]; then
        log_error "Room ID or alias required"
        return 1
    fi

    if ! is_matrix_config_loaded; then
        log_error "Matrix configuration not loaded"
        return 1
    fi

    log_info "Joining Matrix room: $room"

    # URL encode room if it contains #
    local encoded_room
    encoded_room="${room//#/%23}"

    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d '{}' \
        "$MATRIX_SERVER/_matrix/client/r0/join/$encoded_room" 2>&1)

    local room_id
    room_id=$(echo "$response" | parse_json_string "$response" "room_id")

    if [[ -n "$room_id" ]]; then
        log_success "Joined room: $room_id"
        return 0
    else
        local error_code
        error_code=$(echo "$response" | parse_json_string "$response" "errcode")
        if [[ -n "$error_code" ]]; then
            local error_msg
            error_msg=$(echo "$response" | parse_json_string "$response" "error")
            log_error "Failed to join room: $error_code - $error_msg"
        else
            log_error "Failed to join room: $response"
        fi
        return 1
    fi
}
