# kmgr - Kubernetes Manager Guide

**Version:** 1.0.0
**Created:** 2025-11-22
**Author:** Aria Prime
**Status:** ✅ Core Features Operational

---

## Overview

`kmgr` is a comprehensive command-line tool for managing Kubernetes clusters on Xen/XCP-ng infrastructure. It provides unified management of:

- **Cluster lifecycle** (create, destroy, status)
- **Node management** (add, remove nodes)
- **SSH key management** (generate, deploy, list keys)
- **Integration** with Ray Cluster, Rocket AI, and Matrix

## Quick Start

```bash
# Show cluster status
kmgr status

# List SSH keys
kmgr keys list

# Generate new SSH key
kmgr keys generate aria_k8s_newcluster

# SSH into control plane
kmgr ssh cp-1

# Show help
kmgr help
```

---

## Installation

The `kmgr` tool is already installed in your infrastructure repository:

```bash
~/Development/aria-autonomous-infrastructure/bin/kmgr
```

### Add to PATH (Optional)

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$PATH:$HOME/Development/aria-autonomous-infrastructure/bin"
```

Then reload your shell:

```bash
source ~/.zshrc  # or ~/.bashrc
```

---

## Commands

### Cluster Commands

#### `kmgr status [CLUSTER]`

Show comprehensive cluster status including:
- Xen host connectivity
- VM power states
- Kubernetes node status
- Deployed namespaces

```bash
# Show status of default cluster (kcl1)
kmgr status

# Show status of specific cluster
kmgr status kcl2
```

**Example Output:**
```
╔════════════════════════════════════════════════════════════════════╗
║ Kubernetes Cluster Status                                         ║
║ kcl1                                                               ║
╚════════════════════════════════════════════════════════════════════╝

▶ Xen Host Connectivity
✓ Connected to Xen host: opt-bck01.bck.intern

▶ Cluster VMs
  ● cp-1 (running)
  ● cp-2 (running)
  ● cp-3 (running)
  ● worker-1 (running)
  ● worker-2 (running)
  ● worker-3 (running)
  ● worker-4 (running)

▶ Kubernetes Cluster
✓ MicroK8s is running on cp-1

Nodes:
  ✓ cp-1       Ready    <none>   50d   v1.34.1
  ✓ cp-2       Ready    <none>   50d   v1.34.1
  ✓ cp-3       Ready    <none>   50d   v1.34.1
  ✓ worker-1   Ready    <none>   50d   v1.34.1
  ✓ worker-2   Ready    <none>   50d   v1.34.1
  ✓ worker-3   Ready    <none>   50d   v1.34.1
  ✓ worker-4   Ready    <none>   50d   v1.34.1

Namespaces:
  • default
  • kube-system
  • kube-public
  • ray-system
  • ray-dev
```

#### `kmgr create [CLUSTER]`

Create a new Kubernetes cluster (planned feature).

```bash
kmgr create kcl2
```

**Status:** 🚧 Under Development

**Manual Alternative:**
1. Provision VMs on Xen host
2. Install MicroK8s on each node
3. Form cluster using `microk8s add-node`

#### `kmgr destroy [CLUSTER]`

Destroy an existing cluster (planned feature).

**Status:** 🚧 Not Yet Implemented

#### `kmgr config`

Show and edit cluster configuration.

```bash
kmgr config
```

Creates/displays: `~/.aria/config/kubernetes-clusters.conf`

**Example Configuration:**
```ini
[kcl1]
name=kcl1
control_plane_nodes=cp-1,cp-2,cp-3
worker_nodes=worker-1,worker-2,worker-3,worker-4
network=192.168.188.0/24
created=2025-10-03
status=active
description=Primary development cluster (7 nodes)
```

---

### Node Commands

#### `kmgr add-node [CLUSTER] [TYPE]`

Add a new node to the cluster.

```bash
# Add worker node
kmgr add-node kcl1 worker

# Add control plane node
kmgr add-node kcl1 control-plane
```

**Status:** 🚧 Guidance Only

**Manual Steps:**
1. Create VM on Xen
2. Install MicroK8s
3. Get join token: `sudo microk8s add-node`
4. Join: `sudo microk8s join <IP>:25000/<token>`

#### `kmgr remove-node [CLUSTER] [NODE]`

Remove a node from the cluster.

```bash
kmgr remove-node kcl1 worker-4
```

**Steps Performed:**
1. Drains workloads from node
2. Removes node from Kubernetes
3. Makes node leave cluster

**⚠️ Warning:** This is destructive and requires confirmation.

#### `kmgr ssh [NODE]`

SSH into a cluster node.

```bash
# Connect to control plane
kmgr ssh cp-1

# Connect to worker
kmgr ssh worker-3
```

**Requirements:**
- SSH key must exist: `~/.aria/ssh/aria_[NODE]_key`
- Node must be accessible on network

---

### SSH Key Commands

#### `kmgr keys list`

List all managed SSH keys in `~/.aria/ssh/`.

```bash
kmgr keys list
```

**Example Output:**
```
╔════════════════════════════════════════════════════════════════════╗
║ SSH Keys                                                           ║
║ Keys stored in ~/.aria/ssh/                                        ║
╚════════════════════════════════════════════════════════════════════╝

Private Keys:
  • aria_xen_key (256 bits)
    └─ Public key: aria_xen_key.pub
  • aria_cp-1_key (256 bits)
    └─ Public key: aria_cp-1_key.pub
  • aria_worker-1_key (256 bits)
    └─ Public key: aria_worker-1_key.pub
```

#### `kmgr keys generate [NAME]`

Generate a new SSH key pair.

```bash
# Generate with default name
kmgr keys generate

# Generate with custom name
kmgr keys generate aria_k8s_dev
```

**Creates:**
- Private key: `~/.aria/ssh/[NAME]`
- Public key: `~/.aria/ssh/[NAME].pub`

**Key Type:** Ed25519 (modern, secure)

#### `kmgr keys show [NAME]`

Display the public key content.

```bash
kmgr keys show aria_xen_key
```

**Output:**
```
▶ Public Key: aria_xen_key
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... aria@kubernetes-cluster
```

#### `kmgr keys deploy [NAME] [HOST]`

Deploy public key to remote host (planned feature).

```bash
kmgr keys deploy aria_k8s_dev cp-1
```

**Status:** 🚧 Not Yet Implemented

**Manual Alternative:**
```bash
ssh-copy-id -i ~/.aria/ssh/aria_k8s_dev.pub debian@cp-1
```

---

## Directory Structure

`kmgr` uses the `~/.aria` directory for all its data:

```
~/.aria/
├── ssh/                           # SSH keys
│   ├── aria_xen_key
│   ├── aria_xen_key.pub
│   ├── aria_cp-1_key
│   ├── aria_cp-1_key.pub
│   └── ...
├── kubernetes/                    # Kubernetes configs
│   ├── kcl1-kubeconfig
│   └── kcl2-kubeconfig
├── config/                        # Cluster configurations
│   └── kubernetes-clusters.conf
├── INFRASTRUCTURE.md              # Infrastructure documentation
└── RESUME_HERE.md                # Session continuity
```

---

## Integration

### Ray Cluster

`kmgr` integrates with Ray Cluster deployments:

```bash
# Check Ray pods status
kmgr ssh cp-1
sudo /snap/bin/microk8s kubectl get pods -n ray-dev
```

**Ray Documentation:** `~/Development/aria-autonomous-infrastructure/docs/RAY_CLUSTER_INTEGRATION.md`

### Rocket AI

Rocket instances can be deployed on the cluster:

```bash
# Deploy Rocket via launch-rocket.sh
cd ~/Development/aria-autonomous-infrastructure
./bin/launch-rocket.sh --help
```

### Matrix Integration

Cluster events can be sent to Matrix rooms for monitoring.

---

## Current Cluster: kcl1

**Overview:**
- **Name:** kcl1 (Kubernetes Cluster 1)
- **Created:** 2025-10-03
- **Age:** 50 days
- **Status:** Active and healthy

**Topology:**
- **Control Plane Nodes:** 3 (cp-1, cp-2, cp-3)
- **Worker Nodes:** 4 (worker-1, worker-2, worker-3, worker-4)
- **Total Nodes:** 7
- **Network:** 192.168.188.0/24

**Kubernetes:**
- **Version:** v1.34.1
- **Distribution:** MicroK8s
- **Runtime:** containerd 1.7.28

**Node Details:**
| Node | Role | IP | Status |
|------|------|-------------|--------|
| cp-1 | Control Plane | 192.168.188.113 | Ready |
| cp-2 | Control Plane | 192.168.188.115 | Ready |
| cp-3 | Control Plane | 192.168.188.114 | Ready |
| worker-1 | Worker | 192.168.188.116 | Ready |
| worker-2 | Worker | 192.168.188.117 | Ready |
| worker-3 | Worker | 192.168.188.120 | Ready |
| worker-4 | Worker | 192.168.188.118 | Ready |

**Deployed Applications:**
- KubeRay Operator (ray-system namespace)
- Ray Cluster Dev (ray-dev namespace)
- Prometheus/Grafana (monitoring namespace - planned)

---

## Advanced Usage

### Custom Cluster Management

Edit the cluster configuration file:

```bash
vim ~/.aria/config/kubernetes-clusters.conf
```

Add a new cluster:

```ini
[kcl2]
name=kcl2
control_plane_nodes=cp2-1,cp2-2,cp2-3
worker_nodes=worker2-1,worker2-2
network=192.168.189.0/24
created=2025-11-22
status=planned
description=Testing cluster for CI/CD
```

### Scripting with kmgr

Use `kmgr` in your automation scripts:

```bash
#!/bin/bash

# Check cluster health
if ! kmgr status kcl1 | grep -q "MicroK8s is running"; then
    echo "Cluster unhealthy!"
    exit 1
fi

# Deploy application
kubectl apply -f my-app.yaml
```

### Remote Execution

Execute commands on all nodes:

```bash
# Update all nodes
for node in cp-{1..3} worker-{1..4}; do
    kmgr ssh $node "sudo apt update && sudo apt upgrade -y"
done
```

---

## Troubleshooting

### SSH Connection Issues

**Problem:** Cannot SSH to node

**Solution:**
1. Check SSH key exists: `kmgr keys list`
2. Verify node is accessible: `ping cp-1`
3. Check key permissions: `ls -l ~/.aria/ssh/`
4. Regenerate key if needed: `kmgr keys generate aria_cp-1_key`

### Xen Host Unreachable

**Problem:** Cannot connect to Xen host

**Solution:**
1. Verify Xen host is up: `ping opt-bck01.bck.intern`
2. Check SSH key: `~/.aria/ssh/aria_xen_key`
3. Test connection: `ssh -i ~/.aria/ssh/aria_xen_key root@opt-bck01.bck.intern`

### Node Not Appearing

**Problem:** Node doesn't appear in `kmgr status`

**Solution:**
1. Check VM is running on Xen
2. Verify MicroK8s is installed
3. Ensure node joined cluster: `sudo microk8s kubectl get nodes`

---

## Roadmap

### Version 1.1 (Planned)

- [ ] Full cluster creation automation
- [ ] Automated VM provisioning via Xen API
- [ ] Cloud-init template management
- [ ] Automatic SSH key deployment
- [ ] Cluster backup and restore

### Version 1.2 (Future)

- [ ] Multi-cluster management
- [ ] Cluster migration tools
- [ ] Resource quotas and limits
- [ ] Network policy management
- [ ] Storage provisioning

### Version 2.0 (Vision)

- [ ] Web UI for cluster management
- [ ] Automated scaling (cluster autoscaler)
- [ ] GitOps integration (FluxCD/ArgoCD)
- [ ] Service mesh support (Istio/Linkerd)
- [ ] Advanced monitoring and alerting

---

## Contributing

This tool is part of the Aria autonomous infrastructure project.

**Development:**
- Source: `~/Development/aria-autonomous-infrastructure/bin/kmgr`
- Documentation: `~/Development/aria-autonomous-infrastructure/docs/KMGR_GUIDE.md`
- Tests: `~/.config/dotfiles/tests/test_xen.zsh` (patterns)

**Testing:**
Always test new features on a development cluster before production!

---

## Support

For issues or questions:

1. Check this documentation: `~/Development/aria-autonomous-infrastructure/docs/KMGR_GUIDE.md`
2. Review infrastructure docs: `~/.aria/INFRASTRUCTURE.md`
3. Check test patterns: `~/.config/dotfiles/tests/test_xen.zsh`

---

**Last Updated:** 2025-11-22
**Maintainer:** Aria Prime
**License:** MIT

