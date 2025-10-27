#!/bin/bash
# Install Claude Code Hooks for Matrix Integration
# Automatically configures ~/.claude/settings.json with Matrix notifier hooks

set -e

# Get script directory (absolute path to repo)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
SETTINGS_FILE="$HOME/.claude/settings.json"

echo "🔧 Installing Claude Code Matrix Integration Hooks"
echo ""

# Check if settings file exists
if [ ! -f "$SETTINGS_FILE" ]; then
    echo "Creating new settings file: $SETTINGS_FILE"
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    echo '{"hooks": {}}' > "$SETTINGS_FILE"
fi

# Backup existing settings
BACKUP_FILE="$SETTINGS_FILE.backup.$(date +%Y%m%d-%H%M%S)"
cp "$SETTINGS_FILE" "$BACKUP_FILE"
echo "✅ Backed up settings to: $BACKUP_FILE"
echo ""

# Path to notifier script
NOTIFIER_PATH="$REPO_ROOT/bin/matrix-notifier.sh"

# Use Python to merge hooks into settings.json
python3 << PYTHON_EOF
import json
import os

settings_file = "$SETTINGS_FILE"
notifier_path = "$NOTIFIER_PATH"

# Load existing settings
with open(settings_file, 'r') as f:
    settings = json.load(f)

# Ensure hooks section exists
if 'hooks' not in settings:
    settings['hooks'] = {}

# Define hook configurations
hook_configs = {
    "SessionStart": {
        "matcher": ".*",
        "hooks": [
            {
                "type": "command",
                "command": f"{notifier_path} SessionStart"
            }
        ]
    },
    "SessionEnd": {
        "matcher": ".*",
        "hooks": [
            {
                "type": "command",
                "command": f"{notifier_path} SessionEnd"
            }
        ]
    },
    "Stop": {
        "matcher": ".*",
        "hooks": [
            {
                "type": "command",
                "command": f"{notifier_path} Stop"
            }
        ]
    },
    "Notification": {
        "matcher": ".*",
        "hooks": [
            {
                "type": "command",
                "command": f"{notifier_path} Notification"
            }
        ]
    }
}

# Merge or update hooks
for hook_name, hook_config in hook_configs.items():
    if hook_name not in settings['hooks']:
        settings['hooks'][hook_name] = []

    # Check if our hook already exists
    existing = False
    for i, existing_hook in enumerate(settings['hooks'][hook_name]):
        if existing_hook.get('matcher') == '.*':
            # Update existing hook
            for hook in existing_hook.get('hooks', []):
                if 'matrix-notifier.sh' in hook.get('command', ''):
                    hook['command'] = hook_config['hooks'][0]['command']
                    existing = True
                    break

    if not existing:
        settings['hooks'][hook_name].append(hook_config)

# Write updated settings
with open(settings_file, 'w') as f:
    json.dump(settings, f, indent=2)

print(f"✅ Installed Matrix hooks for:")
for hook_name in hook_configs.keys():
    print(f"   • {hook_name}")
PYTHON_EOF

echo ""
echo "✅ Installation complete!"
echo ""
echo "Hooks configured:"
echo "  • SessionStart - Notifies when Claude Code starts"
echo "  • SessionEnd   - Notifies when session ends"
echo "  • Stop         - Notifies when tasks complete"
echo "  • Notification - Sends custom notifications"
echo ""
echo "Next steps:"
echo "  1. Configure Matrix credentials: cp config/matrix-credentials.example.json config/matrix-credentials.json"
echo "  2. Edit config/matrix-credentials.json with your Matrix details"
echo "  3. Test: $REPO_ROOT/bin/test-integration.sh"
echo ""
echo "To restore previous settings: cp $BACKUP_FILE $SETTINGS_FILE"
