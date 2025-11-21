# Rocket Phase 2: Kubernetes Deployment Guide

This directory contains Kubernetes manifests for deploying Rocket (Matrix-connected LLM infrastructure) on MicroK8s clusters.

## Architecture Overview

Phase 2 introduces Kubernetes orchestration with three deployment options:

### 1. **Rocket Ollama** (CPU-friendly)
- **Path**: `k8s/rocket-ollama/`
- **Components**: Ollama inference server + Matrix listener
- **Resources**: CPU-optimized, ~2-4GB RAM
- **Best for**: CPU-only nodes, development, testing
- **Model**: qwen2.5:0.5b (default, configurable)

### 2. **Rocket vLLM** (GPU-accelerated)
- **Path**: `k8s/rocket-vllm/`
- **Components**: vLLM inference server + Matrix listener
- **Resources**: GPU required, 8-16GB RAM, 1+ GPU
- **Best for**: GPU nodes, production, high performance
- **Model**: Qwen/Qwen2.5-3B-Instruct (default)

### 3. **Rocket Anthropic** (Cloud API)
- **Path**: `k8s/rocket-anthropic/`
- **Components**: Matrix listener only (calls Anthropic API)
- **Resources**: Minimal (~256MB RAM)
- **Best for**: Any node, cloud-hybrid deployments
- **Model**: claude-sonnet-4-20250514

## Directory Structure

```
k8s/
├── README.md                    # This file
├── shared/                      # Shared resources for all deployments
│   ├── namespace.yaml          # Rocket namespace definition
│   ├── secret.yaml             # Matrix credentials
│   └── resource-limits.yaml    # Resource quotas and limits
├── rocket-ollama/              # Ollama deployment
│   ├── configmap.yaml          # Ollama configuration
│   ├── pvc.yaml                # Persistent storage for models
│   ├── deployment.yaml         # Ollama + listener pods
│   └── service.yaml            # Ollama API service
├── rocket-vllm/                # vLLM deployment (GPU)
│   ├── configmap.yaml          # vLLM configuration
│   ├── deployment.yaml         # vLLM + listener pods (GPU)
│   └── service.yaml            # vLLM API service
└── rocket-anthropic/           # Anthropic deployment
    ├── secret.yaml             # Anthropic API key
    ├── configmap.yaml          # Anthropic configuration
    └── deployment.yaml         # Listener pod only
```

## Prerequisites

### 1. MicroK8s Cluster

Your cluster should have:
- **Control Plane**: cp-1 (master node)
- **Worker Nodes**: worker-1 (and any additional workers)
- **MicroK8s version**: v1.28+ recommended

### 2. Required MicroK8s Addons

```bash
# Enable on control plane (cp-1)
ssh debian@cp-1
sudo microk8s enable dns storage

# Optional but recommended:
sudo microk8s enable metrics-server  # Resource monitoring
sudo microk8s enable ingress         # HTTP/HTTPS routing
sudo microk8s enable metallb         # LoadBalancer support
```

### 3. GPU Support (for vLLM only)

If deploying vLLM on GPU nodes:

```bash
# Install NVIDIA device plugin
ssh debian@worker-1
sudo microk8s kubectl apply -f https://raw.githubusercontent.com/NVIDIA/k8s-device-plugin/main/nvidia-device-plugin.yml

# Verify GPU detection
sudo microk8s kubectl describe nodes | grep nvidia.com/gpu
```

### 4. Access Configuration

Ensure you can run kubectl commands from cp-1:

```bash
# Test kubectl access
ssh debian@cp-1
sudo /snap/bin/microk8s kubectl get nodes
```

Or configure remote kubectl access:

```bash
# Export kubeconfig from cp-1
ssh debian@cp-1 "sudo microk8s config" > ~/.kube/config-rocket

# Use with kubectl
export KUBECONFIG=~/.kube/config-rocket
kubectl get nodes
```

## Quick Start: Deploy Ollama (CPU)

The fastest way to get started with Rocket on Kubernetes:

### Step 1: Apply Shared Resources

```bash
# SSH to control plane
ssh debian@cp-1

# Navigate to deployment directory (or use kubectl -f with remote paths)
# For this example, we'll assume files are accessible on cp-1

# Create namespace, Matrix secret, and resource limits
sudo microk8s kubectl apply -f k8s/shared/namespace.yaml
sudo microk8s kubectl apply -f k8s/shared/secret.yaml
sudo microk8s kubectl apply -f k8s/shared/resource-limits.yaml
```

### Step 2: Deploy Ollama

```bash
# Apply Ollama manifests
sudo microk8s kubectl apply -f k8s/rocket-ollama/configmap.yaml
sudo microk8s kubectl apply -f k8s/rocket-ollama/pvc.yaml
sudo microk8s kubectl apply -f k8s/rocket-ollama/deployment.yaml
sudo microk8s kubectl apply -f k8s/rocket-ollama/service.yaml
```

### Step 3: Verify Deployment

```bash
# Check pod status
sudo microk8s kubectl get pods -n rocket

# Expected output:
# NAME                             READY   STATUS    RESTARTS   AGE
# rocket-ollama-xxxxxxxxxx-xxxxx   2/2     Running   0          2m

# Check logs
sudo microk8s kubectl logs -n rocket deployment/rocket-ollama -c ollama-server
sudo microk8s kubectl logs -n rocket deployment/rocket-ollama -c matrix-listener

# Test Ollama API
sudo microk8s kubectl port-forward -n rocket svc/rocket-ollama 11434:11434
# In another terminal:
curl http://localhost:11434/api/tags
```

### Step 4: Monitor in Portainer

Access Portainer at `https://worker-1:30779`:
- Username: `aria`
- Password: `YouAreAwesome`

Navigate to: **Cluster** → **rocket namespace** → **Deployments** → **rocket-ollama**

## Deployment Options

### Deploy vLLM (GPU)

**Prerequisites**: GPU node with NVIDIA device plugin

```bash
ssh debian@cp-1

# 1. Update node selector in deployment.yaml
# Edit k8s/rocket-vllm/deployment.yaml:
#   nodeSelector:
#     kubernetes.io/hostname: worker-1  # Replace with your GPU node

# 2. Apply shared resources (if not already done)
sudo microk8s kubectl apply -f k8s/shared/

# 3. Deploy vLLM
sudo microk8s kubectl apply -f k8s/rocket-vllm/
```

### Deploy Anthropic (Cloud API)

**Prerequisites**: Anthropic API key

```bash
ssh debian@cp-1

# 1. Update Anthropic API key
# Edit k8s/rocket-anthropic/secret.yaml:
#   api-key: "sk-ant-your-actual-key-here"

# 2. Apply shared resources (if not already done)
sudo microk8s kubectl apply -f k8s/shared/

# 3. Deploy Anthropic
sudo microk8s kubectl apply -f k8s/rocket-anthropic/
```

## Configuration

### Changing Models

**Ollama**:
```bash
# Edit k8s/rocket-ollama/configmap.yaml
# Change MODEL_NAME: "qwen2.5:0.5b" to your desired model
# Examples: qwen2.5:1.5b, qwen2.5:3b, llama3.2:1b

sudo microk8s kubectl apply -f k8s/rocket-ollama/configmap.yaml
sudo microk8s kubectl rollout restart deployment/rocket-ollama -n rocket
```

**vLLM**:
```bash
# Edit k8s/rocket-vllm/configmap.yaml
# Change MODEL_NAME: "Qwen/Qwen2.5-3B-Instruct"
# Examples: Qwen/Qwen2.5-1.5B-Instruct, Qwen/Qwen2.5-7B-Instruct

sudo microk8s kubectl apply -f k8s/rocket-vllm/configmap.yaml
sudo microk8s kubectl rollout restart deployment/rocket-vllm -n rocket
```

**Anthropic**:
```bash
# Edit k8s/rocket-anthropic/configmap.yaml
# Change MODEL_NAME: "claude-sonnet-4-20250514"
# Example: claude-3-7-sonnet-20250219

sudo microk8s kubectl apply -f k8s/rocket-anthropic/configmap.yaml
sudo microk8s kubectl rollout restart deployment/rocket-anthropic -n rocket
```

### Scaling Deployments

```bash
# Scale to multiple replicas (for load distribution)
sudo microk8s kubectl scale deployment/rocket-ollama -n rocket --replicas=3

# Verify scaling
sudo microk8s kubectl get pods -n rocket
```

### Updating Matrix Credentials

```bash
# Edit k8s/shared/secret.yaml
# Update token, server, user, or room

sudo microk8s kubectl apply -f k8s/shared/secret.yaml
sudo microk8s kubectl rollout restart deployment/rocket-ollama -n rocket
```

## Monitoring and Debugging

### Check Resource Usage

```bash
# Pod resource usage (requires metrics-server addon)
sudo microk8s kubectl top pods -n rocket

# Describe pod for events and status
sudo microk8s kubectl describe pod -n rocket <pod-name>

# Check resource quotas
sudo microk8s kubectl describe resourcequota -n rocket
```

### View Logs

```bash
# Ollama server logs
sudo microk8s kubectl logs -n rocket deployment/rocket-ollama -c ollama-server --tail=100 -f

# Matrix listener logs
sudo microk8s kubectl logs -n rocket deployment/rocket-ollama -c matrix-listener --tail=100 -f

# All container logs
sudo microk8s kubectl logs -n rocket deployment/rocket-ollama --all-containers=true --tail=100 -f
```

### Common Issues

#### Pod Stuck in Pending

```bash
# Check events
sudo microk8s kubectl describe pod -n rocket <pod-name>

# Common causes:
# 1. Insufficient resources → Check resource quotas
# 2. Node selector mismatch → Verify node labels
# 3. PVC not bound → Check PVC status
sudo microk8s kubectl get pvc -n rocket
```

#### Pod CrashLoopBackOff

```bash
# Check logs for errors
sudo microk8s kubectl logs -n rocket <pod-name> --previous

# Common causes:
# 1. Missing Matrix credentials → Verify secret
# 2. Model download failed → Check internet connectivity
# 3. Resource limits too low → Increase memory/CPU limits
```

#### GPU Not Detected (vLLM)

```bash
# Verify NVIDIA device plugin is running
sudo microk8s kubectl get pods -n kube-system | grep nvidia

# Check node GPU resources
sudo microk8s kubectl describe node worker-1 | grep nvidia.com/gpu
```

#### Model Download Taking Too Long

```bash
# Check download progress
sudo microk8s kubectl logs -n rocket deployment/rocket-ollama -c ollama-server -f

# Expected timeline:
# - qwen2.5:0.5b → ~2-3 minutes (~500MB)
# - qwen2.5:3b → ~10-15 minutes (~2GB)
# - Qwen/Qwen2.5-3B-Instruct (vLLM) → ~5-10 minutes (~6GB)
```

## Cleanup

### Remove Specific Deployment

```bash
# Remove Ollama deployment
sudo microk8s kubectl delete -f k8s/rocket-ollama/

# Remove vLLM deployment
sudo microk8s kubectl delete -f k8s/rocket-vllm/

# Remove Anthropic deployment
sudo microk8s kubectl delete -f k8s/rocket-anthropic/
```

### Remove All Rocket Resources

```bash
# Delete entire namespace (removes all deployments, PVCs, secrets)
sudo microk8s kubectl delete namespace rocket
```

### Preserve Data

```bash
# Backup PVC data before deletion
sudo microk8s kubectl get pvc -n rocket ollama-models -o yaml > ollama-models-backup.yaml

# Delete deployment but keep PVC
sudo microk8s kubectl delete deployment rocket-ollama -n rocket
# PVC remains, will reattach on redeploy
```

## Next Steps: Phase 3 (Ray Cluster)

Phase 3 will add:
- Ray Serve for intelligent request routing
- GPU-preferred, CPU-fallback scheduling
- Automatic model selection based on load
- Ray Dashboard for monitoring
- Distributed inference across multiple nodes

Stay tuned!

## Troubleshooting

### Can't Access Portainer

```bash
# Verify Portainer is running on worker-1
ssh debian@worker-1
sudo docker ps | grep portainer

# Check NodePort service
sudo microk8s kubectl get svc -A | grep portainer
```

### Matrix Messages Not Responding

```bash
# Check listener logs for errors
sudo microk8s kubectl logs -n rocket deployment/rocket-ollama -c matrix-listener --tail=50

# Verify Matrix credentials
sudo microk8s kubectl get secret matrix-credentials -n rocket -o yaml

# Test inference server connectivity
sudo microk8s kubectl exec -n rocket deployment/rocket-ollama -c matrix-listener -- curl http://localhost:11434/api/tags
```

### Need to Update Listener Script

The current manifests have placeholder listener scripts. To mount the actual listener script:

**Option 1**: Build custom image with script
**Option 2**: Use ConfigMap with full script content
**Option 3**: Mount from hostPath (dev only)

See deployment.yaml comments for details.

## Support

For issues, questions, or contributions, please refer to the main project documentation or contact the Aria Infrastructure team.
