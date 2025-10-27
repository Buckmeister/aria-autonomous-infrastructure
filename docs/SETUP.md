# Setup Guide

Complete installation guide for Aria Autonomous Infrastructure.

## Prerequisites

- **Matrix Homeserver** (Synapse 1.50+ recommended)
- **Claude Code CLI** installed and configured
- **tmux** for session management
- **Python 3.7+** with pip
- **matrix-commander** installed
- **bash 4.0+**

## Quick Setup

### 1. Install matrix-commander

```bash
pip3 install matrix-commander
```

### 2. Configure Matrix Credentials

```bash
# Copy example config
cp config/matrix-credentials.example.json config/matrix-credentials.json

# Edit with your actual credentials
nano config/matrix-credentials.json
```

Required fields:
- `homeserver`: Your Matrix server URL
- `user_id`: Your bot user ID (e.g., `@bot:server.local`)
- `access_token`: Bot access token
- `room_id`: Target Matrix room ID
- `instance_name`: Display name for this instance

### 3. Install Hook Integration

For interactive Claude instance (e.g., Aria Prime):

```bash
# Add to ~/.claude/settings.json
{
  "hooks": {
    "SessionStart": [{
      "matcher": ".*",
      "hooks": [{"type": "command", "command": "/path/to/bin/matrix-notifier.sh SessionStart"}]
    }],
    "Stop": [{
      "matcher": ".*",
      "hooks": [{"type": "command", "command": "/path/to/bin/matrix-notifier.sh Stop"}]
    }]
  }
}
```

### 4. Start Listener (Autonomous Instance)

On autonomous machine:

```bash
# Start tmux session for Claude
tmux new-session -s claude-autonomous -d

# Start listener daemon
./bin/matrix-listener.sh --daemon

# Verify running
tail -f logs/matrix-listener.log
```

### 5. Test Integration

```bash
# Send test notification
./bin/matrix-notifier.sh Notification "Test message"

# Check Matrix room for message
```

## Configuration

### Environment Variables

Override config file with environment variables:

```bash
export MATRIX_SERVER="http://matrix.example.com:8008"
export MATRIX_INSTANCE_NAME="My AI Instance"
export TMUX_SESSION="my-session-name"
```

### Security

**Important:** The `matrix-listener.sh` only accepts commands from authorized users.

Edit `AUTHORIZED_USERS` in the script or set via environment:

```bash
export AUTHORIZED_USERS="@thomas,@admin"
```

## Troubleshooting

### Notifications not appearing

1. Check Matrix credentials in config file
2. Verify room ID is correct
3. Test with: `curl -X GET "http://homeserver:8008/_matrix/client/r0/rooms/ROOM_ID/messages"`

### Listener not injecting commands

1. Verify tmux session exists: `tmux list-sessions`
2. Check listener is running: `ps aux | grep matrix-listener`
3. Review logs: `tail -f logs/matrix-listener.log`
4. Ensure sender is in `AUTHORIZED_USERS`

### Permission denied on scripts

```bash
chmod +x bin/*.sh
```

## Advanced Configuration

See additional documentation:
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design
- [SECURITY.md](SECURITY.md) - Security best practices
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues

## Support

- GitHub Issues: https://github.com/Buckmeister/aria-autonomous-infrastructure/issues
- Matrix: #aria-infrastructure:srv1.local
