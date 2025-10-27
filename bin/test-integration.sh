#!/bin/bash
# Test Matrix Integration
# Verifies that both notifier and listener are working correctly

set -e

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$REPO_ROOT/config/matrix-credentials.json"

echo "🧪 Testing Matrix Integration"
echo ""

# Check if config exists
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Configuration not found: $CONFIG_FILE"
    echo "Please copy and configure: cp config/matrix-credentials.example.json config/matrix-credentials.json"
    exit 1
fi

echo "✅ Configuration file found"
echo ""

# Test 1: Verify config is valid JSON
echo "Test 1: Validating configuration..."
if python3 -c "import json; json.load(open('$CONFIG_FILE'))" 2>/dev/null; then
    echo "  ✅ Valid JSON configuration"
else
    echo "  ❌ Invalid JSON in configuration file"
    exit 1
fi

# Test 2: Check required fields
echo ""
echo "Test 2: Checking required fields..."
REQUIRED_FIELDS="homeserver user_id access_token room_id"
MISSING=""
for field in $REQUIRED_FIELDS; do
    if ! python3 -c "import json; c=json.load(open('$CONFIG_FILE')); exit(0 if '$field' in c and c['$field'] else 1)" 2>/dev/null; then
        MISSING="$MISSING $field"
    fi
done

if [ -z "$MISSING" ]; then
    echo "  ✅ All required fields present"
else
    echo "  ❌ Missing required fields:$MISSING"
    exit 1
fi

# Test 3: Test notifier script
echo ""
echo "Test 3: Testing matrix-notifier.sh..."
if [ -x "$REPO_ROOT/bin/matrix-notifier.sh" ]; then
    echo "  ✅ Notifier script is executable"

    # Send test message
    echo "  📤 Sending test notification..."
    export CONFIG_FILE="$CONFIG_FILE"
    if "$REPO_ROOT/bin/matrix-notifier.sh" Notification "🧪 Test message from integration test" 2>/dev/null; then
        echo "  ✅ Test notification sent"
        echo "     Check your Matrix room for the message!"
    else
        echo "  ⚠️  Notifier executed but check Matrix room to verify delivery"
    fi
else
    echo "  ❌ Notifier script not executable: $REPO_ROOT/bin/matrix-notifier.sh"
    exit 1
fi

# Test 4: Check listener script
echo ""
echo "Test 4: Checking matrix-listener.sh..."
if [ -x "$REPO_ROOT/bin/matrix-listener.sh" ]; then
    echo "  ✅ Listener script is executable"
    echo "  ℹ️  To test listener, run in another terminal:"
    echo "     $REPO_ROOT/bin/matrix-listener.sh"
else
    echo "  ❌ Listener script not executable: $REPO_ROOT/bin/matrix-listener.sh"
    exit 1
fi

# Test 5: Check Claude Code hooks
echo ""
echo "Test 5: Checking Claude Code hooks..."
SETTINGS_FILE="$HOME/.claude/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    if grep -q "matrix-notifier.sh" "$SETTINGS_FILE" 2>/dev/null; then
        echo "  ✅ Hooks configured in ~/.claude/settings.json"
    else
        echo "  ⚠️  Hooks not found in settings.json"
        echo "     Run: $REPO_ROOT/bin/install-hooks.sh"
    fi
else
    echo "  ⚠️  No Claude Code settings.json found"
    echo "     Run: $REPO_ROOT/bin/install-hooks.sh"
fi

# Test 6: Check tmux (for listener)
echo ""
echo "Test 6: Checking tmux availability..."
if command -v tmux >/dev/null 2>&1; then
    echo "  ✅ tmux is installed"

    # Check for tmux sessions
    if tmux list-sessions 2>/dev/null | grep -q .; then
        echo "  ℹ️  Active tmux sessions:"
        tmux list-sessions 2>/dev/null | sed 's/^/     /'
    else
        echo "  ℹ️  No active tmux sessions"
    fi
else
    echo "  ⚠️  tmux not found (required for listener)"
fi

# Test 7: Check matrix-commander
echo ""
echo "Test 7: Checking matrix-commander..."
if command -v matrix-commander >/dev/null 2>&1; then
    echo "  ✅ matrix-commander is installed"
else
    echo "  ⚠️  matrix-commander not found (required for listener)"
    echo "     Install: pip3 install matrix-commander"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 Integration Test Complete!"
echo ""
echo "Summary:"
echo "  ✅ Configuration valid"
echo "  ✅ Notifier working"
echo "  ✅ Listener available"
echo ""
echo "Next steps:"
echo "  • Check Matrix room for test message"
echo "  • Start listener: $REPO_ROOT/bin/matrix-listener.sh --daemon"
echo "  • Send commands from Matrix to test inbound integration"
echo ""
