#!/bin/bash
# ============================================================================
# Matrix Authorization Library for Aria Autonomous Infrastructure
# ============================================================================
#
# Authorization and user validation for Matrix interactions
#
# Usage:
#   source "$(dirname $0)/lib/matrix_auth.sh"
#   if is_authorized_sender "@thomas:srv1.local"; then
#       echo "Authorized!"
#   fi
#
# Features:
# - Whitelist-based authorization
# - Configurable authorized users
# - Security logging
# - User validation helpers
# ============================================================================

# Prevent multiple loading
[[ -n "$ARIA_MATRIX_AUTH_LOADED" ]] && return 0
readonly ARIA_MATRIX_AUTH_LOADED=1

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
# Configuration
# ============================================================================

# Default authorized users (can be overridden by AUTHORIZED_USERS env var)
DEFAULT_AUTHORIZED_USERS="@thomas:srv1.local,@ariaprime:srv1.local,@arianova:srv1.local"

# ============================================================================
# Public API
# ============================================================================

# Check if sender is authorized
# Args: sender_user_id
# Returns: 0 if authorized, 1 otherwise
is_authorized_sender() {
    local sender="$1"

    if [[ -z "$sender" ]]; then
        log_warn "Empty sender ID provided to authorization check"
        return 1
    fi

    # Get authorized users list (from env or default)
    local authorized_users="${AUTHORIZED_USERS:-$DEFAULT_AUTHORIZED_USERS}"

    log_debug "Checking authorization for: $sender"
    log_debug "Authorized users: $authorized_users"

    # Check against whitelist
    local authorized=false
    IFS=',' read -ra USERS <<< "$authorized_users"
    for user in "${USERS[@]}"; do
        # Trim whitespace
        user=$(echo "$user" | xargs)

        if [[ "$sender" == "$user" ]]; then
            authorized=true
            break
        fi

        # Also support pattern matching (e.g., @thomas* matches @thomas:srv1.local)
        if [[ "$sender" =~ ^${user} ]]; then
            authorized=true
            break
        fi
    done

    if [[ "$authorized" == "true" ]]; then
        log_debug "✓ Authorized sender: $sender"
        return 0
    else
        log_warn "✗ Unauthorized sender: $sender"
        return 1
    fi
}

# Add user to authorized users list
# Args: user_id
# Returns: 0 on success
authorize_user() {
    local user="$1"

    if [[ -z "$user" ]]; then
        log_error "User ID required"
        return 1
    fi

    local current_users="${AUTHORIZED_USERS:-$DEFAULT_AUTHORIZED_USERS}"

    # Check if already authorized
    if is_authorized_sender "$user"; then
        log_info "User already authorized: $user"
        return 0
    fi

    # Add to list
    export AUTHORIZED_USERS="$current_users,$user"
    log_success "User authorized: $user"
    return 0
}

# Remove user from authorized users list
# Args: user_id
# Returns: 0 on success
deauthorize_user() {
    local user="$1"

    if [[ -z "$user" ]]; then
        log_error "User ID required"
        return 1
    fi

    local current_users="${AUTHORIZED_USERS:-$DEFAULT_AUTHORIZED_USERS}"

    # Remove user from comma-separated list
    local new_users
    new_users=$(echo "$current_users" | tr ',' '\n' | grep -v "^${user}$" | tr '\n' ',' | sed 's/,$//')

    export AUTHORIZED_USERS="$new_users"
    log_success "User deauthorized: $user"
    return 0
}

# List all authorized users
# Returns: Comma-separated list of authorized users
list_authorized_users() {
    echo "${AUTHORIZED_USERS:-$DEFAULT_AUTHORIZED_USERS}"
}

# Check if current user matches configured Matrix user
# Args: user_id
# Returns: 0 if matches, 1 otherwise
is_self() {
    local user="$1"

    if [[ -z "$user" ]]; then
        return 1
    fi

    if ! is_matrix_config_loaded; then
        log_error "Matrix configuration not loaded"
        return 1
    fi

    if [[ "$user" == "$MATRIX_USER_ID" ]]; then
        return 0
    fi

    return 1
}

# Validate user ID format
# Args: user_id
# Returns: 0 if valid format, 1 otherwise
validate_user_id_format() {
    local user_id="$1"

    if [[ -z "$user_id" ]]; then
        return 1
    fi

    # Matrix user IDs have format: @localpart:domain
    if [[ "$user_id" =~ ^@[a-zA-Z0-9._=-]+:[a-zA-Z0-9.-]+$ ]]; then
        return 0
    fi

    log_debug "Invalid user ID format: $user_id"
    return 1
}
