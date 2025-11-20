#!/bin/bash
# ============================================================================
# JSON Utilities Library for Aria Autonomous Infrastructure
# ============================================================================
#
# Provides JSON parsing and manipulation utilities
#
# Usage:
#   source "$(dirname $0)/lib/json_utils.sh"
#   value=$(parse_json_field "config.json" "homeserver")
#   json=$(build_json msgtype "m.text" body "Hello")
#
# Features:
# - Prefer jq, fallback to Python
# - Error handling for missing files/fields
# - Support for nested field paths
# - JSON building utilities
# ============================================================================

# Prevent multiple loading
[[ -n "$ARIA_JSON_UTILS_LOADED" ]] && return 0
readonly ARIA_JSON_UTILS_LOADED=1

# ============================================================================
# Public API
# ============================================================================

# Parse single JSON field from file
# Args: json_file, field_path (e.g., "homeserver" or "config.instance_name")
# Returns: Field value to stdout, 1 on error
parse_json_field() {
    local json_file="$1"
    local field_path="$2"

    if [[ -z "$json_file" ]]; then
        echo "Error: JSON file path required" >&2
        return 1
    fi

    if [[ -z "$field_path" ]]; then
        echo "Error: JSON field path required" >&2
        return 1
    fi

    # Special case: read from stdin
    if [[ "$json_file" == "/dev/stdin" ]] || [[ "$json_file" == "-" ]]; then
        local json_content
        json_content=$(cat)

        if command -v jq >/dev/null 2>&1; then
            echo "$json_content" | jq -r ".$field_path // empty" 2>/dev/null
        else
            echo "$json_content" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('$field_path', ''))" 2>/dev/null
        fi
        return $?
    fi

    if [[ ! -f "$json_file" ]]; then
        echo "Error: JSON file not found: $json_file" >&2
        return 1
    fi

    # Try jq first (faster, more reliable)
    if command -v jq >/dev/null 2>&1; then
        jq -r ".$field_path // empty" "$json_file" 2>/dev/null
        return $?
    fi

    # Fallback to Python
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json; data=json.load(open('$json_file')); print(data.get('$field_path', ''))" 2>/dev/null
        return $?
    fi

    echo "Error: Neither jq nor python3 available for JSON parsing" >&2
    return 1
}

# Build JSON object from key-value pairs
# Args: key1 value1 key2 value2 ...
# Returns: JSON string to stdout
build_json() {
    if [[ $# -eq 0 ]]; then
        echo "{}"
        return 0
    fi

    if [[ $(( $# % 2 )) -ne 0 ]]; then
        echo "Error: build_json requires even number of arguments (key-value pairs)" >&2
        return 1
    fi

    # Try jq first
    if command -v jq >/dev/null 2>&1; then
        # Build jq command with named arguments
        local args=()
        while [[ $# -gt 0 ]]; do
            local key="$1"
            local value="$2"
            args+=("--arg" "$key" "$value")
            shift 2
        done

        # Build object from args
        local jq_expr='$ARGS.named'
        jq -n "${args[@]}" "$jq_expr" 2>/dev/null
        return $?
    fi

    # Fallback to Python
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json,sys; print(json.dumps(dict(zip(sys.argv[1::2], sys.argv[2::2]))))" "$@" 2>/dev/null
        return $?
    fi

    echo "Error: Neither jq nor python3 available for JSON building" >&2
    return 1
}

# Check if JSON file is valid
# Args: json_file
# Returns: 0 if valid, 1 if invalid
validate_json_file() {
    local json_file="$1"

    if [[ ! -f "$json_file" ]]; then
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        jq empty "$json_file" >/dev/null 2>&1
        return $?
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import json; json.load(open('$json_file'))" >/dev/null 2>&1
        return $?
    fi

    return 1
}

# Extract field from JSON string (not file)
# Args: json_string, field_path
# Returns: Field value to stdout, 1 on error
parse_json_string() {
    local json_string="$1"
    local field_path="$2"

    if [[ -z "$json_string" ]]; then
        echo "Error: JSON string required" >&2
        return 1
    fi

    if [[ -z "$field_path" ]]; then
        echo "Error: Field path required" >&2
        return 1
    fi

    if command -v jq >/dev/null 2>&1; then
        echo "$json_string" | jq -r ".$field_path // empty" 2>/dev/null
        return $?
    fi

    if command -v python3 >/dev/null 2>&1; then
        echo "$json_string" | python3 -c "import json,sys; data=json.load(sys.stdin); print(data.get('$field_path', ''))" 2>/dev/null
        return $?
    fi

    echo "Error: Neither jq nor python3 available" >&2
    return 1
}
