#!/bin/bash

# ============================================================================
# Deployment Utilities Library for Aria Autonomous Infrastructure
# ============================================================================
#
# Provides common deployment functions, logging, Docker operations, and SSH
# helpers used across deployment scripts (launch-rocket.sh, launch-rocket-gpu.sh)
#
# Usage:
#   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   LIB_DIR="$SCRIPT_DIR/lib"
#   source "$LIB_DIR/deployment_utils.sh"
#
# Features:
# - Centralized logging with color output
# - Docker operation helpers
# - SSH operation helpers for remote deployment
# - Common validation functions
# - Argument parsing utilities
# ============================================================================

# Prevent multiple loading
[[ -n "$DEPLOYMENT_UTILS_LOADED" ]] && return 0
readonly DEPLOYMENT_UTILS_LOADED=1

# ============================================================================
# Color Constants
# ============================================================================

readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_RESET='\033[0m'

# ============================================================================
# Logging Functions
# ============================================================================

# Log informational message
log_info() {
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

# Log success message
log_success() {
    echo -e "${COLOR_GREEN}[SUCCESS]${COLOR_RESET} $*"
}

# Log warning message
log_warn() {
    echo -e "${COLOR_YELLOW}[WARN]${COLOR_RESET} $*"
}

# Log error message
log_error() {
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*"
}

# Exit with error message
exit_with_error() {
    local message="$1"
    local exit_code="${2:-1}"
    log_error "$message"
    exit "$exit_code"
}

# ============================================================================
# Validation Functions
# ============================================================================

# Validate that required parameters are set
# Usage: validate_required_params "PARAM1" "PARAM2" ...
validate_required_params() {
    local param_names=("$@")
    local missing=()

    for param in "${param_names[@]}"; do
        if [[ -z "${!param}" ]]; then
            missing+=("$param")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required parameters: ${missing[*]}"
        return 1
    fi

    return 0
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Validate Docker is running
validate_docker() {
    if ! command_exists docker; then
        exit_with_error "Docker command not found. Please install Docker first."
    fi

    if ! docker info > /dev/null 2>&1; then
        exit_with_error "Docker is not running. Please start Docker first."
    fi

    log_success "Docker is running"
}

# ============================================================================
# Docker Operation Helpers
# ============================================================================

# Check if Docker container exists
# Usage: container_exists "container_name"
container_exists() {
    local container_name="$1"
    docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"
}

# Remove Docker container with confirmation
# Usage: remove_container_with_confirmation "container_name"
remove_container_with_confirmation() {
    local container_name="$1"

    if ! container_exists "$container_name"; then
        return 0
    fi

    log_warn "Container '$container_name' already exists"
    read -p "Remove and recreate? (y/n) " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Removing existing container..."
        docker rm -f "$container_name"
        log_success "Container removed"
        return 0
    else
        log_error "Deployment cancelled"
        return 1
    fi
}

# Wait for HTTP endpoint to be available
# Usage: wait_for_endpoint "http://localhost:8080/health" "Service" <max_wait_seconds>
wait_for_endpoint() {
    local endpoint="$1"
    local service_name="$2"
    local max_wait="${3:-300}"

    log_info "⏳ Waiting for $service_name to be ready..."

    local wait_time=0
    while [[ $wait_time -lt $max_wait ]]; do
        if curl -s "$endpoint" > /dev/null 2>&1; then
            log_success "$service_name ready!"
            return 0
        fi
        sleep 5
        wait_time=$((wait_time + 5))
        echo -n "."
    done
    echo

    log_error "$service_name startup timed out after ${max_wait}s"
    return 1
}

# Check if process is running in container
# Usage: container_process_running "container_name" "process_pattern"
container_process_running() {
    local container_name="$1"
    local process_pattern="$2"

    docker exec "$container_name" ps aux 2>/dev/null | grep -q "[$process_pattern]"
}

# ============================================================================
# SSH Operation Helpers
# ============================================================================

# Test SSH connectivity
# Usage: test_ssh_connection "user@host" "/path/to/key"
test_ssh_connection() {
    local ssh_target="$1"
    local ssh_key="$2"

    log_info "🔌 Testing SSH connection to $ssh_target..."

    if ! ssh -i "$ssh_key" "$ssh_target" "echo Connected" > /dev/null 2>&1; then
        exit_with_error "Cannot connect to $ssh_target"
    fi

    log_success "SSH connection OK"
}

# Execute command on remote host via SSH
# Usage: ssh_exec "user@host" "/path/to/key" "command"
ssh_exec() {
    local ssh_target="$1"
    local ssh_key="$2"
    local command="$3"

    ssh -i "$ssh_key" "$ssh_target" "$command"
}

# Copy files to remote host
# Usage: ssh_copy "user@host" "/path/to/key" "local_path" "remote_path"
ssh_copy() {
    local ssh_target="$1"
    local ssh_key="$2"
    local local_path="$3"
    local remote_path="$4"

    scp -i "$ssh_key" -r "$local_path" "$ssh_target:$remote_path"
}

# ============================================================================
# Configuration File Helpers
# ============================================================================

# Create Matrix credentials JSON file
# Usage: create_matrix_credentials_file "output_path" "server" "user" "token" "room" "instance_name"
create_matrix_credentials_file() {
    local output_path="$1"
    local server="$2"
    local user="$3"
    local token="$4"
    local room="$5"
    local instance_name="$6"

    cat > "$output_path" << MATRIX_EOF
{
  "homeserver": "$server",
  "user_id": "$user",
  "access_token": "$token",
  "room_id": "$room",
  "instance_name": "$instance_name"
}
MATRIX_EOF
}

# ============================================================================
# Display Helpers
# ============================================================================

# Display deployment configuration summary
# Usage: display_config_summary "key1=value1" "key2=value2" ...
display_config_summary() {
    echo
    for line in "$@"; do
        echo "  $line"
    done
    echo
}

# Display final deployment status
# Usage: display_deployment_status "Container Name" "container_name" "model" "matrix_user" "matrix_room" "commands..."
display_deployment_status() {
    echo
    log_success "🎉 Deployment complete!"
    echo
}

# ============================================================================
# Argument Parsing Helpers
# ============================================================================

# Parse boolean flag from arguments
# Usage: has_flag "--help" "$@"
has_flag() {
    local flag="$1"
    shift

    for arg in "$@"; do
        if [[ "$arg" == "$flag" ]]; then
            return 0
        fi
    done

    return 1
}

# Get value for flag from arguments
# Usage: value=$(get_flag_value "--model" "$@")
get_flag_value() {
    local flag="$1"
    shift

    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "$flag" ]]; then
            echo "$2"
            return 0
        fi
        shift
    done

    return 1
}

# ============================================================================
# Export Functions
# ============================================================================

# Export all functions so they're available in calling scripts
export -f log_info log_success log_warn log_error exit_with_error
export -f validate_required_params command_exists validate_docker
export -f container_exists remove_container_with_confirmation wait_for_endpoint container_process_running
export -f test_ssh_connection ssh_exec ssh_copy
export -f create_matrix_credentials_file
export -f display_config_summary display_deployment_status
export -f has_flag get_flag_value
