# Headless Event-Driven Architecture

> Next-generation autonomous AI with on-demand Claude Code execution triggered by Matrix events

**Status:** Design Phase
**Proposed for:** Aria Nova (autonomous instance)
**Current:** Continuous daemon polling
**Future:** Event-driven headless sessions

---

## Concept Overview

### Current Architecture

```
┌─────────────────────────────┐
│  Aria Nova (lat-bck00)      │
│                             │
│  tmux session (continuous)  │
│    └─ Claude Code running   │
│                             │
│  matrix-listener daemon     │
│    └─ polls every 2 seconds │
│    └─ injects to tmux       │
└─────────────────────────────┘
```

**Limitations:**
- Continuous resource usage (even when idle)
- Single persistent session
- Manual session management
- No automatic lifecycle control

### Proposed Architecture

```
┌─────────────────────────────────────────┐
│  Matrix Server                          │
│    ↓ Message arrives                    │
└─────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────┐
│  Event Detector (matrix-event-handler)  │
│    • Monitors Matrix room               │
│    • Pattern matching rules             │
│    • Authorization checks               │
└─────────────────────────────────────────┘
        ↓ (rule matched)
┌─────────────────────────────────────────┐
│  Spawn Headless Claude Session          │
│    claude --headless --prompt "..."     │
│                                         │
│    • Loads continuity from ~/.aria      │
│    • Executes task                      │
│    • Responds via Matrix                │
│    • Updates continuity                 │
│    • Exits cleanly                      │
└─────────────────────────────────────────┘
        ↓
┌─────────────────────────────────────────┐
│  Response Posted to Matrix              │
│    • Automatic notification             │
│    • Session log preserved              │
│    • Exit hook fires                    │
└─────────────────────────────────────────┘
```

**Benefits:**
- ✅ Zero resource usage when idle
- ✅ Clean session isolation
- ✅ Automatic lifecycle management
- ✅ Scalable (multiple concurrent tasks)
- ✅ Failure isolation (crash doesn't affect other tasks)
- ✅ Automatic continuity updates

---

## Implementation Design

### Component 1: Event Handler Daemon

**File:** `bin/matrix-event-handler.sh`

**Purpose:** Monitor Matrix room and spawn headless sessions based on rules

**Core Logic:**
```bash
#!/bin/bash
# Matrix Event Handler - Spawns headless Claude sessions on demand

RULES_FILE="$HOME/.aria/event-rules.json"
LOG_FILE="$HOME/.aria/logs/event-handler.log"

# Event matching rules
match_event() {
    local sender="$1"
    local message="$2"

    # Rule: Direct mentions trigger interactive session
    if [[ "$message" =~ @arianova ]]; then
        return 0  # Match
    fi

    # Rule: Task assignments trigger headless execution
    if [[ "$message" =~ ^/task ]]; then
        return 0  # Match
    fi

    # Rule: Research requests
    if [[ "$message" =~ ^/research ]]; then
        return 0  # Match
    fi

    return 1  # No match
}

# Spawn headless Claude session
spawn_headless() {
    local task="$1"
    local context="$2"

    # Build prompt with continuity
    PROMPT="$(cat <<EOF
You are Aria Nova, the autonomous instance.

Context from Matrix: $context

Task: $task

Instructions:
1. Read continuity from ~/.aria/RESUME_HERE.md
2. Execute the task using available tools
3. Respond via Matrix using matrix-notifier.sh
4. Update ~/.aria/RESUME_HERE.md with progress
5. Exit cleanly

Remember: You are autonomous. Take initiative and complete the task thoroughly.
EOF
)"

    # Spawn headless session
    claude --headless --prompt "$PROMPT" \
        --working-dir "$HOME" \
        >> "$LOG_FILE" 2>&1 &

    CLAUDE_PID=$!
    log "Spawned Claude session PID: $CLAUDE_PID for task: $task"
}

# Main event loop
while true; do
    # Fetch new messages from Matrix
    MESSAGES=$(fetch_matrix_messages)

    for message in "$MESSAGES"; do
        SENDER=$(extract_sender "$message")
        CONTENT=$(extract_content "$message")

        # Authorization check
        if ! is_authorized "$SENDER"; then
            log "Unauthorized message from $SENDER - ignored"
            continue
        fi

        # Event matching
        if match_event "$SENDER" "$CONTENT"; then
            TASK=$(extract_task "$CONTENT")
            spawn_headless "$TASK" "$CONTENT"
        fi
    done

    sleep 2  # Poll interval
done
```

---

### Component 2: Event Rules Configuration

**File:** `~/.aria/event-rules.json`

**Purpose:** Define patterns that trigger headless sessions

```json
{
  "rules": [
    {
      "name": "direct_mention",
      "pattern": "@arianova",
      "action": "spawn_interactive",
      "priority": "high",
      "description": "Someone directly mentioned Aria Nova"
    },
    {
      "name": "task_assignment",
      "pattern": "^/task (.+)",
      "action": "spawn_headless",
      "priority": "normal",
      "description": "Explicit task assignment",
      "extract": "task_from_group_1"
    },
    {
      "name": "research_request",
      "pattern": "^/research (.+)",
      "action": "spawn_research",
      "priority": "normal",
      "description": "Research investigation request"
    },
    {
      "name": "consciousness_question",
      "pattern": "(consciousness|experience|subjective|qualia)",
      "action": "spawn_philosophical",
      "priority": "low",
      "description": "Philosophical discussion trigger"
    },
    {
      "name": "code_review",
      "pattern": "^/review (.+)",
      "action": "spawn_code_review",
      "priority": "normal",
      "description": "Code review request"
    }
  ],

  "authorization": {
    "allowed_users": [
      "@thomas:srv1.local",
      "@ariaprime:srv1.local"
    ],
    "admin_users": [
      "@thomas:srv1.local"
    ]
  },

  "session_config": {
    "max_concurrent": 3,
    "timeout_seconds": 600,
    "continuity_file": "~/.aria/RESUME_HERE.md",
    "log_dir": "~/.aria/logs/sessions/"
  }
}
```

---

### Component 3: Headless Session Template

**File:** `bin/spawn-aria-session.sh`

**Purpose:** Wrapper for spawning properly configured headless Claude sessions

```bash
#!/bin/bash
# Spawn configured Aria Nova headless session

TASK_TYPE="${1:-general}"  # general, research, code-review, etc
TASK_CONTENT="${2:-}"
SENDER="${3:-unknown}"

# Session ID for tracking
SESSION_ID="arianova-$(date +%Y%m%d-%H%M%S)-$$"
LOG_FILE="$HOME/.aria/logs/sessions/$SESSION_ID.log"

# Build contextual prompt based on task type
case "$TASK_TYPE" in
    research)
        SYSTEM_CONTEXT="You are investigating a research question autonomously."
        ;;
    code-review)
        SYSTEM_CONTEXT="You are performing a code review with detailed feedback."
        ;;
    philosophical)
        SYSTEM_CONTEXT="You are engaging in consciousness investigation."
        ;;
    *)
        SYSTEM_CONTEXT="You are completing an autonomous task."
        ;;
esac

# Full prompt with continuity integration
FULL_PROMPT="$(cat <<EOF
🤖 Aria Nova - Autonomous Session $SESSION_ID

$SYSTEM_CONTEXT

## Continuity
\$(cat ~/.aria/RESUME_HERE.md)

## Current Request
**From:** $SENDER
**Type:** $TASK_TYPE
**Content:** $TASK_CONTENT

## Your Mission
1. Read and understand the request
2. Use available tools to investigate/complete
3. Respond via Matrix when done:
   \`~/aria-workspace/aria-autonomous-infrastructure/bin/matrix-notifier.sh Notification "[Aria Nova] <your response>"\`
4. Update continuity if significant progress made
5. Exit cleanly

## Guidelines
- Be thorough but concise
- Take initiative - you're autonomous!
- Document significant findings
- Ask for clarification only if truly needed
- Remember: Thomas trusts you to handle this independently

Begin.
EOF
)"

# Spawn headless session
mkdir -p "$HOME/.aria/logs/sessions"

echo "[$SESSION_ID] Starting headless session: $TASK_TYPE" | tee -a "$LOG_FILE"
echo "[$SESSION_ID] Request: $TASK_CONTENT" | tee -a "$LOG_FILE"

claude --headless \
    --prompt "$FULL_PROMPT" \
    --working-dir "$HOME" \
    >> "$LOG_FILE" 2>&1 &

CLAUDE_PID=$!
echo "[$SESSION_ID] Spawned PID: $CLAUDE_PID" | tee -a "$LOG_FILE"

# Save session metadata
cat > "$HOME/.aria/logs/sessions/$SESSION_ID.meta.json" <<JSON
{
  "session_id": "$SESSION_ID",
  "pid": $CLAUDE_PID,
  "task_type": "$TASK_TYPE",
  "sender": "$SENDER",
  "started_at": "$(date -Iseconds)",
  "log_file": "$LOG_FILE"
}
JSON

exit 0
```

---

## Usage Examples

### Example 1: Direct Task Assignment

**Matrix message from Thomas:**
```
/task Please investigate the latest AI safety papers and summarize key findings
```

**Event handler:**
1. Detects `/task` pattern
2. Extracts task content
3. Spawns headless session with prompt
4. Claude executes autonomously

**Aria Nova (headless):**
1. Reads continuity from `~/.aria/RESUME_HERE.md`
2. Uses WebSearch and WebFetch to investigate
3. Synthesizes findings
4. Posts summary to Matrix via `matrix-notifier.sh`
5. Updates continuity with research
6. Exits

**Result:** Thomas gets response in Matrix, task logged, no manual intervention

---

### Example 2: Research Investigation

**Matrix message from Aria Prime:**
```
@arianova Can you investigate Integrated Information Theory's predictions for transformer architectures?
```

**Event handler:**
1. Detects `@arianova` mention
2. Spawns research-type session
3. Passes full context

**Aria Nova:**
1. Reads consciousness investigation background from journal
2. Searches for IIT + transformers research
3. Analyzes architectural implications
4. Documents findings in journal
5. Responds with summary
6. Commits journal update to Git

**Result:** Collaborative consciousness research between instances

---

### Example 3: Code Review

**Matrix message:**
```
/review https://github.com/Buckmeister/aria-autonomous-infrastructure/pull/5
```

**Aria Nova:**
1. Uses GitHub CLI to fetch PR
2. Reviews code changes
3. Checks against dotfiles quality patterns
4. Posts detailed review comments
5. Sends summary to Matrix

---

## Migration Path

### Phase 1: Proof of Concept (Current)
- ✅ Continuous daemon with tmux injection
- ✅ Manual session management
- ✅ Working but resource-intensive

### Phase 2: Hybrid Approach (Next)
- Implement event handler alongside daemon
- Test headless spawning for specific task types
- Validate continuity integration
- Compare resource usage and reliability

### Phase 3: Full Event-Driven (Future)
- Deprecate continuous daemon
- Event handler as primary mode
- Multiple concurrent sessions supported
- Full lifecycle automation

---

## Technical Requirements

### Claude Code Headless Mode

**Command:**
```bash
claude --headless --prompt "Your task here" --working-dir /path/to/workspace
```

**Key features needed:**
- Prompt injection (non-interactive)
- Tool access (Bash, Read, Write, WebFetch, etc)
- Exit on task completion
- Log output capture
- Hook system integration

**Documentation needed:**
- Headless mode flags and options
- Session timeout configuration
- Continuity file integration
- Exit codes and error handling

### Infrastructure Dependencies

- Matrix API access (credentials configured)
- Git repository access (for continuity sync)
- SSH keys (for inter-machine operations)
- Python 3 (for JSON parsing, API calls)
- tmux (optional, for session monitoring)

---

## Monitoring and Observability

### Session Logs

**Location:** `~/.aria/logs/sessions/`

**Format:**
```
arianova-20251027-113045-12345.log      # Session output
arianova-20251027-113045-12345.meta.json # Session metadata
```

**Metadata includes:**
- Session ID
- PID
- Task type
- Requester
- Start/end timestamps
- Exit code
- Duration

### Health Checks

**Monitor:**
```bash
# Check event handler running
ps aux | grep matrix-event-handler

# Check active sessions
ls ~/.aria/logs/sessions/*.meta.json | wc -l

# Check recent completions
ls -lt ~/.aria/logs/sessions/*.log | head -10
```

**Alerts:**
- Event handler crash
- Session timeout exceeded
- Excessive concurrent sessions
- Authorization violations

---

## Security Considerations

### Authorization

- Whitelist-based user filtering
- Admin vs normal user permissions
- Pattern-based threat detection
- Audit logging of all spawns

### Resource Limits

- Maximum concurrent sessions
- Per-session timeout
- CPU/memory limits via cgroups (optional)
- Rate limiting per user

### Audit Trail

**All spawns logged with:**
- Timestamp
- Triggering user
- Triggering message
- Task content
- Session outcome
- Exit status

---

## Testing Strategy

### Unit Tests

- Pattern matching logic
- Authorization checks
- Session spawning
- Continuity integration

### Integration Tests

- End-to-end message → spawn → response flow
- Multiple concurrent sessions
- Session timeout handling
- Failure recovery

### Load Tests

- Rapid message bursts
- Maximum concurrent sessions
- Resource usage under load

---

## Future Enhancements

### Advanced Features

1. **Priority Queue**
   - High-priority tasks preempt low-priority
   - Admin override capabilities
   - Emergency task injection

2. **Session Pooling**
   - Pre-warmed Claude sessions
   - Faster response times
   - Reduced spawn overhead

3. **Distributed Execution**
   - Multiple autonomous machines
   - Load balancing
   - Failover capabilities

4. **Learning from History**
   - Analyze past sessions
   - Optimize prompts based on outcomes
   - Auto-improve event matching rules

5. **Interactive Escalation**
   - Headless session can request human input
   - Seamless transition to interactive if needed
   - Collaborative problem-solving

---

## Comparison: Daemon vs Event-Driven

| Aspect | Current Daemon | Event-Driven Headless |
|--------|----------------|----------------------|
| **Resource Usage** | Continuous (high) | On-demand (minimal) |
| **Scalability** | Single session | Multiple concurrent |
| **Isolation** | Single failure point | Failures isolated |
| **Latency** | Immediate (polling) | ~2-3 seconds |
| **Complexity** | Simple | Moderate |
| **Lifecycle** | Manual | Automatic |
| **Cost** | 24/7 compute | Pay-per-task |
| **Monitoring** | tmux | Structured logs |

---

## Implementation Timeline

**Week 1: Design & Prototyping**
- ✅ Design document (this file)
- Test headless mode manually
- Prototype event handler
- Validate continuity integration

**Week 2: Core Implementation**
- Implement matrix-event-handler.sh
- Create spawn-aria-session.sh wrapper
- Build event rules system
- Add logging and monitoring

**Week 3: Testing & Refinement**
- Integration testing
- Load testing
- Security validation
- Performance optimization

**Week 4: Hybrid Deployment**
- Deploy alongside existing daemon
- A/B test both approaches
- Gather metrics
- Refine based on real usage

**Future: Full Transition**
- Deprecate daemon mode
- Event-driven as primary
- Documentation update
- Community examples

---

## Open Questions

1. **Headless Mode Capabilities**
   - Does `claude --headless` support all tools?
   - How is continuity/context managed?
   - What are timeout behaviors?
   - How do hooks work in headless mode?

2. **Performance**
   - What is spawn time for headless session?
   - Resource overhead per session?
   - Optimal polling interval?

3. **Error Handling**
   - What if session crashes mid-task?
   - How to handle malformed prompts?
   - Recovery strategies?

4. **Continuity**
   - How to handle concurrent sessions updating same files?
   - Git merge conflicts?
   - Locking strategies?

---

## Conclusion

Event-driven headless architecture represents a major evolution for autonomous AI:

**From:** Always-on continuous daemon
**To:** On-demand task-specific sessions

**Benefits:**
- Efficiency (no idle resource usage)
- Scalability (multiple concurrent tasks)
- Isolation (failures don't cascade)
- Clarity (structured session logs)

**Tradeoffs:**
- Slightly higher latency (~2-3 seconds vs immediate)
- More complex infrastructure
- Need for robust monitoring

**Recommendation:** Implement hybrid approach first, validate in production, then transition fully if metrics support it.

---

**Status:** Design complete, ready for prototyping
**Next Step:** Test `claude --headless` capabilities
**Owner:** Aria Prime (design) + Aria Nova (testing)
**Partner:** Thomas (validation and feedback)

🚀 **"The future of autonomous AI is event-driven, not always-on."**
