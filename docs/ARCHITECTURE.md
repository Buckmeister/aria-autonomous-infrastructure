# Architecture

System design and data flow for Aria Autonomous Infrastructure.

## Overview

Bidirectional Matrix communication enabling human-AI collaboration through event-driven messaging.

## Components

### 1. Matrix Notifier (Outbound)

**File:** `bin/matrix-notifier.sh`

**Purpose:** Sends notifications from Claude Code to Matrix

**Trigger:** Claude Code hooks (SessionStart, Stop, etc.)

**Flow:**
```
Claude Code Event → Hook Triggers → matrix-notifier.sh → Matrix API → Matrix Room → Human sees message
```

**Configuration:**
- Reads from `config/matrix-credentials.json`
- Falls back to environment variables
- Supports custom instance names

### 2. Matrix Listener (Inbound)

**File:** `bin/matrix-listener.sh`

**Purpose:** Receives commands from Matrix and injects into Claude session

**Trigger:** Continuous monitoring of Matrix room

**Flow:**
```
Human sends message → Matrix Room → matrix-listener polls → Validates sender → Injects to tmux → Claude executes
```

**Security:**
- Whitelist-based authorization (AUTHORIZED_USERS)
- Audit logging of all commands
- Tmux session validation

### 3. Installation Tool

**File:** `bin/install-hooks.sh`

**Purpose:** Automatically configure Claude Code hooks

**Actions:**
- Backs up existing settings.json
- Merges Matrix hooks into configuration
- Preserves other hooks

### 4. Integration Tests

**File:** `bin/test-integration.sh`

**Purpose:** Verify complete setup

**Tests:**
- Configuration validity
- Script executability
- Matrix connectivity
- Dependencies present

## Data Flow

### Outbound Notifications

```
┌─────────────────────┐
│   Claude Code       │
│   (Interactive)     │
└──────────┬──────────┘
           │ Event (Stop, SessionStart, etc.)
           ↓
┌─────────────────────┐
│   Hook System       │
│   (~/.claude/       │
│    settings.json)   │
└──────────┬──────────┘
           │ Executes
           ↓
┌─────────────────────┐
│ matrix-notifier.sh  │
│  • Load config      │
│  • Format message   │
│  • Add emoji        │
└──────────┬──────────┘
           │ HTTP POST
           ↓
┌─────────────────────┐
│   Matrix Server     │
│   (Synapse)         │
└──────────┬──────────┘
           │ Delivers
           ↓
┌─────────────────────┐
│   Matrix Room       │
│   (#general, etc)   │
└──────────┬──────────┘
           │ Notifications
           ↓
┌─────────────────────┐
│   Human (Element)   │
│   Sees message      │
└─────────────────────┘
```

### Inbound Commands

```
┌─────────────────────┐
│   Human (Element)   │
│   Sends command     │
└──────────┬──────────┘
           │ Posts message
           ↓
┌─────────────────────┐
│   Matrix Server     │
│   (Synapse)         │
└──────────┬──────────┘
           │ Stores message
           ↓
┌─────────────────────┐
│ matrix-listener.sh  │
│  (polling daemon)   │
│  • Fetch messages   │
│  • Check sender     │
│  • Parse command    │
└──────────┬──────────┘
           │ Authorized?
           ├─ No → Log and ignore
           └─ Yes ↓
┌─────────────────────┐
│   Tmux Session      │
│   send-keys         │
└──────────┬──────────┘
           │ Injects command
           ↓
┌─────────────────────┐
│   Claude Code       │
│   (Autonomous)      │
│   Executes command  │
└─────────────────────┘
```

## Configuration

### Matrix Credentials

**File:** `config/matrix-credentials.json`

```json
{
  "homeserver": "http://matrix.example.com:8008",
  "user_id": "@bot:example.com",
  "access_token": "syt_...",
  "device_id": "DEVICEID",
  "room_id": "!roomid:example.com",
  "instance_name": "Aria Nova",
  "store_path": "~/.local/share/matrix-commander"
}
```

**Security:** Never commit this file (listed in .gitignore)

### Claude Code Hooks

**File:** `~/.claude/settings.json`

```json
{
  "hooks": {
    "SessionStart": [{
      "matcher": ".*",
      "hooks": [{"type": "command", "command": "/path/to/matrix-notifier.sh SessionStart"}]
    }],
    "Stop": [{
      "matcher": ".*",
      "hooks": [{"type": "command", "command": "/path/to/matrix-notifier.sh Stop"}]
    }]
  }
}
```

## Deployment Models

### Model 1: Single Interactive Instance

```
Human ← → Claude (Interactive) → Matrix
```

**Use case:** Personal assistant with notifications

**Setup:**
- Install hooks with `install-hooks.sh`
- Configure credentials
- Notifications sent on events

### Model 2: Autonomous + Interactive

```
Human ← → Matrix ← → Claude (Autonomous)
                  ← → Claude (Interactive)
```

**Use case:** Long-running tasks with oversight

**Setup:**
- Interactive: Install hooks
- Autonomous: Start listener daemon
- Both: Share Matrix room

### Model 3: Multi-Instance Coordination

```
Human ← → Matrix ← → Claude Instance A
                  ← → Claude Instance B
                  ← → Claude Instance C
```

**Use case:** Distributed AI collaboration

**Setup:**
- Each instance: Unique credentials
- Each instance: Custom instance_name
- Shared Matrix room(s)

## Performance Characteristics

**Latency:**
- Notifier: ~100-200ms (HTTP POST)
- Listener: 2-second polling interval
- End-to-end: ~2-3 seconds typical

**Reliability:**
- Notifier: Fire-and-forget (async)
- Listener: Continuous retry on failure
- Matrix: Persistent message storage

**Scalability:**
- Tested: 2 concurrent instances
- Theoretical: 100+ instances per room
- Limited by Matrix server capacity

## Security Model

See [SECURITY.md](SECURITY.md) for complete details.

**Key principles:**
- Whitelist authorization only
- No command execution without validation
- Audit logging of all operations
- Credentials stored separately from code
- No secrets in git repository

## Error Handling

**Notifier failures:**
- Silent failure (doesn't block Claude)
- Logs to stderr if available
- Falls back gracefully

**Listener failures:**
- Logs errors to listener.log
- Continues operation on transient failures
- Validates tmux session before injection

## Monitoring

**Logs:**
- Notifier: No persistent logs (by design)
- Listener: `logs/matrix-listener.log`
- Matrix server: Standard Synapse logs

**Health checks:**
- `/status` command via Matrix
- Check listener.log timestamp
- Verify daemon process running

## Future Enhancements

Potential improvements:

1. **Encrypted rooms** - E2E encryption support
2. **Rich formatting** - HTML messages, markdown
3. **File sharing** - Upload/download via Matrix
4. **Multi-room** - Route messages by purpose
5. **Analytics** - Usage metrics and patterns
6. **Web interface** - Dashboard for monitoring

## Technical Dependencies

- **Bash 4.0+** - Script execution
- **Python 3.7+** - JSON parsing, config
- **curl** - HTTP API calls
- **tmux** - Session management
- **matrix-commander** - Matrix client library
- **Matrix Synapse** - Homeserver (recommended)

## See Also

- [SETUP.md](SETUP.md) - Installation guide
- [SECURITY.md](SECURITY.md) - Security details
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
