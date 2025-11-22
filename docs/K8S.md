# Kubernetes & Ray Cluster Reference

Quick reference for K8s and Ray operations. Commands only.

---

## Cluster: kcl1 (MicroK8s)

**Nodes:** 7 total
- Control Plane: cp-1, cp-2, cp-3 (192.168.188.51-53)
- Workers: worker-1, worker-2, worker-3, worker-4 (192.168.188.61-64)

**Version:** v1.34.1
**Status:** All nodes Ready, 50+ days uptime

---

## Quick Access

```bash
# Export kubeconfig
export KUBECONFIG=~/.aria/tools/kubernetes/config-rocket

# Or refresh from cluster
ssh debian@cp-1 "sudo /snap/bin/microk8s config" > ~/.aria/tools/kubernetes/config-rocket

# Use kmgr (auto-detects config)
kmgr status
```

---

## kmgr Tool

**Location:** ~/Development/aria-autonomous-infrastructure/bin/kmgr
**Guide:** ~/Development/aria-autonomous-infrastructure/docs/KMGR_GUIDE.md

### Essential Commands

```bash
# Cluster operations
kmgr health                    # Check cluster health
kmgr status                    # Full cluster status
kmgr nodes                     # List all nodes
kmgr pods --all               # All pods across namespaces
kmgr resources                 # Resource usage

# Ray Cluster
kmgr ray deploy dev           # Deploy dev Ray Cluster
kmgr ray status dev           # Check Ray Cluster status
kmgr ray dashboard dev        # Port-forward to dashboard
kmgr ray scale dev 5          # Scale workers to 5
kmgr ray logs dev head        # View head pod logs
kmgr ray logs dev worker      # View worker pod logs

# Deployments
kmgr deploy myapp ./manifests/
kmgr logs deployment/myapp --follow
kmgr describe pod <pod-name> -n <namespace>

# Configuration
kmgr refresh-config           # Refresh kubeconfig from cluster
```

---

## Ray Cluster Operations

### Deploy Ray Cluster

```bash
# Development cluster (1 head, 2 workers)
kubectl apply -f ~/Development/aria-autonomous-infrastructure/k8s/ray/dev/ray-cluster-dev.yaml

# Production cluster (HA configuration)
kubectl apply -f ~/Development/aria-autonomous-infrastructure/k8s/ray/prod/ray-cluster-prod.yaml
```

### Check Status

```bash
# Ray Cluster custom resource
kubectl get raycluster -n ray-dev
kubectl describe raycluster ray-cluster-dev -n ray-dev

# Pods
kubectl get pods -n ray-dev
kubectl get pods -n ray-dev -l ray.io/node-type=head
kubectl get pods -n ray-dev -l ray.io/node-type=worker

# Services
kubectl get svc -n ray-dev
```

### View Logs

```bash
# Head pod
kubectl logs -n ray-dev -l ray.io/node-type=head --follow

# Worker pods
kubectl logs -n ray-dev -l ray.io/node-type=worker --follow

# Specific pod
kubectl logs -n ray-dev <pod-name> --follow
```

### Access Ray Dashboard

```bash
# Port-forward (manual)
kubectl port-forward -n ray-dev svc/ray-cluster-dev-head-svc 8265:8265

# Or use kmgr
kmgr ray dashboard dev

# Then open: http://localhost:8265
```

### Scale Workers

```bash
# Edit RayCluster manifest
kubectl edit raycluster ray-cluster-dev -n ray-dev

# Change spec.workerGroupSpecs[0].replicas to desired count

# Or use kmgr
kmgr ray scale dev 10
```

### Delete and Recreate

```bash
# Delete
kubectl delete raycluster ray-cluster-dev -n ray-dev

# Verify deletion
kubectl get pods -n ray-dev

# Recreate
kubectl apply -f ~/Development/aria-autonomous-infrastructure/k8s/ray/dev/ray-cluster-dev.yaml
```

---

## Ray Cluster Configuration

### Dev Cluster (ray-cluster-dev.yaml)

```yaml
apiVersion: ray.io/v1
kind: RayCluster
metadata:
  name: ray-cluster-dev
  namespace: ray-dev
spec:
  rayVersion: '2.9.0'
  headGroupSpec:
    serviceType: ClusterIP
    replicas: 1
    rayStartParams:
      dashboard-host: '0.0.0.0'
      num-cpus: '0'
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray-ml:2.9.0
          ports:
          - containerPort: 6379  # Redis
          - containerPort: 8265  # Dashboard
          - containerPort: 10001 # Client
          - containerPort: 8000  # Serve
          resources:
            limits:
              cpu: "2"
              memory: "4Gi"
  workerGroupSpecs:
  - groupName: inference-routers
    replicas: 2
    minReplicas: 1
    maxReplicas: 10
    rayStartParams: {}
    template:
      spec:
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.9.0
          resources:
            limits:
              cpu: "2"
              memory: "4Gi"
```

**Location:** ~/Development/aria-autonomous-infrastructure/k8s/ray/dev/ray-cluster-dev.yaml

---

## KubeRay Operator

### Installation

```bash
# Add Helm repo
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

# Install operator
helm install kuberay-operator kuberay/kuberay-operator \
  --namespace ray-system --create-namespace

# Verify
kubectl get pods -n ray-system
kubectl get crd | grep ray
```

### CRDs

- rayclusters.ray.io
- rayjobs.ray.io
- rayservices.ray.io

### Check Operator

```bash
# Operator pod
kubectl get pods -n ray-system

# Operator logs
kubectl logs -n ray-system -l app.kubernetes.io/name=kuberay-operator --follow
```

---

## Ingress Configuration

### Ray Dashboard Ingress

```bash
# Deploy ingress
kubectl apply -f ~/Development/aria-autonomous-infrastructure/k8s/ingress/ray-dashboard-ingress.yaml

# Check ingress
kubectl get ingress -n ray-dev
```

### Ray Serve API Ingress

```bash
# Deploy ingress
kubectl apply -f ~/Development/aria-autonomous-infrastructure/k8s/ingress/ray-serve-ingress.yaml

# Check ingress
kubectl get ingress -n ray-dev
```

---

## Common Kubernetes Operations

### Namespaces

```bash
# Create namespace
kubectl create namespace ray-dev

# List namespaces
kubectl get namespaces

# Set default namespace
kubectl config set-context --current --namespace=ray-dev
```

### Pods

```bash
# All pods in namespace
kubectl get pods -n ray-dev

# All pods across all namespaces
kubectl get pods -A

# Describe pod (troubleshooting)
kubectl describe pod <pod-name> -n ray-dev

# Execute command in pod
kubectl exec -it <pod-name> -n ray-dev -- /bin/bash

# Copy files to/from pod
kubectl cp <local-file> <pod-name>:/path -n ray-dev
kubectl cp <pod-name>:/path <local-file> -n ray-dev
```

### Logs

```bash
# Recent logs
kubectl logs <pod-name> -n ray-dev

# Follow logs
kubectl logs <pod-name> -n ray-dev --follow

# Previous pod logs (if crashed)
kubectl logs <pod-name> -n ray-dev --previous

# Multiple pods (by label)
kubectl logs -n ray-dev -l ray.io/node-type=head --follow
```

### Resources

```bash
# Deployments
kubectl get deployments -n ray-dev
kubectl describe deployment <name> -n ray-dev

# Services
kubectl get svc -n ray-dev
kubectl describe svc <name> -n ray-dev

# ConfigMaps
kubectl get configmap -n ray-dev
kubectl describe configmap <name> -n ray-dev

# Secrets
kubectl get secrets -n ray-dev
```

### Events

```bash
# Recent events in namespace
kubectl get events -n ray-dev --sort-by='.lastTimestamp'

# All events
kubectl get events -A --sort-by='.lastTimestamp'

# Watch events
kubectl get events -n ray-dev --watch
```

---

## Troubleshooting

### Pod Stuck in ContainerCreating

```bash
# Describe pod to see events
kubectl describe pod <pod-name> -n ray-dev

# Check image pull
kubectl get events -n ray-dev | grep <pod-name>

# Common causes:
# - Image pull in progress (wait)
# - Image pull failed (check image name/tag)
# - Volume mount issues (check PVC)
```

### Pod Stuck in Init:0/1

```bash
# Check init container logs
kubectl logs <pod-name> -n ray-dev -c <init-container-name>

# Ray worker init containers wait for head pod
# Verify head pod is Running
kubectl get pods -n ray-dev -l ray.io/node-type=head
```

### Pod in ContainerStatusUnknown

```bash
# This usually means pod is stuck/stale
# Solution: Delete and let K8s recreate

kubectl delete pod <pod-name> -n ray-dev

# Or delete entire RayCluster
kubectl delete raycluster ray-cluster-dev -n ray-dev
kubectl apply -f k8s/ray/dev/ray-cluster-dev.yaml
```

### Image Pull Slow

```bash
# Ray ML image is ~3-4GB, takes 5-10 minutes
# Check pull progress
kubectl describe pod <pod-name> -n ray-dev | grep -A 10 Events

# Images are cached after first pull
# Subsequent deployments will be much faster
```

### Resource Limits

```bash
# Check node resources
kubectl top nodes

# Check pod resources
kubectl top pods -n ray-dev

# Describe node to see allocations
kubectl describe node worker-1
```

---

## Manifest Locations

```
~/Development/aria-autonomous-infrastructure/k8s/
├── ray/
│   ├── dev/
│   │   └── ray-cluster-dev.yaml
│   ├── prod/
│   │   └── ray-cluster-prod.yaml
│   └── README.md
├── ingress/
│   ├── ray-dashboard-ingress.yaml
│   └── ray-serve-ingress.yaml
└── overlays/
    └── README.md
```

---

## Integration with Rocket

**Future:** Deploy Rocket backends on Kubernetes
- Ollama pods (CPU-optimized)
- vLLM pods (GPU-accelerated)
- Anthropic adapter pods
- Ray Serve for intelligent routing

**Benefits:**
- Auto-scaling based on Matrix traffic
- High availability (pod restarts)
- Resource sharing across Aria instances
- Centralized monitoring

---

## Related Documentation
- [DEPLOY.md](DEPLOY.md) - Rocket deployment
- [KMGR_GUIDE.md](KMGR_GUIDE.md) - Complete kmgr reference
- [REFERENCE.md](REFERENCE.md) - Hostnames, IPs, credentials

**Last Updated:** 2025-11-22
**Maintained by:** Aria Prime & Nova & Proxima
