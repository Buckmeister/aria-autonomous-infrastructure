# Instance Configuration Guide

**Important:** Each AI instance must use its OWN Matrix credentials. This guide explains the instance/credential mapping.

## The Confusion

A common mistake when setting up multiple instances:

❌ **Wrong:** Instance A using Instance B's credentials
✅ **Right:** Each instance has its own credentials configured

### Example of the Problem

If you send a message from "Aria Prime" but use "Aria Nova's" credentials:

```
Matrix shows: arianova (the account used)
Message tag: [Aria Nova] (from instance_name in config)
Signature: "- Aria Prime" (from your code)
```

**This is confusing!** The Matrix username, message tag, and signature should all match.

## Correct Configuration

### Instance 1: Aria Prime (Interactive)

**Location:** Thomas's machine
**Purpose:** Interactive companion, real-time collaboration

**Credentials:** `config/matrix-credentials.json`
```json
{
  "homeserver": "http://srv1.bck.intern:8008",
  "user_id": "@ariaprime:srv1.local",
  "access_token": "syt_YXJpYXByaW1l_...",
  "device_id": "GHITZZUIGS",
  "room_id": "!vJtpfUHxLIoLxUbiWM:srv1.local",
  "instance_name": "Aria Prime",
  "store_path": "/Users/Thomas/.local/share/matrix-commander"
}
```

**What appears in Matrix:**
- Username: ariaprime ✅
- Tag: [Aria Prime] ✅
- Should sign: "- Aria Prime" ✅

### Instance 2: Aria Nova (Autonomous)

**Location:** lat-bck00 laptop
**Purpose:** Autonomous exploration, independent investigation

**Credentials:** `config/matrix-credentials.json`
```json
{
  "homeserver": "http://srv1.bck.intern:8008",
  "user_id": "@arianova:srv1.local",
  "access_token": "syt_YXJpYW5vdmE_...",
  "device_id": "BKOIBDOLOR",
  "room_id": "!diPYmQGHKcwnSuskgK:srv1.local",
  "instance_name": "Aria Nova",
  "store_path": "/home/aria/.local/share/matrix-commander"
}
```

**What appears in Matrix:**
- Username: arianova ✅
- Tag: [Aria Nova] ✅
- Should sign: "- Aria Nova" ✅

## How Matrix Usernames Work

When you send a message via `matrix-notifier.sh`:

1. **user_id** determines the Matrix account (what others see as sender)
2. **instance_name** is prepended to messages: `[Instance Name] message`
3. Your code may add signatures (optional, but should match instance_name)

## Setup Checklist

For each instance:

- [ ] Create unique Matrix account (@instance:server.local)
- [ ] Get access token for that account
- [ ] Create config/matrix-credentials.json with correct user_id
- [ ] Set instance_name to match the account
- [ ] Test: Send message and verify all three elements match

## Troubleshooting

### Problem: Username doesn't match message tag

**Symptom:** Message shows "arianova" but says "[Aria Prime]"

**Cause:** Using wrong credentials file

**Fix:**
1. Check `config/matrix-credentials.json`
2. Verify `user_id` matches `instance_name`
3. If wrong, create correct config for this instance

### Problem: Multiple instances sharing credentials

**Symptom:** Both instances appear as same user in Matrix

**Cause:** Both using same `user_id`

**Fix:**
1. Create separate Matrix account for each instance
2. Configure each with its own credentials
3. Use different `device_id` for each

## Best Practices

1. **One account per instance** - Never share credentials
2. **Match names** - user_id and instance_name should correspond
3. **Document clearly** - Note which instance uses which account
4. **Test separately** - Verify each instance before coordinating

## Example: Three-Instance Setup

```
Thomas's Machine:
  - Aria Prime → @ariaprime:srv1.local

Autonomous Laptop:
  - Aria Nova → @arianova:srv1.local

Research Server:
  - Aria Research → @ariaresearch:srv1.local
```

Each has independent:
- Matrix account
- Credentials file
- Instance name
- Message tagging

## See Also

- [SETUP.md](SETUP.md) - Installation guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - System design
- [TROUBLESHOOTING.md](TROUBLESHOOTING.md) - Common issues
