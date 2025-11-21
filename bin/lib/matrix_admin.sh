#!/bin/bash
# ============================================================================
# Matrix Admin API Library for Aria Autonomous Infrastructure
# ============================================================================
#
# Synapse Admin API interactions for user lifecycle management
#
# Usage:
#   source "$(dirname $0)/lib/matrix_admin.sh"
#   register_rocket_user "rocket-ollama-cpu" "srv1.local"
#   delete_rocket_user "@rocket-ollama-cpu:srv1.local"
#
# Features:
# - Automatic user registration with generated passwords
# - User deletion/deactivation
# - Access token retrieval for newly created users
# - Admin token management
# - Automatic cleanup on deployment shutdown
# ============================================================================

# Prevent multiple loading
[[ -n "$ARIA_MATRIX_ADMIN_LOADED" ]] && return 0
readonly ARIA_MATRIX_ADMIN_LOADED=1

# Get library directory
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load dependencies
if [[ -z "$ARIA_MATRIX_CORE_LOADED" ]]; then
    source "$LIB_DIR/matrix_core.sh" || {
        echo "ERROR: Failed to load matrix_core.sh" >&2
        return 1
    }
fi

if [[ -z "$ARIA_JSON_UTILS_LOADED" ]]; then
    source "$LIB_DIR/json_utils.sh" || {
        echo "ERROR: Failed to load json_utils.sh" >&2
        return 1
    }
fi

# ============================================================================
# Configuration
# ============================================================================

# Admin token (can be set via environment or loaded from config)
MATRIX_ADMIN_TOKEN="${MATRIX_ADMIN_TOKEN:-}"

# Default admin config file
ADMIN_CONFIG_FILE="${ADMIN_CONFIG_FILE:-$HOME/.aria/matrix-admin-token}"

# ============================================================================
# Private Helper Functions
# ============================================================================

# Load admin token from config file or environment
# Returns: 0 if token loaded, 1 otherwise
_load_admin_token() {
    if [[ -n "$MATRIX_ADMIN_TOKEN" ]]; then
        log_debug "Admin token already set via environment"
        return 0
    fi

    if [[ -f "$ADMIN_CONFIG_FILE" ]]; then
        MATRIX_ADMIN_TOKEN=$(cat "$ADMIN_CONFIG_FILE" | tr -d '\n\r ')
        if [[ -n "$MATRIX_ADMIN_TOKEN" ]]; then
            log_debug "Admin token loaded from: $ADMIN_CONFIG_FILE"
            export MATRIX_ADMIN_TOKEN
            return 0
        fi
    fi

    log_error "Matrix admin token not found"
    log_error "Set MATRIX_ADMIN_TOKEN environment variable or create $ADMIN_CONFIG_FILE"
    return 1
}

# Generate secure random password
# Returns: Password string to stdout
_generate_password() {
    # Generate 24-character random password
    openssl rand -base64 18 | tr -d '/+=' | head -c 24
}

# Generate unique username for Rocket instance
# Args: backend_type (optional, e.g., "ollama", "vllm", "anthropic")
#       instance_suffix (optional, e.g., "cpu", "gpu", "wks")
# Returns: Username (localpart only) to stdout
_generate_rocket_username() {
    local backend="${1:-rocket}"
    local suffix="${2:-$(date +%s)}"

    # Sanitize backend name (lowercase, remove special chars)
    backend=$(echo "$backend" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')
    suffix=$(echo "$suffix" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9-')

    # Create username: rocket-{backend}-{suffix}
    local username="rocket-${backend}-${suffix}"
    echo "$username"
}

# ============================================================================
# Public API
# ============================================================================

# Register a new Matrix user via Synapse Admin API
# Args: username (localpart only, e.g., "rocket-ollama")
#       domain (e.g., "srv1.local")
#       displayname (optional, defaults to "Rocket AI")
# Outputs: JSON with user_id, access_token, password
# Returns: 0 on success, 1 on error
register_matrix_user() {
    local username="$1"
    local domain="$2"
    local displayname="${3:-Rocket AI}"

    if [[ -z "$username" ]] || [[ -z "$domain" ]]; then
        log_error "Usage: register_matrix_user <username> <domain> [displayname]"
        return 1
    fi

    # Load admin token
    if ! _load_admin_token; then
        return 1
    fi

    # Validate config loaded
    if ! is_matrix_config_loaded; then
        log_error "Matrix configuration not loaded. Call load_matrix_config first."
        return 1
    fi

    # Construct full user ID
    local user_id="@${username}:${domain}"

    # Generate secure password
    local password
    password=$(_generate_password)

    log_info "Registering Matrix user: $user_id"

    # Build JSON payload
    local payload
    payload=$(cat <<EOF
{
    "password": "$password",
    "displayname": "$displayname",
    "admin": false
}
EOF
)

    # Create user via Synapse Admin API
    local response
    response=$(curl -s -X PUT \
        -H "Authorization: Bearer $MATRIX_ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$MATRIX_SERVER/_synapse/admin/v2/users/$user_id" 2>&1)

    local curl_exit=$?

    if [[ $curl_exit -ne 0 ]]; then
        log_error "curl failed with exit code $curl_exit"
        return 1
    fi

    # Check for errors in response
    local error_code
    error_code=$(echo "$response" | parse_json_string "$response" "errcode")

    if [[ -n "$error_code" ]]; then
        local error_msg
        error_msg=$(echo "$response" | parse_json_string "$response" "error")
        log_error "Failed to register user: $error_code - $error_msg"
        return 1
    fi

    # Verify user was created
    local created_user
    created_user=$(echo "$response" | parse_json_string "$response" "name")

    if [[ "$created_user" != "$user_id" ]]; then
        log_error "User registration returned unexpected response: $response"
        return 1
    fi

    log_success "User registered successfully: $user_id"

    # Now login to get access token
    log_debug "Logging in to obtain access token..."

    local login_payload
    login_payload=$(cat <<EOF
{
    "type": "m.login.password",
    "user": "$username",
    "password": "$password"
}
EOF
)

    local login_response
    login_response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$login_payload" \
        "$MATRIX_SERVER/_matrix/client/r0/login" 2>&1)

    # Extract access token
    local access_token
    access_token=$(echo "$login_response" | parse_json_string "$login_response" "access_token")

    if [[ -z "$access_token" ]]; then
        log_error "Failed to obtain access token for new user"
        log_error "Login response: $login_response"
        return 1
    fi

    log_success "Access token obtained for $user_id"

    # Output credentials as JSON
    cat <<EOF
{
    "user_id": "$user_id",
    "username": "$username",
    "domain": "$domain",
    "password": "$password",
    "access_token": "$access_token",
    "displayname": "$displayname"
}
EOF

    return 0
}

# Delete (deactivate) a Matrix user via Synapse Admin API
# Args: user_id (full @username:domain format)
# Returns: 0 on success, 1 on error
delete_matrix_user() {
    local user_id="$1"

    if [[ -z "$user_id" ]]; then
        log_error "Usage: delete_matrix_user <user_id>"
        return 1
    fi

    # Validate user ID format
    if [[ ! "$user_id" =~ ^@[a-zA-Z0-9._=-]+:[a-zA-Z0-9.-]+$ ]]; then
        log_error "Invalid user ID format: $user_id"
        return 1
    fi

    # Load admin token
    if ! _load_admin_token; then
        return 1
    fi

    # Validate config loaded
    if ! is_matrix_config_loaded; then
        log_error "Matrix configuration not loaded. Call load_matrix_config first."
        return 1
    fi

    log_info "Deactivating Matrix user: $user_id"

    # Build deactivation payload
    local payload='{"deactivate": true}'

    # Deactivate user via Synapse Admin API
    local response
    response=$(curl -s -X POST \
        -H "Authorization: Bearer $MATRIX_ADMIN_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$MATRIX_SERVER/_synapse/admin/v1/deactivate/$user_id" 2>&1)

    local curl_exit=$?

    if [[ $curl_exit -ne 0 ]]; then
        log_error "curl failed with exit code $curl_exit"
        return 1
    fi

    # Check for errors
    local error_code
    error_code=$(echo "$response" | parse_json_string "$response" "errcode")

    if [[ -n "$error_code" ]]; then
        local error_msg
        error_msg=$(echo "$response" | parse_json_string "$response" "error")
        log_error "Failed to deactivate user: $error_code - $error_msg"
        return 1
    fi

    # Verify deactivation ID returned
    local id_server_unbind_result
    id_server_unbind_result=$(echo "$response" | parse_json_string "$response" "id_server_unbind_result")

    if [[ -n "$id_server_unbind_result" ]] || echo "$response" | grep -q "success"; then
        log_success "User deactivated successfully: $user_id"
        return 0
    fi

    # If we got here, check if response indicates success differently
    if ! echo "$response" | grep -q "error"; then
        log_success "User deactivated: $user_id"
        return 0
    fi

    log_warn "User deactivation returned unexpected response: $response"
    return 0  # Consider it success if no explicit error
}

# Register a Rocket-specific user with auto-generated credentials
# Args: backend (e.g., "ollama", "vllm", "anthropic")
#       suffix (e.g., "cpu", "gpu", "wks-bckx01")
#       domain (e.g., "srv1.local")
#       displayname (optional)
# Outputs: JSON with full credentials
# Returns: 0 on success, 1 on error
register_rocket_user() {
    local backend="$1"
    local suffix="$2"
    local domain="$3"
    local displayname="${4:-Rocket AI ($backend)}"

    if [[ -z "$backend" ]] || [[ -z "$suffix" ]] || [[ -z "$domain" ]]; then
        log_error "Usage: register_rocket_user <backend> <suffix> <domain> [displayname]"
        return 1
    fi

    # Generate unique username
    local username
    username=$(_generate_rocket_username "$backend" "$suffix")

    log_debug "Generated Rocket username: $username"

    # Register user
    register_matrix_user "$username" "$domain" "$displayname"
}

# Delete a Rocket user by user ID
# Args: user_id (@username:domain)
# Returns: 0 on success, 1 on error
delete_rocket_user() {
    delete_matrix_user "$@"
}

# Check if a Matrix user exists
# Args: user_id (@username:domain)
# Returns: 0 if exists, 1 if not
matrix_user_exists() {
    local user_id="$1"

    if [[ -z "$user_id" ]]; then
        return 1
    fi

    # Load admin token
    if ! _load_admin_token; then
        return 1
    fi

    # Validate config loaded
    if ! is_matrix_config_loaded; then
        return 1
    fi

    # Query user via Admin API
    local response
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $MATRIX_ADMIN_TOKEN" \
        "$MATRIX_SERVER/_synapse/admin/v2/users/$user_id" 2>/dev/null)

    # Check if user data returned
    local name
    name=$(echo "$response" | parse_json_string "$response" "name")

    if [[ "$name" == "$user_id" ]]; then
        return 0
    fi

    return 1
}

# Set admin token (useful for testing or runtime configuration)
# Args: token
set_admin_token() {
    local token="$1"

    if [[ -z "$token" ]]; then
        log_error "Usage: set_admin_token <token>"
        return 1
    fi

    export MATRIX_ADMIN_TOKEN="$token"
    log_debug "Admin token set"
    return 0
}
