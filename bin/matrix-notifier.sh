#!/bin/bash
# Matrix Notifier for Claude Code Hooks
# Sends notifications to Matrix when Claude Code events occur
#
# Usage: matrix-notifier.sh <event-type> [message]
#
# Configuration:
#   Set environment variables or edit config/matrix-credentials.json
#
# Integration with Claude Code hooks in ~/.claude/settings.json:
# {
#   "hooks": {
#     "Stop": { "command": "~/path/to/matrix-notifier.sh Stop" },
#     "SessionStart": { "command": "~/path/to/matrix-notifier.sh SessionStart" }
#   }
# }

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config/matrix-credentials.json}"

# Parse command line
EVENT_TYPE="${1:-Unknown}"
MESSAGE_TEXT="${2:-}"

# Load configuration from environment or config file
if [ -f "$CONFIG_FILE" ]; then
    MATRIX_SERVER=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['homeserver'])" 2>/dev/null || echo "")
    MATRIX_USER_ID=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['user_id'])" 2>/dev/null || echo "")
    MATRIX_ACCESS_TOKEN=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['access_token'])" 2>/dev/null || echo "")
    MATRIX_ROOM=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['room_id'])" 2>/dev/null || echo "")
    INSTANCE_NAME=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE')).get('instance_name', 'AI Instance'))" 2>/dev/null || echo "AI Instance")
fi

# Override with environment variables if set
MATRIX_SERVER="${MATRIX_SERVER:-http://localhost:8008}"
MATRIX_USER_ID="${MATRIX_USER_ID:-@bot:server.local}"
MATRIX_ACCESS_TOKEN="${MATRIX_ACCESS_TOKEN:-}"
MATRIX_ROOM="${MATRIX_ROOM:-!room:server.local}"
INSTANCE_NAME="${MATRIX_INSTANCE_NAME:-${INSTANCE_NAME:-AI Instance}}"

# Build message based on event type
case "$EVENT_TYPE" in
    SessionStart)
        EMOJI="🚀"
        MSG="[$INSTANCE_NAME] Session started"
        ;;
    SessionEnd)
        EMOJI="👋"
        MSG="[$INSTANCE_NAME] Session ended"
        ;;
    Stop)
        EMOJI="✅"
        MSG="[$INSTANCE_NAME] Task completed"
        if [ -n "$MESSAGE_TEXT" ]; then
            MSG="$MSG: $MESSAGE_TEXT"
        fi
        ;;
    SubagentStop)
        EMOJI="🤖"
        MSG="[$INSTANCE_NAME] Agent task completed"
        if [ -n "$MESSAGE_TEXT" ]; then
            MSG="$MSG: $MESSAGE_TEXT"
        fi
        ;;
    Notification)
        EMOJI="📢"
        MSG="[$INSTANCE_NAME] $MESSAGE_TEXT"
        ;;
    Error)
        EMOJI="❌"
        MSG="[$INSTANCE_NAME] Error: $MESSAGE_TEXT"
        ;;
    *)
        EMOJI="ℹ️"
        MSG="[$INSTANCE_NAME] $EVENT_TYPE: $MESSAGE_TEXT"
        ;;
esac

# Full message with emoji
FULL_MSG="$EMOJI $MSG"

# Send to Matrix using direct API call
# Use jq for proper JSON encoding (handles newlines, quotes, special chars)
if [ -n "$MATRIX_ACCESS_TOKEN" ]; then
    # Build JSON payload with proper escaping
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
fi

exit 0
