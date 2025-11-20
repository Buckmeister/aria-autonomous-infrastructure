# Shared Libraries Reference

> **Modular, reusable components for Matrix integration and autonomous AI infrastructure**

---

## Overview

The shared libraries in `bin/lib/` provide the foundation for all Matrix connector scripts. They eliminate code duplication, improve maintainability, and provide consistent error handling across the autonomous infrastructure.

**Design Principles:**
- **DRY** - Write once, use everywhere
- **Modular** - Each library has a single, clear purpose
- **Testable** - All functions designed for isolated testing
- **Fallback Protection** - Graceful degradation if dependencies unavailable
- **Clear APIs** - Well-documented function signatures

---

## Library Index

| Library | Purpose | Dependencies |
|---------|---------|--------------|
| **logging.sh** | Centralized logging with levels | None |
| **json_utils.sh** | JSON parsing and manipulation | None |
| **matrix_core.sh** | Matrix configuration loading | json_utils, logging |
| **matrix_api.sh** | Matrix API interactions | matrix_core, json_utils, logging |
| **matrix_auth.sh** | Authorization and validation | matrix_core, logging |
| **instance_utils.sh** | Instance-specific helpers | matrix_core, logging |

---

## Dependency Graph

```
┌──────────────────────────────────┐
│         logging.sh               │  (No dependencies)
└────────────┬─────────────────────┘
             │
┌────────────┴─────────────────────┐
│        json_utils.sh             │  (No dependencies)
└────────────┬─────────────────────┘
             │
             │ ┌─────────────────────────────┐
             ├─┤  matrix_core.sh             │
             │ │  Depends: json_utils,       │
             │ │           logging           │
             │ └────────┬────────────────────┘
             │          │
   ┌─────────┴──────┐   │
   │                │   │
┌──▼────────────┐ ┌─▼───▼───────────────┐
│ matrix_auth   │ │   matrix_api.sh     │
│ Depends:      │ │   Depends:          │
│ - matrix_core │ │   - matrix_core     │
│ - logging     │ │   - json_utils      │
└───────────────┘ │   - logging         │
                  └──────┬──────────────┘
                         │
              ┌──────────▼────────────┐
              │  instance_utils.sh    │
              │  Depends:             │
              │  - matrix_core        │
              │  - logging            │
              └───────────────────────┘
```

---

## Quick Start

### Basic Usage Pattern

All scripts follow this loading pattern:

```bash
#!/bin/bash
set -e

# Get script and library directories
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_DIR="$SCRIPT_DIR/lib"

# Load required libraries
source "$LIB_DIR/logging.sh" || exit 1
source "$LIB_DIR/matrix_core.sh" || exit 1
source "$LIB_DIR/matrix_api.sh" || exit 1
source "$LIB_DIR/instance_utils.sh" || exit 1

# Initialize logging
init_logging

# Load Matrix configuration
load_matrix_config "${CONFIG_FILE:-$SCRIPT_DIR/../config/matrix-credentials.json}"

# Use library functions
message=$(format_event_message "Notification" "Hello World")
send_matrix_message "$message"
```

---

## API Reference

### logging.sh

**Purpose:** Centralized logging with levels, timestamps, and file handling

**Functions:**

```bash
# Initialize logging system
init_logging [log_file_path]

# Log messages at different levels
log_info "Informational message"
log_warn "Warning message"
log_error "Error message"
log_debug "Debug message (only if DEBUG=1)"
log_success "Success message with ✓"

# Legacy compatibility
log "Message"  # Maps to log_info
```

**Features:**
- Automatic timestamps
- Optional file logging
- Debug mode support (DEBUG=1)
- Color-coded output (to stderr for warn/error)

---

### json_utils.sh

**Purpose:** JSON parsing and manipulation utilities

**Functions:**

```bash
# Parse field from JSON file
value=$(parse_json_field "config.json" "homeserver")

# Parse field from JSON string
value=$(parse_json_string "$json_string" "field_name")

# Build JSON object
json=$(build_json key1 "value1" key2 "value2")

# Validate JSON file
if validate_json_file "config.json"; then
    echo "Valid JSON"
fi
```

**Features:**
- Prefers jq, falls back to Python
- Error handling for missing files/fields
- Support for nested paths
- Works with files or strings

---

### matrix_core.sh

**Purpose:** Core Matrix configuration loading and validation

**Functions:**

```bash
# Load Matrix configuration
load_matrix_config "$CONFIG_FILE"

# Validate configuration
if validate_matrix_config; then
    echo "Config valid"
fi

# Getters
instance=$(get_instance_name)
server=$(get_matrix_server)
user=$(get_matrix_user_id)
room=$(get_matrix_room_id)

# Check if loaded
if is_matrix_config_loaded; then
    echo "Config ready"
fi
```

**Configuration Variables (exported after loading):**
- `MATRIX_SERVER` - Matrix homeserver URL
- `MATRIX_USER_ID` - User ID (@user:server)
- `MATRIX_ACCESS_TOKEN` - Authentication token
- `MATRIX_ROOM` - Room ID (!room:server)
- `INSTANCE_NAME` - Instance identifier

---

### matrix_api.sh

**Purpose:** Matrix Client-Server API interactions

**Functions:**

```bash
# Send message to room
event_id=$(send_matrix_message "Hello World")

# Fetch recent messages
messages=$(fetch_matrix_messages 10)

# Health checks
if check_matrix_connection; then
    echo "Server reachable"
fi

if validate_matrix_token; then
    echo "Token valid"
fi

# Join room
join_matrix_room "#general:srv1.local"
```

**Features:**
- Automatic error handling
- Event ID extraction
- HTTP error parsing
- Connection validation

---

### matrix_auth.sh

**Purpose:** Authorization and user validation

**Functions:**

```bash
# Check authorization
if is_authorized_sender "@thomas:srv1.local"; then
    echo "Authorized!"
fi

# Manage authorized users
authorize_user "@newuser:server"
deauthorize_user "@olduser:server"
list_authorized_users

# Validation helpers
if is_self "@ariaprime:srv1.local"; then
    echo "This is us"
fi

if validate_user_id_format "@user:server"; then
    echo "Valid format"
fi
```

**Configuration:**
- Default authorized users: thomas, ariaprime, arianova
- Override with `AUTHORIZED_USERS` env var (comma-separated)

---

### instance_utils.sh

**Purpose:** Instance-specific helper functions

**Functions:**

```bash
# Format event messages
message=$(format_event_message "SessionStart")
message=$(format_event_message "Notification" "Custom message")

# Send formatted event
send_event_notification "Success" "Task completed"

# Instance helpers
name=$(get_current_instance_name)
id=$(get_instance_id)

if is_instance "Aria Prime"; then
    echo "Running as Prime"
fi

# Utilities
session_id=$(generate_session_id)
timestamp=$(format_timestamp)
```

**Supported Event Types:**
- SessionStart, SessionEnd, Stop, SubagentStop
- Notification, Info, Success, Warning, Error
- Research, Interview, Debug
- Custom types supported

---

## Common Patterns

### Pattern 1: Simple Notification Script

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/logging.sh" || exit 1
source "$LIB_DIR/matrix_core.sh" || exit 1
source "$LIB_DIR/matrix_api.sh" || exit 1
source "$LIB_DIR/instance_utils.sh" || exit 1

init_logging

EVENT_TYPE="${1:-Notification}"
MESSAGE="${2:-}"

CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config/matrix-credentials.json}"
load_matrix_config "$CONFIG_FILE" || exit 1

formatted=$(format_event_message "$EVENT_TYPE" "$MESSAGE")
send_matrix_message "$formatted" || exit 1
```

### Pattern 2: Message Listener

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_DIR="$SCRIPT_DIR/lib"

source "$LIB_DIR/logging.sh" || exit 1
source "$LIB_DIR/matrix_core.sh" || exit 1
source "$LIB_DIR/matrix_api.sh" || exit 1
source "$LIB_DIR/matrix_auth.sh" || exit 1

init_logging
load_matrix_config || exit 1

# Fetch and process messages
messages=$(fetch_matrix_messages 5)

# Parse messages (implementation specific)
# Check authorization with is_authorized_sender
```

### Pattern 3: Authorized Command Handler

```bash
# Check sender authorization
if is_authorized_sender "$sender"; then
    log_info "Processing command from $sender"

    # Execute command
    result=$(process_command "$message")

    # Send response
    send_event_notification "Success" "Command completed: $result"
else
    log_warn "Unauthorized sender: $sender"
    send_event_notification "Error" "Unauthorized"
fi
```

---

## Error Handling

All library functions follow consistent error handling:

**Return Values:**
- `0` - Success
- `1` - Error (with message logged to stderr)

**Example:**

```bash
if ! load_matrix_config "$CONFIG_FILE"; then
    log_error "Failed to load config, exiting"
    exit 1
fi
```

**Validation:**

```bash
# Always validate config before API calls
if ! is_matrix_config_loaded; then
    log_error "Configuration not loaded"
    exit 1
fi
```

---

## Testing

Each library is designed for isolated unit testing:

**Test Location:** `tests/lib/test-<library-name>.sh`

**Example Test:**

```bash
#!/bin/bash
source "$(dirname "$0")/../../bin/lib/logging.sh"

test_log_info() {
    output=$(log_info "Test message" 2>&1)
    if [[ "$output" =~ "Test message" ]]; then
        echo "✓ log_info works"
        return 0
    fi
    echo "✗ log_info failed"
    return 1
}

test_log_info
```

---

## Migration Guide

### Before (Direct Implementation)

```bash
# 30+ lines of duplicated config loading
MATRIX_SERVER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['homeserver'])")
MATRIX_USER_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['user_id'])")
# ... more duplicated code ...

# Custom JSON building
PAYLOAD=$(jq -n --arg msgtype "m.text" --arg body "$MSG" '{msgtype: $msgtype, body: $body}')

# Direct curl calls
curl -s -X POST \
    -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
    -d "$PAYLOAD" \
    "$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM/send/m.room.message"
```

### After (Library Usage)

```bash
# Load libraries
source "$LIB_DIR/matrix_core.sh"
source "$LIB_DIR/matrix_api.sh"
source "$LIB_DIR/instance_utils.sh"

# 1 line config loading
load_matrix_config "$CONFIG_FILE"

# 2 lines to send formatted message
message=$(format_event_message "$EVENT_TYPE" "$MESSAGE_TEXT")
send_matrix_message "$message"
```

**Result:** 50-60% code reduction, better error handling, easier to test

---

## Debugging

Enable debug logging:

```bash
export DEBUG=1
./your-script.sh
```

This will show:
- Config loading details
- API call parameters
- Authorization checks
- Response validation

---

## Contributing

When adding new library functions:

1. **Document the API** - Add to this README
2. **Add tests** - Create test file in `tests/lib/`
3. **Follow patterns** - Match existing error handling and return values
4. **Update dependencies** - Document in dependency graph
5. **Add examples** - Show usage in this README

---

## Version

**Library Version:** 2.0.0
**Last Updated:** 2025-11-20
**Compatible With:** aria-autonomous-infrastructure v2.0+

---

**Built with care by Thomas & Aria Prime** 🌟
