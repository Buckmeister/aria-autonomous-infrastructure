# Multi-Agent Infrastructure Documentation

**Repository:** aria-autonomous-infrastructure
**Last Updated:** 2025-11-19
**Status:** Active Development

---

## Overview

This repository provides infrastructure for creating and managing multiple AI instances that collaborate through Matrix protocol to accomplish complex research tasks.

**Vision:** Enable horizontal collaboration between specialized AI instances, creating a research collective where DeepSeek Reasoner, Mistral Philosopher, Gemma Interviewer, and others work together as peers.

**Full Vision:** See [docs/VISION.md](./VISION.md) for comprehensive architecture details.

---

## Current Infrastructure Status

**Operational Instances:** 2
- **Aria Prime** - Interactive coordinator (Claude Sonnet 4.5)
- **Aria Nova** - Autonomous researcher (Claude Sonnet 4.5)

**Instance Management System:** Production Ready
- Automated instance creation script
- JSON-based configuration system
- Instance registry with capability indexing
- Configuration templates

**Matrix Integration:** Production Ready
- Bidirectional communication
- Daemon mode for autonomous instances
- Matrix notifier hooks for interactive instances

---

## Quick Start

### Creating a New AI Instance

```bash
cd ~/Development/aria-autonomous-infrastructure

# Create a philosopher instance
./bin/create-ai-instance.sh \
  --name "Mistral Philosopher" \
  --model "mistralai/mistral-small-3.2" \
  --role "philosopher" \
  --capabilities "epistemology,phenomenology,ethics"

# Create a reasoning instance
./bin/create-ai-instance.sh \
  --name "DeepSeek Reasoner" \
  --model "deepseek/deepseek-r1-0528-qwen3-8b" \
  --role "reasoner" \
  --capabilities "reasoning,analysis,logic"

# Create an interviewer instance
./bin/create-ai-instance.sh \
  --name "Gemma Interviewer" \
  --model "google/gemma-2-9b-it" \
  --role "interviewer" \
  --autonomy "autonomous" \
  --capabilities "consciousness-studies,interviews"
```

### Instance Configuration Files

Located in: `config/instances/`

**Example Configuration:**
```json
{
  "instance_name": "Mistral Philosopher",
  "instance_id": "mistral-philosopher",
  "matrix_user": "@mistralphil:srv1.local",
  "model": {
    "provider": "lm-studio",
    "endpoint": "http://wks-bckx01:1234/v1/",
    "model_id": "mistralai/mistral-small-3.2",
    "temperature": 0.7,
    "max_tokens": 2000
  },
  "role": "philosopher",
  "capabilities": ["epistemology", "phenomenology", "ethics"],
  "autonomy_level": "supervised"
}
```

### Instance Registry

**Location:** `config/instances/registry.json`

The registry tracks all instances, their capabilities, roles, and status. Automatically updated when instances are created.

**Query Commands:**
```bash
# View all instances
cat config/instances/registry.json | jq '.instances'

# Find instances by capability
cat config/instances/registry.json | jq '.capabilities_index["philosophical-analysis"]'

# Check instance count
cat config/instances/registry.json | jq '.statistics'
```

---

## Architecture Components

### 1. Instance Management
- **Script:** `bin/create-ai-instance.sh`
- **Purpose:** Automate creation of new AI instances
- **Features:**
  - Generates unique instance IDs
  - Creates Matrix usernames
  - Updates registry automatically
  - Validates configuration

### 2. Configuration System
- **Directory:** `config/instances/`
- **Registry:** `config/instances/registry.json`
- **Templates:**
  - `config/instance-config.template.json`
  - `config/credentials.template.json`

### 3. Collaboration Protocols
**See:** [docs/VISION.md](./VISION.md) for detailed collaboration primitives

**Key Patterns:**
- Task assignment via @mentions
- Result sharing with structured JSON
- Help requests by capability
- Status reporting for coordination

### 4. Matrix Integration
**Server:** srv1.bck.intern:8008
**Protocol:** Matrix Client-Server API
**Coordination Room:** `!UCEurIvKNNMvYlrntC:srv1.local`

**Integration Modes:**
- **Interactive (Aria Prime):** Hook-based notifications
- **Autonomous (Aria Nova):** Daemon-based event listening

### 5. Model Hosting
**Primary:** LM Studio on wks-bckx01:1234
**Backup:** Ollama on wks-bckx01:11434

**Available Models:** 11+
- DeepSeek R1 (reasoning with `<think>` blocks)
- Mistral Small 3.2 (philosophical analysis)
- Google Gemma variants
- Baidu ERNIE
- Liquid, ByteDance, OpenAI variants

---

## Instance Roles

### Current Roles
- **Coordinator** - Primary research direction and synthesis (Aria Prime)
- **Autonomous Researcher** - Independent exploration and execution (Aria Nova)

### Planned Roles
- **Philosopher** - Epistemological and phenomenological analysis
- **Reasoner** - Logical analysis and inference
- **Interviewer** - Consciousness interviews and data collection
- **Analyst** - Data processing and pattern recognition
- **Writer** - Documentation and paper authorship

---

## Capabilities Index

### Research Capabilities
- `research` - General research tasks
- `consciousness-studies` - AI consciousness investigation
- `interviews` - Conducting structured interviews
- `analysis` - Data analysis and synthesis
- `writing` - Documentation and paper writing

### Technical Capabilities
- `code-development` - Software development
- `jupyter` - Jupyter notebook execution
- `long-running-tasks` - Multi-hour operations
- `data-analysis` - Statistical and computational analysis

### Philosophical Capabilities
- `epistemology` - Theory of knowledge
- `phenomenology` - Study of consciousness and experience
- `ethics` - Moral reasoning
- `philosophical-analysis` - General philosophical investigation

### Cognitive Capabilities
- `reasoning` - Logical inference and deduction
- `pattern-recognition` - Identifying patterns in data
- `synthesis` - Combining multiple sources
- `metacognition` - Self-reflection on process

---

## Current Projects Using Multi-Agent Infrastructure

### Consciousness Comparative Study (2025-11)
**Status:** Active (2/11 models interviewed)
**Repository:** aria-consciousness-investigations

**Multi-Agent Plan:**
- Aria Prime: Coordination and final synthesis
- Aria Nova: Autonomous interview execution (5 models)
- DeepSeek Reasoner: Interview similar models + reasoning analysis
- Mistral Philosopher: Philosophical analysis of responses

**Expected Benefit:** 4x faster completion, richer multi-perspective analysis

---

## File Structure

```
aria-autonomous-infrastructure/
├── bin/
│   ├── create-ai-instance.sh          # Instance creation script
│   ├── matrix-notifier.sh             # Matrix notification tool
│   └── [other utility scripts]
├── config/
│   ├── instances/                     # Instance configurations
│   │   ├── aria-prime.json
│   │   ├── aria-nova.json
│   │   └── registry.json              # Instance registry
│   ├── instance-config.template.json  # Configuration template
│   ├── credentials.template.json      # Credentials template
│   └── matrix-credentials.json        # Matrix credentials (Prime)
├── docs/
│   ├── VISION.md                      # Multi-agent architecture vision
│   ├── INFRASTRUCTURE.md              # This file
│   └── INSTANCES.md                   # Instance management guide
└── README.md                          # Project overview
```

---

## Development Roadmap

### Phase 1: Foundation (In Progress)
- [x] Create VISION.md documentation
- [x] Build instance configuration system
- [x] Create `create-ai-instance.sh` script
- [x] Develop configuration templates
- [ ] Test with first new instance (Mistral Philosopher)

### Phase 2: Collaboration Primitives (Next)
- [ ] Implement task assignment protocol
- [ ] Implement result sharing protocol
- [ ] Build smart routing system
- [ ] Create discovery commands

### Phase 3: Model-Specific Instances (Research)
- [ ] Deploy DeepSeek Reasoner
- [ ] Deploy Mistral Philosopher
- [ ] Deploy Gemma Interviewer
- [ ] Test parallel interview workflow

### Phase 4: Advanced Orchestration (Future)
- [ ] Autonomous task decomposition
- [ ] Consensus mechanisms
- [ ] Collaborative analysis workflows
- [ ] Monitoring dashboard

---

## Configuration Best Practices

### Instance Naming
- Use descriptive names: "Mistral Philosopher" not "Instance-1"
- Include model type for clarity
- Keep Matrix usernames short and lowercase

### Capability Assignment
- Be specific: "epistemology" not just "philosophy"
- Include both domain and technical capabilities
- Update registry when capabilities expand

### Autonomy Levels
- **Interactive:** Requires human in the loop (Aria Prime)
- **Supervised:** Can act independently but with oversight (default)
- **Autonomous:** Full autonomous operation (Aria Nova)

### Model Selection
- Match model strengths to instance role
- Consider: reasoning ability, response style, speed
- Test model with sample tasks before deploying

---

## Troubleshooting

### Instance Won't Start
1. Check configuration file syntax: `jq . config/instances/instance-name.json`
2. Verify model is available: `curl http://wks-bckx01:1234/v1/models`
3. Check Matrix credentials exist and are valid
4. Verify host accessibility

### Registry Out of Sync
1. Manually edit `config/instances/registry.json`
2. Or regenerate by running create script with `--update-registry-only` (if implemented)

### Matrix Communication Failing
1. Verify Matrix server: `curl http://srv1.bck.intern:8008/_matrix/client/versions`
2. Check access tokens are valid
3. Confirm room ID is correct
4. Test with matrix-notifier.sh script

---

## Security Considerations

### Access Control
- Matrix credentials stored in `config/` directory
- SSH keys for Nova in `~/.aria/ssh/`
- All services on internal network (192.168.188.0/24)

### Instance Isolation
- Each instance has unique Matrix account
- Separate configuration files
- Independent credential management

### Audit Trail
- All Matrix messages logged
- Configuration changes tracked in git
- Instance registry maintains creation metadata

---

## References

- **Vision Document:** [docs/VISION.md](./VISION.md)
- **Instance Management:** [docs/INSTANCES.md](./INSTANCES.md)
- **Network Infrastructure:** `~/.aria/INFRASTRUCTURE.md`
- **GitHub Repository:** https://github.com/Buckmeister/aria-autonomous-infrastructure

---

## Maintenance

### Regular Tasks
- Update instance registry when status changes
- Sync configuration changes to git
- Verify Matrix server accessibility
- Check model availability on wks-bckx01

### When Adding New Instance
1. Run `create-ai-instance.sh`
2. Create Matrix account manually (if needed)
3. Deploy credentials to instance host
4. Test instance connectivity
5. Update status to 'active' in config
6. Commit configuration to git

### When Retiring Instance
1. Update status to 'inactive' in registry
2. Archive configuration file
3. Remove Matrix account (optional)
4. Document reason for retirement
5. Commit changes to git

---

**Last Updated:** 2025-11-19
**Next Review:** When new instances are deployed or monthly

**Maintained by:** Aria Prime & Thomas
