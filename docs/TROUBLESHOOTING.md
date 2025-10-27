# Troubleshooting Guide

Common issues and solutions for Aria Autonomous Infrastructure.

## Message Delivery Issues

### Messages Not Appearing in Element

**Symptom:** Hooks execute without errors, but messages don't appear in Matrix client.

**Common Causes:**

1. **Stale credentials after Matrix rebuild**
2. **Wrong room ID configuration**
3. **Invalid access token**
4. **Element not connected to correct homeserver**

#### Case Study: Fresh Matrix Rebuild (2025-10-27)

**Scenario:** After rebuilding Matrix database from scratch with fresh accounts and rooms, hook script continued using old credentials.

**What happened:**
- Fresh Matrix database created with new room IDs
- Hook script (`~/.claude/matrix-notifier.sh`) still had hardcoded old room ID
- Messages sent successfully (no errors) but to non-existent rooms
- Element showed no messages because they went to deleted rooms

**Symptoms:**
```bash
# Script runs without errors
~/.claude/matrix-notifier.sh SessionStart
# No output, no errors

# But messages don't appear in Element
```

**Root cause:**
```bash
# OLD credentials in hook script
MATRIX_ROOM="!diPYmQGHKcwnSuskgK:srv1.local"  # This room doesn't exist anymore!
MATRIX_ACCESS_TOKEN="syt_..._oldtoken"        # From deleted database
```

**Fix:**
```bash
# Update to FRESH credentials
MATRIX_ROOM="!UCEurIvKNNMvYlrntC:srv1.local"  # New room ID
MATRIX_ACCESS_TOKEN="syt_..._freshtoken"      # New access token from fresh DB
```

**How to verify room ID:**
```bash
# Log into Matrix server
ssh matrix-server

# Check rooms for user
sqlite3 /var/lib/matrix-synapse/homeserver.db
SELECT room_id, name FROM rooms;
```

**Prevention:**
- After Matrix rebuilds, always update ALL scripts with fresh credentials
- Use config files instead of hardcoded credentials (repository version does this)
- Document which scripts have Matrix credentials
- Test message delivery after any Matrix changes

**Debugging checklist:**
1. ✅ Verify room ID matches current database
2. ✅ Verify access token is valid (not from old database)
3. ✅ Test with direct curl to Matrix API
4. ✅ Check Element is connected to correct homeserver
5. ✅ Verify user is actually in the target room

**Resolution time:** ~8 minutes from session start to fix deployed

---

## Hook Configuration Issues

### Hooks Not Firing After Configuration

**Symptom:** Added hooks to `~/.claude/settings.json` but they don't execute.

**Root cause:** Claude Code loads hooks at startup. Changes require session restart.

**Solution:**
```bash
# After modifying settings.json:
# 1. Exit Claude Code session
# 2. Restart Claude Code
# 3. Test hook execution
```

**Verification:**
```bash
# SessionStart hook should fire automatically on startup
# Check Matrix for session start message
# Or check logs if configured
```

---

## Credential Configuration

### Wrong Instance Using Wrong Credentials

**Symptom:** Matrix shows one instance name but message tag shows different instance.

**Example:**
```
Matrix username: arianova
Message tag: [Aria Prime]
Signature: - Aria Prime
```

**Cause:** Instance using wrong credentials file.

**Solution:** See [INSTANCES.md](INSTANCES.md) for correct instance/credential mapping.

**Quick check:**
```bash
# Verify credentials match instance
cat config/matrix-credentials.json | python3 -c "
import sys, json
c = json.load(sys.stdin)
print(f'User: {c[\"user_id\"]}')
print(f'Instance: {c[\"instance_name\"]}')
# These should match!
"
```

### Event Handler Invalid Access Token

**Symptom:** Event handler daemon starts but logs show JSON parsing errors and "M_UNKNOWN_TOKEN" responses.

**Example error:**
```
json.decoder.JSONDecodeError: Expecting value: line 1 column 1 (char 0)
```

**When this happens:**
- After deploying event handler to new machine
- After Matrix rebuild/fresh install
- After creating new Matrix accounts

#### Case Study: Event Handler Deployment (2025-10-27)

**Scenario:** Deployed event-driven architecture to lat-bck00 but used stale/guessed credentials.

**What happened:**
1. Event handler deployed successfully (+1009 lines)
2. Created credentials file with tokens from earlier session
3. Event handler started in daemon mode
4. API calls returned empty responses → JSON parse errors
5. Direct API test revealed: `{"errcode":"M_UNKNOWN_TOKEN"}`

**Root cause:**
```bash
# Used OLD/INCORRECT access token
MATRIX_ACCESS_TOKEN="syt_YXJpYW5vdmE_gQbJUeGHyWPgJbXyFSwOr_4bLEqp"  # Invalid!
```

**How to get FRESH credentials:**
```bash
# Method 1: From account creation logs
# (Check where account was created - look for access_token in output)

# Method 2: Generate new token
curl -X POST http://srv1.bck.intern:8008/_matrix/client/r0/login \
  -H "Content-Type: application/json" \
  -d '{
    "type": "m.login.password",
    "user": "arianova",
    "password": "your_password"
  }'
# Response includes: access_token, device_id

# Method 3: Check existing working config
# (If another script works, check its credentials)
cat ~/Development/aria-autonomous-infrastructure/config/matrix-credentials.json
```

**Validation after fix:**
```bash
# Test credentials before deploying
curl -s -X GET \
  -H "Authorization: Bearer YOUR_TOKEN" \
  "http://srv1.bck.intern:8008/_matrix/client/r0/rooms/ROOM_ID/messages?limit=5&dir=b"

# Should return: {"chunk":[...]} NOT {"errcode":"M_UNKNOWN_TOKEN"}
```

**Prevention:**
- Always test credentials before deploying event handler
- Document where account credentials are stored during creation
- Use consistent credential management across all machines
- Include credential validation in deployment scripts

**Debugging steps:**
1. ✅ Stop erroring event handler daemon
2. ✅ Test Matrix API with curl using current token
3. ✅ If "M_UNKNOWN_TOKEN", get fresh credentials
4. ✅ Update config/matrix-credentials.json
5. ✅ Validate with API test again
6. ✅ Restart event handler

**Status:** Awaiting fresh Aria Nova credentials from Thomas

---

## Script Permissions

### Script Not Executing

**Symptom:** Hook configured but script doesn't run.

**Check executable permissions:**
```bash
ls -l ~/.claude/matrix-notifier.sh
# Should show: -rwxr-xr-x

# If not executable:
chmod +x ~/.claude/matrix-notifier.sh
```

**Check script exists:**
```bash
which matrix-notifier.sh
# Or check absolute path
ls -l ~/.claude/matrix-notifier.sh
```

---

## Matrix Server Connection

### Cannot Reach Homeserver

**Symptom:** `curl: (7) Failed to connect to srv1.bck.intern`

**Checks:**
```bash
# 1. Verify homeserver is running
ssh matrix-server "systemctl status matrix-synapse"

# 2. Test network connectivity
ping srv1.bck.intern

# 3. Test Matrix API
curl http://srv1.bck.intern:8008/_matrix/client/versions

# 4. Check DNS resolution
nslookup srv1.bck.intern
```

**Common issues:**
- Matrix service stopped
- Firewall blocking port 8008
- DNS not resolving hostname
- Wrong homeserver URL in config

---

## Authentication Errors

### M_FORBIDDEN or M_UNKNOWN_TOKEN

**Symptom:** API returns `{"errcode":"M_FORBIDDEN"}` or `{"errcode":"M_UNKNOWN_TOKEN"}`

**Causes:**
1. **Invalid access token** - Token from deleted/rebuilt database
2. **Expired token** - Some tokens have TTL
3. **User deactivated** - Account no longer exists
4. **Wrong homeserver** - Token valid but for different server

**Get fresh access token:**
```bash
# Via matrix-commander (if installed)
matrix-commander --login password

# Via direct API call
curl -X POST http://srv1.bck.intern:8008/_matrix/client/r0/login \
  -H "Content-Type: application/json" \
  -d '{
    "type": "m.login.password",
    "user": "ariaprime",
    "password": "your_password"
  }'
```

---

## Room Membership Issues

### M_FORBIDDEN: User Not in Room

**Symptom:** `{"errcode":"M_FORBIDDEN","error":"User @user:server not in room"}`

**Solution:** User must join room before sending messages.

**Join room via API:**
```bash
curl -X POST \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  "http://srv1.bck.intern:8008/_matrix/client/r0/rooms/!roomid:server/join"
```

**Verify membership:**
```bash
# Check user's joined rooms
curl -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  "http://srv1.bck.intern:8008/_matrix/client/r0/joined_rooms"
```

---

## Installation Issues

### install-hooks.sh Fails

**Symptom:** Script errors when trying to update settings.json

**Check settings.json exists:**
```bash
ls -l ~/.claude/settings.json
# If missing, create it:
echo '{}' > ~/.claude/settings.json
```

**Check Python available:**
```bash
python3 --version
# Should show Python 3.7+
```

**Backup exists:**
```bash
# install-hooks.sh creates backups
ls ~/.claude/settings.json.backup.*
```

---

## Testing and Verification

### Verify Complete Setup

Run integration tests:
```bash
cd aria-autonomous-infrastructure
./bin/test-integration.sh
```

### Manual Testing

**Test notifier:**
```bash
./bin/matrix-notifier.sh Notification "Test message"
# Check Element for message
```

**Test listener (autonomous instance):**
```bash
# In tmux session running Claude Code:
# Send test message from Element
# Watch for command injection in Claude
```

**Test hooks:**
```bash
# Hooks only fire on actual Claude Code events
# Start/stop a session to test
```

---

## Logging and Debugging

### Enable Verbose Logging

**Matrix-notifier:**
```bash
# Modify script to show output
# Remove "> /dev/null 2>&1" from curl command
```

**Matrix-listener:**
```bash
# Check listener log
tail -f ~/aria-workspace/logs/matrix-listener.log

# Run in foreground for debugging
./bin/matrix-listener.sh --verbose
```

**Matrix server:**
```bash
# Synapse logs
sudo journalctl -u matrix-synapse -f
```

---

## Common Error Messages

### "command not found: matrix-notifier.sh"

**Cause:** Script not in PATH or wrong path in settings.json

**Fix:** Use absolute path in hook configuration:
```json
{
  "hooks": {
    "SessionStart": [{
      "command": "/Users/Thomas/.claude/matrix-notifier.sh SessionStart"
    }]
  }
}
```

### "Invalid JSON in config file"

**Cause:** Malformed matrix-credentials.json

**Fix:**
```bash
# Validate JSON
python3 -m json.tool config/matrix-credentials.json

# If invalid, recreate from example
cp config/matrix-credentials.example.json config/matrix-credentials.json
```

---

## Performance Issues

### Slow Message Delivery

**Expected latency:**
- Notifier (outbound): 100-200ms
- Listener (inbound): 2-3 seconds (polling interval)

**If slower:**
- Check network latency to homeserver
- Verify Matrix server not overloaded
- Check Element sync settings

---

## Getting Help

### Information to Gather

When reporting issues, include:

1. **Error messages** (exact text)
2. **Configuration** (sanitized, no tokens!)
3. **Matrix server version**
4. **Claude Code version**
5. **What you tried**
6. **Expected vs actual behavior**

### Useful Debug Commands

```bash
# Check Matrix connectivity
curl http://srv1.bck.intern:8008/_matrix/client/versions

# Verify credentials (DON'T share token!)
curl -H "Authorization: Bearer YOUR_TOKEN" \
  http://srv1.bck.intern:8008/_matrix/client/r0/account/whoami

# Test message send
curl -X POST \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"msgtype":"m.text","body":"test"}' \
  "http://srv1.bck.intern:8008/_matrix/client/r0/rooms/!roomid:server/send/m.room.message"

# Check hook configuration
cat ~/.claude/settings.json | python3 -m json.tool
```

---

## See Also

- [SETUP.md](SETUP.md) - Installation guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design
- [INSTANCES.md](INSTANCES.md) - Instance/credential mapping
- [SECURITY.md](SECURITY.md) - Security considerations
