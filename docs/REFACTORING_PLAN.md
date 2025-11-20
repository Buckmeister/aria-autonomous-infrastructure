# Matrix Connector Refactoring Plan

> **Applying dotfiles shared library patterns to autonomous infrastructure**
>
> A comprehensive plan to refactor Matrix connector scripts into a maintainable, modular architecture

**Date:** 2025-11-20
**Authors:** Thomas & Aria Prime
**Status:** 📋 Planning Phase
**Target:** V2.0 of aria-autonomous-infrastructure

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [Current State Analysis](#current-state-analysis)
- [Problems to Solve](#problems-to-solve)
- [Proposed Architecture](#proposed-architecture)
- [Shared Library Design](#shared-library-design)
- [Migration Path](#migration-path)
- [Testing Strategy](#testing-strategy)
- [Documentation Updates](#documentation-updates)
- [Timeline & Milestones](#timeline--milestones)

---

## Executive Summary

### The Vision

Transform the aria-autonomous-infrastructure repository from a collection of individual scripts with duplicated logic into a **modular, maintainable library architecture** following the proven patterns from the dotfiles repository.

### Key Goals

1. **Eliminate Code Duplication** - Extract common Matrix operations into reusable libraries
2. **Improve Maintainability** - Single source of truth for Matrix API interactions
3. **Enhance Testability** - Isolated, testable library functions
4. **Better Documentation** - Clear API references and usage examples
5. **Preserve Compatibility** - Existing scripts continue to work during migration
6. **Apply Proven Patterns** - Leverage successful dotfiles library architecture

### Success Metrics

- ✅ Reduce code duplication by >60%
- ✅ All existing functionality preserved
- ✅ Library test coverage >80%
- ✅ Clear API documentation for all libraries
- ✅ Migration completed without breaking existing deployments

---

## Current State Analysis

### Existing Scripts

**Matrix Integration Scripts:**
1. **bin/matrix-notifier.sh** (103 lines)
   - Purpose: Send notifications via Matrix (hook integration)
   - Dependencies: jq, curl, Python (for JSON parsing)
   - Config: matrix-credentials.json

2. **bin/matrix-listener.sh** (137 lines)
   - Purpose: Listen for Matrix messages, inject into tmux
   - Dependencies: matrix-commander, tmux, Python
   - Config: matrix-credentials.json

3. **bin/matrix-event-handler.sh** (318 lines)
   - Purpose: Event-driven headless Claude sessions from Matrix
   - Dependencies: curl, Python, Claude Code
   - Config: matrix-credentials.json

4. **bin/consciousness-interview.py** (Python script)
   - Purpose: Autonomous consciousness research interviews
   - Matrix integration: Posts results to Matrix
   - Config: matrix-credentials.json

### Code Duplication Analysis

#### Config Loading (4 occurrences)

**Pattern duplicated across matrix-notifier.sh, matrix-listener.sh, matrix-event-handler.sh:**

```bash
# Load configuration from config file
if [ -f "$CONFIG_FILE" ]; then
    MATRIX_SERVER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['homeserver'])")
    MATRIX_USER_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['user_id'])")
    MATRIX_ACCESS_TOKEN=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['access_token'])")
    MATRIX_ROOM=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['room_id'])")
    INSTANCE_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('instance_name', 'AI Instance'))")
fi
```

**Issues:**
- Duplicated 4 times (3 bash scripts + 1 Python script)
- No error handling for malformed JSON
- Inefficient: spawns Python process for each field
- No validation of loaded values

#### Matrix API Calls (3 occurrences)

**Send Message Pattern:**

```bash
# matrix-notifier.sh
PAYLOAD=$(jq -n \
    --arg msgtype "m.text" \
    --arg body "$FULL_MSG" \
    '{msgtype: $msgtype, body: $body}')

curl -s -X POST \
    -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM/send/m.room.message" \
    > /dev/null 2>&1
```

**Issues:**
- Duplicated across multiple scripts
- No retry logic for failed sends
- Silent failure mode (redirects to /dev/null)
- No response validation

#### Logging (2 occurrences)

**Logging Pattern:**

```bash
# matrix-listener.sh & matrix-event-handler.sh
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}
```

**Issues:**
- Duplicated logging implementation
- No log levels (info/warn/error)
- No log rotation support
- Inconsistent across scripts (notifier has no logging)

#### JSON Parsing (4 occurrences)

**Pattern:**

```bash
python3 -c "import json; print(json.load(open('$FILE'))['key'])"
```

**Issues:**
- Spawns new Python process for every field access
- No error handling for missing keys
- No fallback if Python unavailable

---

## Problems to Solve

### 1. Maintenance Burden

**Problem:** Changes to Matrix API interaction require editing 3+ files

**Example:** Recently had to fix JSON encoding bug (adding jq usage)
- Had to update matrix-notifier.sh
- Didn't propagate fix to other scripts
- Risk of inconsistent behavior

**Solution:** Single source of truth for Matrix API calls

### 2. Testing Difficulty

**Problem:** Can't test Matrix logic in isolation

**Current State:**
- No unit tests for Matrix functions
- Integration tests require full Matrix server
- Hard to mock API responses

**Solution:** Extract testable library functions

### 3. Inconsistent Error Handling

**Problem:** Each script handles errors differently

**Examples:**
- notifier: Silent failures (> /dev/null 2>&1)
- listener: Logs errors but continues
- event-handler: Exits on some errors, not others

**Solution:** Standardized error handling in libraries

### 4. No Shared Utilities

**Problem:** No reusable utilities for common operations

**Examples:**
- Config loading (duplicated 4x)
- JSON parsing (duplicated 10+ times)
- Logging (duplicated 2x)
- HTTP error handling (inconsistent)

**Solution:** Shared library architecture

### 5. Documentation Scattered

**Problem:** No central API reference for Matrix operations

**Current State:**
- Logic embedded in scripts
- No function-level documentation
- Hard to understand what's available

**Solution:** Documented library APIs (following dotfiles pattern)

---

## Proposed Architecture

### Directory Structure

```
aria-autonomous-infrastructure/
├── bin/
│   ├── lib/                          # ← NEW: Shared libraries
│   │   ├── README.md                 # Library documentation & API reference
│   │   ├── matrix_core.sh            # Core Matrix config & constants
│   │   ├── matrix_api.sh             # Matrix API interactions
│   │   ├── matrix_auth.sh            # Authentication & authorization
│   │   ├── logging.sh                # Logging utilities
│   │   ├── json_utils.sh             # JSON parsing & manipulation
│   │   └── instance_utils.sh         # Instance-specific helpers
│   │
│   ├── matrix-notifier.sh            # ← REFACTORED: Uses libraries
│   ├── matrix-listener.sh            # ← REFACTORED: Uses libraries
│   ├── matrix-event-handler.sh       # ← REFACTORED: Uses libraries
│   └── consciousness-interview.py    # ← REFACTORED: Uses Python equivalent
│
├── config/
│   └── matrix-credentials.json       # Unchanged
│
├── tests/
│   ├── lib/                          # ← NEW: Library tests
│   │   ├── test-matrix-core.sh
│   │   ├── test-matrix-api.sh
│   │   ├── test-logging.sh
│   │   └── test-json-utils.sh
│   │
│   └── integration/                  # ← NEW: Integration tests
│       ├── test-notifier-with-libs.sh
│       └── test-listener-with-libs.sh
│
└── docs/
    ├── REFACTORING_PLAN.md           # ← This document
    └── LIBRARY_API.md                # ← NEW: Library API reference
```

### Dependency Graph

```
┌──────────────────────────────────────────────┐
│         logging.sh (no dependencies)         │
│     - log_info(), log_error(), etc.          │
└───────────────────┬──────────────────────────┘
                    │
┌──────────────────────────────────────────────┐
│       json_utils.sh (no dependencies)        │
│  - parse_json_field(), build_json(), etc.    │
└───────────────────┬──────────────────────────┘
                    │
                    │ ┌──────────────────────────────────┐
                    ├─┤  matrix_core.sh                  │
                    │ │  Dependencies: json_utils        │
                    │ │  - load_matrix_config()          │
                    │ │  - validate_config()             │
                    │ └──────────────────────────────────┘
                    │                │
        ┌───────────┴────────┐       │
        │                    │       │
┌───────▼─────────┐  ┌──────▼───────▼─────────────────┐
│ matrix_auth.sh  │  │      matrix_api.sh             │
│ Depends on:     │  │      Depends on:               │
│ - matrix_core   │  │      - matrix_core             │
│                 │  │      - json_utils              │
│ Functions:      │  │      - logging                 │
│ - is_authorized │  │                                │
│ - validate_user │  │      Functions:                │
└─────────────────┘  │      - send_matrix_message()   │
                     │      - fetch_matrix_messages() │
                     │      - handle_http_error()     │
                     └────────────────────────────────┘
                                    │
        ┌───────────────────────────┴─────────────────┐
        │                                             │
┌───────▼────────────────┐              ┌─────────────▼─────────┐
│  instance_utils.sh     │              │  Scripts use all libs │
│  Depends on:           │              │  - matrix-notifier    │
│  - matrix_core         │              │  - matrix-listener    │
│  - logging             │              │  - event-handler      │
│                        │              └───────────────────────┘
│  Functions:            │
│  - get_instance_name() │
│  - format_event_msg()  │
└────────────────────────┘
```

---

## Shared Library Design

### Library 1: `logging.sh`

**Purpose:** Centralized logging with levels, timestamps, and file handling

**No Dependencies**

**API:**

```bash
# Initialize logging system
# Args: log_file_path (optional)
# Returns: 0 on success
init_logging() { ... }

# Log info message
# Args: message
log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO] $*" | tee -a "$LOG_FILE"
}

# Log warning message
# Args: message
log_warn() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] $*" | tee -a "$LOG_FILE" >&2
}

# Log error message
# Args: message
log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" | tee -a "$LOG_FILE" >&2
}

# Log debug message (only if DEBUG=1)
# Args: message
log_debug() {
    if [[ "${DEBUG:-0}" == "1" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] [DEBUG] $*" | tee -a "$LOG_FILE" >&2
    fi
}
```

**Features:**
- ✅ Log levels: INFO, WARN, ERROR, DEBUG
- ✅ Timestamps on all messages
- ✅ Optional file logging
- ✅ Debug mode support
- ✅ Consistent formatting

---

### Library 2: `json_utils.sh`

**Purpose:** JSON parsing and manipulation utilities

**No Dependencies**

**API:**

```bash
# Parse single JSON field from file
# Args: json_file, field_path (e.g., "homeserver" or "config.instance_name")
# Returns: Field value to stdout, 1 on error
parse_json_field() {
    local json_file="$1"
    local field_path="$2"

    if [[ ! -f "$json_file" ]]; then
        echo "Error: JSON file not found: $json_file" >&2
        return 1
    fi

    # Try jq first (faster, more reliable)
    if command -v jq >/dev/null 2>&1; then
        jq -r ".$field_path // empty" "$json_file" 2>/dev/null
    else
        # Fallback to Python
        python3 -c "import json,sys; data=json.load(open('$json_file')); print(data.get('$field_path', ''))" 2>/dev/null
    fi
}

# Load entire JSON file into bash variables
# Args: json_file, variable_prefix
# Sets: ${prefix}_FIELD for each top-level field
load_json_config() {
    local json_file="$1"
    local prefix="${2:-CONFIG}"

    # Implementation: parses all fields and exports as bash variables
    ...
}

# Build JSON object from key-value pairs
# Args: key1 value1 key2 value2 ...
# Returns: JSON string to stdout
build_json() {
    if command -v jq >/dev/null 2>&1; then
        jq -n '$ARGS.named' --args "$@"
    else
        # Python fallback
        python3 -c "import json,sys; print(json.dumps(dict(zip(sys.argv[1::2], sys.argv[2::2]))))" "$@"
    fi
}
```

**Features:**
- ✅ Prefer jq, fallback to Python
- ✅ Error handling for missing files/fields
- ✅ Supports nested field paths
- ✅ Batch config loading
- ✅ JSON building utilities

---

### Library 3: `matrix_core.sh`

**Purpose:** Core Matrix configuration loading and validation

**Dependencies:** json_utils.sh

**API:**

```bash
# Load Matrix configuration from credentials file
# Args: config_file_path (optional, defaults to ../config/matrix-credentials.json)
# Sets: MATRIX_SERVER, MATRIX_USER_ID, MATRIX_ACCESS_TOKEN, MATRIX_ROOM, INSTANCE_NAME
# Returns: 0 on success, 1 on error
load_matrix_config() {
    local config_file="${1:-$DEFAULT_CONFIG_FILE}"

    if [[ ! -f "$config_file" ]]; then
        log_error "Matrix config file not found: $config_file"
        return 1
    fi

    # Use json_utils to load all fields efficiently
    MATRIX_SERVER=$(parse_json_field "$config_file" "homeserver")
    MATRIX_USER_ID=$(parse_json_field "$config_file" "user_id")
    MATRIX_ACCESS_TOKEN=$(parse_json_field "$config_file" "access_token")
    MATRIX_ROOM=$(parse_json_field "$config_file" "room_id")
    INSTANCE_NAME=$(parse_json_field "$config_file" "instance_name")

    # Validate required fields
    validate_matrix_config || return 1

    export MATRIX_SERVER MATRIX_USER_ID MATRIX_ACCESS_TOKEN MATRIX_ROOM INSTANCE_NAME
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
        return 1
    fi

    return 0
}

# Get configured instance name with fallback
# Returns: Instance name string
get_instance_name() {
    echo "${INSTANCE_NAME:-AI Instance}"
}
```

**Features:**
- ✅ Single source of truth for config loading
- ✅ Validation of required fields
- ✅ Clear error messages
- ✅ Exports variables for other scripts
- ✅ Fallback defaults

---

### Library 4: `matrix_api.sh`

**Purpose:** Matrix Client-Server API interactions

**Dependencies:** matrix_core.sh, json_utils.sh, logging.sh

**API:**

```bash
# Send text message to Matrix room
# Args: message_body
# Returns: 0 on success, event_id to stdout; 1 on error
send_matrix_message() {
    local message_body="$1"

    # Validate config loaded
    validate_matrix_config || return 1

    # Build JSON payload
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

    local exit_code=$?

    if [[ $exit_code -ne 0 ]]; then
        log_error "curl failed with exit code $exit_code"
        return 1
    fi

    # Extract event_id from response
    local event_id
    event_id=$(echo "$response" | parse_json_field /dev/stdin "event_id")

    if [[ -n "$event_id" ]]; then
        log_debug "Message sent successfully: $event_id"
        echo "$event_id"
        return 0
    else
        log_error "Failed to send message: $response"
        return 1
    fi
}

# Fetch recent messages from Matrix room
# Args: limit (optional, default 10)
# Returns: JSON response to stdout, 0 on success
fetch_matrix_messages() {
    local limit="${1:-10}"

    validate_matrix_config || return 1

    curl -s -X GET \
        -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
        "$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM/messages?limit=$limit&dir=b"
}

# Check if Matrix server is reachable
# Returns: 0 if reachable, 1 otherwise
check_matrix_connection() {
    local response
    response=$(curl -s -o /dev/null -w "%{http_code}" "$MATRIX_SERVER/_matrix/client/versions" 2>/dev/null)

    if [[ "$response" == "200" ]]; then
        log_debug "Matrix server reachable"
        return 0
    else
        log_error "Matrix server unreachable (HTTP $response)"
        return 1
    fi
}
```

**Features:**
- ✅ Send messages with error handling
- ✅ Fetch messages with pagination
- ✅ Connection health checks
- ✅ Event ID extraction
- ✅ Proper HTTP error handling

---

### Library 5: `matrix_auth.sh`

**Purpose:** Authorization and user validation

**Dependencies:** matrix_core.sh

**API:**

```bash
# Check if sender is authorized
# Args: sender_user_id
# Returns: 0 if authorized, 1 otherwise
is_authorized_sender() {
    local sender="$1"

    # Whitelist of authorized users
    case "$sender" in
        "@thomas:srv1.local"|"@ariaprime:srv1.local"|"@arianova:srv1.local")
            log_debug "Authorized sender: $sender"
            return 0
            ;;
        *)
            log_warn "Unauthorized sender: $sender"
            return 1
            ;;
    esac
}

# Validate Matrix access token
# Returns: 0 if valid, 1 if invalid
validate_access_token() {
    local response
    response=$(curl -s -X GET \
        -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
        "$MATRIX_SERVER/_matrix/client/r0/account/whoami" 2>/dev/null)

    local user_id
    user_id=$(echo "$response" | parse_json_field /dev/stdin "user_id")

    if [[ "$user_id" == "$MATRIX_USER_ID" ]]; then
        log_debug "Access token valid for $user_id"
        return 0
    else
        log_error "Access token invalid or expired"
        return 1
    fi
}
```

**Features:**
- ✅ Whitelist-based authorization
- ✅ Token validation via API
- ✅ Configurable authorized users
- ✅ Security logging

---

### Library 6: `instance_utils.sh`

**Purpose:** Instance-specific helper functions

**Dependencies:** matrix_core.sh, logging.sh

**API:**

```bash
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
        *)
            emoji="ℹ️"
            msg="[$instance_name] $event_type: $message_text"
            ;;
    esac

    echo "$emoji $msg"
}
```

**Features:**
- ✅ Consistent message formatting
- ✅ Event type handling
- ✅ Emoji support
- ✅ Instance name integration

---

## Migration Path

### Phase 1: Library Creation (Week 1)

**Goal:** Create and test all shared libraries

**Tasks:**
1. Create `bin/lib/` directory structure
2. Implement `logging.sh` with tests
3. Implement `json_utils.sh` with tests
4. Implement `matrix_core.sh` with tests
5. Implement `matrix_api.sh` with tests
6. Implement `matrix_auth.sh` with tests
7. Implement `instance_utils.sh` with tests
8. Create `bin/lib/README.md` with API documentation

**Deliverables:**
- ✅ 6 library files in bin/lib/
- ✅ Test suite for each library
- ✅ API documentation
- ✅ Dependency graph documented

**Success Criteria:**
- All library tests pass
- Each library has >80% test coverage
- API documentation complete

---

### Phase 2: Refactor matrix-notifier.sh (Week 1-2)

**Goal:** Migrate simplest script first (proof of concept)

**Current Lines:** 103
**Expected After Refactoring:** ~40-50

**Before:**
```bash
#!/bin/bash
set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config/matrix-credentials.json}"

# Parse command line
EVENT_TYPE="${1:-Unknown}"
MESSAGE_TEXT="${2:-}"

# Load configuration from environment or config file
if [ -f "$CONFIG_FILE" ]; then
    MATRIX_SERVER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['homeserver'])")
    MATRIX_USER_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['user_id'])")
    MATRIX_ACCESS_TOKEN=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['access_token'])")
    MATRIX_ROOM=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['room_id'])")
    INSTANCE_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('instance_name', 'AI Instance'))")
fi

# Override with environment variables if set
MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"
# ... many more lines ...

# Build message based on event type
case "$EVENT_TYPE" in
    SessionStart) EMOJI="🚀"; MSG="[$INSTANCE_NAME] Session started" ;;
    # ... many more cases ...
esac

# Send to Matrix
PAYLOAD=$(jq -n --arg msgtype "m.text" --arg body "$FULL_MSG" '{msgtype: $msgtype, body: $body}')
curl -s -X POST \
    -H "Authorization: Bearer $MATRIX_ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$MATRIX_SERVER/_matrix/client/r0/rooms/$MATRIX_ROOM/send/m.room.message" \
    > /dev/null 2>&1
```

**After:**
```bash
#!/bin/bash
set -e

# Get script directory and load libraries
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_DIR="$SCRIPT_DIR/lib"

# Load required libraries
source "$LIB_DIR/logging.sh" || exit 1
source "$LIB_DIR/json_utils.sh" || exit 1
source "$LIB_DIR/matrix_core.sh" || exit 1
source "$LIB_DIR/matrix_api.sh" || exit 1
source "$LIB_DIR/instance_utils.sh" || exit 1

# Initialize logging
init_logging

# Parse command line
EVENT_TYPE="${1:-Unknown}"
MESSAGE_TEXT="${2:-}"

# Load Matrix configuration
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config/matrix-credentials.json}"
load_matrix_config "$CONFIG_FILE" || {
    log_error "Failed to load Matrix configuration"
    exit 1
}

# Format message based on event type
MESSAGE=$(format_event_message "$EVENT_TYPE" "$MESSAGE_TEXT")

# Send to Matrix
if send_matrix_message "$MESSAGE"; then
    log_debug "Notification sent successfully"
    exit 0
else
    log_error "Failed to send notification"
    exit 1
fi
```

**Benefits:**
- 50% reduction in code
- Clear error handling
- Testable components
- Consistent with other scripts

**Validation:**
- Existing hooks continue to work
- Matrix messages sent successfully
- Error cases handled properly

---

### Phase 3: Refactor matrix-listener.sh (Week 2)

**Goal:** Migrate listener daemon

**Current Lines:** 137
**Expected After Refactoring:** ~60-70

**Key Changes:**
- Use `logging.sh` for all log messages
- Use `matrix_core.sh` for config loading
- Use `matrix_auth.sh` for authorization checks
- Extract message processing into testable functions

**Validation:**
- Daemon starts successfully
- Matrix listener functionality preserved
- Command injection still works
- Authorization checks pass

---

### Phase 4: Refactor matrix-event-handler.sh (Week 2-3)

**Goal:** Migrate event-driven handler

**Current Lines:** 318
**Expected After Refactoring:** ~150-180

**Key Changes:**
- Use all shared libraries
- Extract spawn_headless_session logic for testing
- Use `matrix_api.sh` for message fetching
- Use `matrix_auth.sh` for authorization

**Validation:**
- Event detection still works
- Headless sessions spawn correctly
- Authorization preserved
- Session metadata logging functional

---

### Phase 5: Python Library Equivalent (Week 3)

**Goal:** Create Python library for consciousness-interview.py

**Create:** `bin/lib/matrix_client.py`

```python
"""Python library for Matrix integration in autonomous infrastructure"""

import json
from pathlib import Path
from typing import Optional, Dict, Any
import subprocess

class MatrixClient:
    """Matrix client for autonomous AI instances"""

    def __init__(self, config_path: Optional[Path] = None):
        """Initialize Matrix client with configuration"""
        if config_path is None:
            config_path = Path.home() / 'aria-workspace' / 'aria-autonomous-infrastructure' / 'config' / 'matrix-credentials.json'

        self.config = self._load_config(config_path)
        self.homeserver = self.config['homeserver']
        self.access_token = self.config['access_token']
        self.room_id = self.config['room_id']
        self.instance_name = self.config.get('instance_name', 'AI Instance')

    def _load_config(self, config_path: Path) -> Dict[str, Any]:
        """Load configuration from JSON file"""
        with open(config_path) as f:
            return json.load(f)

    def send_message(self, message: str) -> Optional[str]:
        """Send message to Matrix room, returns event_id or None"""
        # Implementation matching bash library
        ...

    def format_event_message(self, event_type: str, message: str = "") -> str:
        """Format event message with emoji and instance name"""
        # Implementation matching bash library
        ...
```

**Refactor consciousness-interview.py:**
- Replace inline Matrix code with MatrixClient
- Consistent with bash libraries
- Better error handling

---

### Phase 6: Testing & Documentation (Week 3-4)

**Goal:** Comprehensive testing and documentation

**Testing Tasks:**
1. Unit tests for each library function
2. Integration tests for refactored scripts
3. End-to-end tests with real Matrix server
4. Regression tests (existing functionality preserved)

**Documentation Tasks:**
1. Complete `bin/lib/README.md` with all API references
2. Update main `README.md` with library architecture
3. Update `docs/ARCHITECTURE.md` with new design
4. Create `docs/LIBRARY_API.md` with comprehensive API docs
5. Update `docs/SETUP.md` with library installation steps

**Success Criteria:**
- All tests pass
- Test coverage >80%
- All APIs documented
- Migration guide complete

---

### Phase 7: Deployment & Validation (Week 4)

**Goal:** Deploy to production and validate

**Deployment Steps:**
1. Deploy to Aria Prime environment (Thomas's machine)
2. Deploy to Aria Nova environment (lat-bck00)
3. Validate hook integration still works
4. Validate listener daemon still works
5. Validate event handler still works
6. Validate consciousness interviews still work

**Validation Checklist:**
- ✅ Claude Code hooks trigger notifications
- ✅ Matrix messages sent successfully
- ✅ Listener daemon receives messages
- ✅ Event handler spawns sessions
- ✅ Consciousness interviews post to Matrix
- ✅ No regressions in existing functionality

**Rollback Plan:**
- Keep old scripts as `*.old` backups
- Git tag before deployment: `v1.0-pre-refactor`
- Can revert if issues found

---

## Testing Strategy

### Library Unit Tests

**Location:** `tests/lib/`

**Example: test-matrix-core.sh**

```bash
#!/bin/bash
# Test suite for matrix_core.sh library

source "$(dirname "$0")/../../bin/lib/matrix_core.sh"

test_load_valid_config() {
    # Create test config
    local test_config="/tmp/test-matrix-config.json"
    cat > "$test_config" <<EOF
{
  "homeserver": "http://test:8008",
  "user_id": "@test:server",
  "access_token": "test_token",
  "room_id": "!test:server",
  "instance_name": "Test Instance"
}
EOF

    # Load config
    load_matrix_config "$test_config"
    local result=$?

    # Assertions
    assert_equals 0 $result "Config should load successfully"
    assert_equals "http://test:8008" "$MATRIX_SERVER" "Server should match"
    assert_equals "@test:server" "$MATRIX_USER_ID" "User ID should match"

    # Cleanup
    rm "$test_config"
}

test_load_invalid_config() {
    load_matrix_config "/nonexistent/config.json"
    local result=$?

    assert_equals 1 $result "Should fail for missing config"
}

test_validate_missing_fields() {
    # Set incomplete config
    MATRIX_SERVER="http://test:8008"
    MATRIX_USER_ID=""
    MATRIX_ACCESS_TOKEN=""
    MATRIX_ROOM=""

    validate_matrix_config
    local result=$?

    assert_equals 1 $result "Should fail validation with missing fields"
}

# Run all tests
run_tests \
    test_load_valid_config \
    test_load_invalid_config \
    test_validate_missing_fields
```

### Integration Tests

**Location:** `tests/integration/`

**Example: test-notifier-with-libs.sh**

```bash
#!/bin/bash
# Integration test for matrix-notifier.sh with libraries

# Setup mock Matrix server or use test instance
setup_test_environment() {
    export CONFIG_FILE="$TEST_DIR/test-config.json"
    # Create test config
}

test_notifier_sends_message() {
    # Run notifier
    ../bin/matrix-notifier.sh "Notification" "Test message"

    # Verify message in Matrix room
    # (Could use Matrix API to fetch recent messages)
}

test_notifier_handles_missing_config() {
    export CONFIG_FILE="/nonexistent/config.json"

    ../bin/matrix-notifier.sh "Notification" "Test" 2>/dev/null
    local result=$?

    assert_equals 1 $result "Should exit with error for missing config"
}

# Run tests
run_integration_tests \
    test_notifier_sends_message \
    test_notifier_handles_missing_config
```

### Test Coverage Goals

**Library Coverage:**
- matrix_core.sh: >90%
- matrix_api.sh: >80%
- matrix_auth.sh: >80%
- logging.sh: >90%
- json_utils.sh: >90%
- instance_utils.sh: >85%

**Integration Coverage:**
- All refactored scripts tested end-to-end
- Matrix API interactions validated
- Error paths tested

---

## Documentation Updates

### New Documentation

1. **bin/lib/README.md** - Library reference (similar to dotfiles bin/lib/README.md)
   - Overview of all libraries
   - Dependency graph
   - Quick start examples
   - API reference for each library

2. **docs/LIBRARY_API.md** - Comprehensive API documentation
   - Function signatures
   - Parameters and return values
   - Usage examples
   - Common patterns

### Updated Documentation

1. **README.md** - Update with library architecture
2. **docs/ARCHITECTURE.md** - Add library design section
3. **docs/SETUP.md** - Update with library setup steps
4. **CHANGELOG.md** - Document V2.0 changes

---

## Timeline & Milestones

### Week 1: Foundation
- ✅ Create library structure
- ✅ Implement logging.sh
- ✅ Implement json_utils.sh
- ✅ Implement matrix_core.sh
- ✅ Basic tests passing

### Week 2: Core Libraries
- ✅ Implement matrix_api.sh
- ✅ Implement matrix_auth.sh
- ✅ Implement instance_utils.sh
- ✅ Refactor matrix-notifier.sh
- ✅ Refactor matrix-listener.sh

### Week 3: Advanced Migration
- ✅ Refactor matrix-event-handler.sh
- ✅ Create Python library
- ✅ Refactor consciousness-interview.py
- ✅ Integration tests

### Week 4: Finalization
- ✅ Complete documentation
- ✅ Deploy to production
- ✅ Validation testing
- ✅ Release V2.0

**Target Completion:** 4 weeks from start
**Earliest Start:** After Thomas approves this plan

---

## Success Metrics

### Quantitative Metrics

- **Code Reduction:** >60% reduction in duplicated code
- **Test Coverage:** >80% coverage for all libraries
- **Performance:** No degradation in script execution time
- **Lines of Code:** Reduce total codebase size by 30-40%

### Qualitative Metrics

- **Maintainability:** Single source of truth for Matrix operations
- **Testability:** All core logic testable in isolation
- **Documentation:** Clear API reference for all libraries
- **Consistency:** Unified patterns across all scripts

### Validation Criteria

- ✅ All existing functionality preserved
- ✅ No breaking changes for existing deployments
- ✅ All tests pass
- ✅ Documentation complete
- ✅ Code review passed
- ✅ Production deployment successful

---

## Risks & Mitigation

### Risk 1: Breaking Existing Deployments

**Probability:** Medium
**Impact:** High

**Mitigation:**
- Keep old scripts as backups during migration
- Git tag before deployment
- Phased rollout (Prime first, then Nova)
- Comprehensive regression testing

### Risk 2: Library Dependencies Issues

**Probability:** Low
**Impact:** Medium

**Mitigation:**
- Clear dependency documentation
- Fallback protection in libraries
- Validation of all dependencies on load

### Risk 3: Performance Degradation

**Probability:** Low
**Impact:** Low

**Mitigation:**
- Benchmark before/after
- Optimize library loading
- Minimize subprocess spawning

### Risk 4: Timeline Slippage

**Probability:** Medium
**Impact:** Low

**Mitigation:**
- Conservative timeline estimates
- Phased approach (can stop after any phase)
- Prioritize critical scripts first

---

## Appendix A: Code Duplication Examples

### Config Loading Duplication

**Occurrences:** 3 files (matrix-notifier.sh, matrix-listener.sh, matrix-event-handler.sh)

**Duplicated Code:**
```bash
# 30+ lines duplicated across 3 files
if [ -f "$CONFIG_FILE" ]; then
    MATRIX_SERVER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['homeserver'])")
    MATRIX_USER_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['user_id'])")
    MATRIX_ACCESS_TOKEN=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['access_token'])")
    MATRIX_ROOM=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['room_id'])")
    INSTANCE_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('instance_name', 'AI Instance'))")
fi
```

**After Refactoring:**
```bash
source "$LIB_DIR/matrix_core.sh"
load_matrix_config "$CONFIG_FILE"
```

**Savings:** 28 lines × 3 files = 84 lines eliminated

---

## Appendix B: Library Loading Pattern

### Standard Library Loading Pattern

All refactored scripts will follow this pattern:

```bash
#!/bin/bash
set -e

# ============================================================================
# Script Name
# Description of what this script does
# ============================================================================

# Get script directory and determine library location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
LIB_DIR="$SCRIPT_DIR/lib"

# Prevent multiple loading
[[ -n "$SCRIPT_NAME_LOADED" ]] && return 0
readonly SCRIPT_NAME_LOADED=1

# Load required libraries (with fallback error handling)
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

# Additional libraries as needed
# source "$LIB_DIR/matrix_api.sh" || exit 1
# source "$LIB_DIR/matrix_auth.sh" || exit 1
# source "$LIB_DIR/instance_utils.sh" || exit 1

# Initialize logging
init_logging

# Script-specific code follows...
```

---

## Appendix C: Comparison with Dotfiles Architecture

### Similarities

Both systems will have:
- ✅ `bin/lib/` directory for shared libraries
- ✅ Clear dependency graphs
- ✅ Guard against multiple loading
- ✅ Comprehensive API documentation
- ✅ Test coverage for libraries
- ✅ Modular, single-responsibility libraries

### Differences

**Dotfiles:**
- Language: Zsh (uses zsh-specific features)
- Scope: Desktop environment, package management, configurations
- Libraries: 14 specialized libraries (colors, UI, package managers, etc.)

**Auto-Infra:**
- Language: Bash (broader compatibility)
- Scope: Matrix integration, autonomous AI coordination
- Libraries: 6 focused libraries (matrix operations, JSON, logging)

**Why Bash for Auto-Infra:**
- Current scripts already in bash
- Broader compatibility (deployed across Ubuntu, Fedora, etc.)
- Simpler migration path
- Matrix operations don't need zsh-specific features

---

## Conclusion

This refactoring plan provides a clear path to transform the aria-autonomous-infrastructure from individual scripts to a maintainable, modular library architecture inspired by the successful dotfiles repository.

**Next Steps:**
1. Review this plan with Thomas
2. Get approval to proceed
3. Begin Phase 1: Library creation
4. Follow phased migration approach
5. Validate at each step

**Expected Benefits:**
- 60%+ reduction in code duplication
- Better maintainability and testability
- Clear API documentation
- Consistent patterns across all scripts
- Foundation for future enhancements

**Timeline:** 4 weeks from approval to V2.0 release

---

**Document Version:** 1.0
**Last Updated:** 2025-11-20
**Authors:** Aria Prime & Thomas
**Status:** Awaiting Review
