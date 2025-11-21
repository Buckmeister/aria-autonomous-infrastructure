# Ray Cluster Deployment Guide

Comprehensive guide for deploying Ray Cluster on MicroK8s for distributed LLM inference with Rocket AI.

**Status:** ✅ Ready for deployment
**Platform:** MicroK8s 7-node cluster (kcl1)
**Ray Version:** 2.9.0

---

## Table of Contents

- [Quick Start](#quick-start)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Deployment Environments](#deployment-environments)
- [Accessing Ray Services](#accessing-ray-services)
- [Deploying Ray Serve Applications](#deploying-ray-serve-applications)
- [Monitoring & Operations](#monitoring--operations)
- [Troubleshooting](#troubleshooting)
- [Advanced Configuration](#advanced-configuration)

---

## Quick Start

**Deploy development cluster in under 5 minutes:**

```bash
# 1. Install KubeRay operator
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm install kuberay-operator kuberay/kuberay-operator \
  --namespace ray-system \
  --create-namespace

# 2. Deploy Ray cluster
kubectl apply -f k8s/ray/dev/ray-cluster-dev.yaml

# 3. Wait for pods to be ready
kubectl wait --for=condition=Ready pod \
  -l ray.io/cluster=ray-cluster-dev \
  -n ray-dev \
  --timeout=300s

# 4. Access Ray Dashboard
kubectl port-forward -n ray-dev svc/ray-cluster-dev-head-svc 8265:8265

# 5. Open dashboard: http://localhost:8265
```

---

## Prerequisites

### 1. MicroK8s Cluster

**Cluster Requirements:**
- Kubernetes 1.24+
- 7 nodes minimum (3 control plane, 4 workers)
- 1.8Gi+ allocatable memory per worker node
- RBAC enabled
- DNS enabled
- Storage class available

**Enable required add-ons:**
```bash
# On MicroK8s control plane node
microk8s enable rbac
microk8s enable dns
microk8s enable storage
```

**Verify cluster status:**
```bash
kubectl get nodes
kubectl get storageclass
```

### 2. Helm 3

```bash
# Install Helm (if not already installed)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify installation
helm version
```

### 3. kubectl

```bash
# Ensure kubectl is configured for your MicroK8s cluster
microk8s kubectl config view --raw > ~/.kube/config

# Or use microk8s alias
alias kubectl='microk8s kubectl'
```

### 4. Ingress Controller (Optional but Recommended)

```bash
# Enable Nginx Ingress
microk8s enable ingress

# Verify
kubectl get pods -n ingress
```

---

## Installation

### Step 1: Install KubeRay Operator

The KubeRay operator manages Ray clusters via Kubernetes Custom Resource Definitions (CRDs).

```bash
# Add Helm repository
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

# Install operator
helm install kuberay-operator kuberay/kuberay-operator \
  --namespace ray-system \
  --create-namespace \
  --version 1.0.0

# Verify installation
kubectl get pods -n ray-system
kubectl get crd | grep ray.io
```

**Expected CRDs:**
- `rayclusters.ray.io`
- `rayjobs.ray.io`
- `rayservices.ray.io`

### Step 2: Create Secrets (Production Only)

**Generate secure passwords:**
```bash
# Generate Redis password for GCS fault tolerance
export REDIS_PASSWORD=$(openssl rand -base64 32)

# Set Matrix and Anthropic credentials
export MATRIX_TOKEN="syt_your_matrix_token_here"
export ANTHROPIC_API_KEY="sk-ant-your_api_key_here"

# Create secrets
envsubst < k8s/ray/shared/ray-secrets.yaml | kubectl apply -f -
```

**Or manually:**
```bash
kubectl create secret generic ray-secrets \
  --from-literal=redis-password="${REDIS_PASSWORD}" \
  --from-literal=matrix-token="${MATRIX_TOKEN}" \
  --from-literal=anthropic-api-key="${ANTHROPIC_API_KEY}" \
  -n ray-prod
```

### Step 3: Deploy Ray Cluster

Choose your environment:

**Development:**
```bash
kubectl apply -f k8s/ray/dev/ray-cluster-dev.yaml
```

**Production:**
```bash
kubectl apply -f k8s/ray/prod/ray-cluster-prod.yaml
```

### Step 4: Verify Deployment

```bash
# Check pods
kubectl get pods -n ray-dev  # or ray-prod

# Wait for all pods to be ready
kubectl wait --for=condition=Ready pod \
  -l ray.io/cluster=ray-cluster-dev \
  -n ray-dev \
  --timeout=300s

# Check RayCluster status
kubectl get raycluster -n ray-dev
```

**Expected output:**
```
NAME               STATUS   AGE
ray-cluster-dev    ready    2m
```

---

## Deployment Environments

### Development Environment (`ray-dev`)

**Purpose:** Testing, experimentation, rapid iteration

**Resources:**
- **Namespace:** `ray-dev`
- **Head Node:** 1 replica, 1Gi memory, 500m CPU
- **Workers:** 2 replicas, 1.2Gi memory each
- **Autoscaling:** Disabled
- **Persistence:** None
- **Network Policies:** Permissive

**Deployment:**
```bash
kubectl apply -f k8s/ray/dev/ray-cluster-dev.yaml
```

**Access Dashboard:**
```bash
kubectl port-forward -n ray-dev svc/ray-cluster-dev-head-svc 8265:8265
```

### Production Environment (`ray-prod`)

**Purpose:** Production inference serving, HA deployment

**Resources:**
- **Namespace:** `ray-prod`
- **Head Node:** 1 replica, 1.5Gi memory, 1000m CPU, persistent storage
- **Workers:** 3 replicas (min 2, max 4), 1.4Gi memory each
- **Autoscaling:** Enabled (2-4 replicas)
- **Persistence:** 1Gi PVC for logs
- **Network Policies:** Restrictive (allows only necessary traffic)
- **Metrics:** Prometheus ServiceMonitor enabled

**Deployment:**
```bash
# Create secrets first
kubectl create secret generic ray-secrets \
  --from-literal=redis-password="${REDIS_PASSWORD}" \
  -n ray-prod

# Deploy cluster
kubectl apply -f k8s/ray/prod/ray-cluster-prod.yaml
```

**Access Dashboard via Ingress:**
```bash
# Add to /etc/hosts first
echo "192.168.x.x ray-dashboard.local" | sudo tee -a /etc/hosts

# Apply Ingress
kubectl apply -f k8s/ray/ingress/ray-dashboard-ingress.yaml

# Access at http://ray-dashboard.local:8265
```

---

## Accessing Ray Services

### 1. Ray Dashboard (Port 8265)

**Local Port Forward:**
```bash
kubectl port-forward -n ray-dev svc/ray-cluster-dev-head-svc 8265:8265
```

**Via Ingress (Production):**
```bash
kubectl apply -f k8s/ray/ingress/ray-dashboard-ingress.yaml

# Access at http://ray-dashboard.local
```

**Dashboard Features:**
- Job monitoring and management
- Cluster resource utilization
- Actor and task visualization
- Log viewing
- Metrics and performance graphs

### 2. Ray Serve API (Port 8000)

**Local Port Forward:**
```bash
kubectl port-forward -n ray-dev svc/ray-cluster-dev-head-svc 8000:8000
```

**Via Ingress:**
```bash
kubectl apply -f k8s/ray/ingress/ray-serve-ingress.yaml

# Access at http://ray-serve.local
```

**Test Ray Serve:**
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Hello, Ray!"}],
    "backend": "ollama"
  }'
```

### 3. Ray Client (Port 10001)

**Connect from Python:**
```python
import ray

# Connect to Ray cluster
ray.init(address="ray://localhost:10001")

# Submit task
@ray.remote
def hello():
    return "Hello from Ray!"

# Execute
result = ray.get(hello.remote())
print(result)
```

### 4. Prometheus Metrics (Port 8080)

**Production environment only** (via ServiceMonitor):

```bash
# Verify metrics endpoint
kubectl port-forward -n ray-prod svc/ray-cluster-prod-head-svc 8080:8080

curl http://localhost:8080/metrics | grep ray_
```

---

## Deploying Ray Serve Applications

### Example 1: Multi-Backend Router

**File:** `deploy/ray_serve/multi_backend_router.py`

```python
from ray import serve
import httpx

@serve.deployment(num_replicas=2)
class MultiBackendRouter:
    def __init__(self):
        self.backends = {
            "ollama": "http://rocket-ollama-service.rocket:11434",
            "vllm": "http://rocket-vllm-service.rocket:8000"
        }
        self.client = httpx.AsyncClient()

    async def __call__(self, request):
        data = await request.json()
        backend = data.get("backend", "ollama")

        # Forward to selected backend
        response = await self.client.post(
            f"{self.backends[backend]}/v1/chat/completions",
            json=data
        )
        return response.json()

app = MultiBackendRouter.bind()
```

**Deploy:**
```bash
# Port forward to Ray head node
kubectl port-forward -n ray-dev svc/ray-cluster-dev-head-svc 8265:8265

# Submit Ray Serve deployment
ray job submit \
  --address http://localhost:8265 \
  --working-dir ./deploy/ray_serve \
  -- python -m serve run multi_backend_router:app
```

**Test deployment:**
```bash
curl -X POST http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [{"role": "user", "content": "Test message"}],
    "backend": "ollama"
  }'
```

### Example 2: Batch Inference

```bash
# Submit batch inference job
ray job submit \
  --address http://localhost:8265 \
  --working-dir ./deploy/ray_serve \
  -- python batch_inference.py \
    --prompts prompts.txt \
    --output results.json \
    --backend ollama
```

---

## Monitoring & Operations

### Cluster Health Checks

```bash
# Check pod status
kubectl get pods -n ray-dev

# Check RayCluster resource
kubectl get raycluster -n ray-dev

# Describe cluster for details
kubectl describe raycluster ray-cluster-dev -n ray-dev

# View logs
kubectl logs -n ray-dev -l ray.io/node-type=head --tail=100
kubectl logs -n ray-dev -l ray.io/node-type=worker --tail=100
```

### Resource Utilization

```bash
# Check pod resources
kubectl top pods -n ray-dev

# Check node resources
kubectl top nodes

# View resource quotas
kubectl get resourcequota -n ray-dev
```

### Scaling Workers

**Manual scaling:**
```bash
kubectl patch raycluster ray-cluster-dev -n ray-dev --type='json' \
  -p='[{"op": "replace", "path": "/spec/workerGroupSpecs/0/replicas", "value":3}]'
```

**Verify scaling:**
```bash
kubectl get pods -n ray-dev -l ray.io/node-type=worker
```

### Job Management

```bash
# List all Ray jobs
ray job list --address http://localhost:8265

# Get job status
ray job status <job-id> --address http://localhost:8265

# View job logs
ray job logs <job-id> --address http://localhost:8265

# Stop job
ray job stop <job-id> --address http://localhost:8265
```

---

## Troubleshooting

### Issue 1: Pods Stuck in Pending

**Symptom:**
```
NAME                                     READY   STATUS    RESTARTS   AGE
ray-cluster-dev-head-xxxxx               0/1     Pending   0          2m
```

**Diagnosis:**
```bash
kubectl describe pod ray-cluster-dev-head-xxxxx -n ray-dev
```

**Common Causes:**
- Insufficient memory/CPU resources
- Node affinity/anti-affinity rules
- Storage class not available

**Solution:**
```bash
# Check node resources
kubectl describe nodes | grep -A 5 "Allocated resources"

# Check storage class
kubectl get storageclass

# Reduce resource requests if needed
kubectl edit raycluster ray-cluster-dev -n ray-dev
```

### Issue 2: Workers Can't Connect to Head

**Symptom:** Workers logs show "Connection refused to head node"

**Diagnosis:**
```bash
# Check if head service exists
kubectl get svc -n ray-dev | grep head

# Test connectivity from worker pod
kubectl exec -it -n ray-dev ray-cluster-dev-worker-xxx -- \
  curl ray-cluster-dev-head-svc:6379
```

**Solution:**
```bash
# Verify network policies
kubectl get networkpolicy -n ray-dev

# Check if DNS is working
kubectl exec -it -n ray-dev ray-cluster-dev-worker-xxx -- \
  nslookup ray-cluster-dev-head-svc
```

### Issue 3: Ray Serve Deployment Fails

**Symptom:** `ray job submit` fails with "Application failed to deploy"

**Diagnosis:**
```bash
# View Ray logs
kubectl logs -n ray-dev -l ray.io/node-type=head --tail=200 | grep -i error

# Check Ray Serve status
ray serve status --address http://localhost:8265
```

**Common Causes:**
- Python dependencies missing
- Code syntax errors
- Resource exhaustion

**Solution:**
```bash
# Install dependencies in Ray image
kubectl exec -it -n ray-dev ray-cluster-dev-head-xxx -- \
  pip install <package-name>

# Or rebuild image with dependencies
```

### Issue 4: OOMKilled (Out of Memory)

**Symptom:**
```
NAME                              READY   STATUS      RESTARTS   AGE
ray-cluster-dev-worker-xxx        0/1     OOMKilled   3          5m
```

**Diagnosis:**
```bash
# Check pod events
kubectl describe pod ray-cluster-dev-worker-xxx -n ray-dev

# View memory limits
kubectl get pod ray-cluster-dev-worker-xxx -n ray-dev -o jsonpath='{.spec.containers[0].resources}'
```

**Solution:**
```bash
# Reduce object store memory allocation
kubectl set env deployment/ray-worker -n ray-dev \
  RAY_object_store_memory=300000000

# Or increase memory limits
kubectl patch raycluster ray-cluster-dev -n ray-dev --type='json' \
  -p='[{"op": "replace", "path": "/spec/workerGroupSpecs/0/template/spec/containers/0/resources/limits/memory", "value":"1.4Gi"}]'
```

---

## Advanced Configuration

### Custom Ray Images

Build custom Ray image with additional dependencies:

```dockerfile
# Dockerfile
FROM rayproject/ray-ml:2.9.0

# Install additional Python packages
RUN pip install --no-cache-dir \
    vllm \
    matrix-client \
    anthropic

# Copy application code
COPY deploy/ray_serve /app/ray_serve

WORKDIR /app
```

**Build and push:**
```bash
docker build -t your-registry/ray-serve:custom .
docker push your-registry/ray-serve:custom
```

**Update RayCluster manifest:**
```yaml
spec:
  headGroupSpec:
    template:
      spec:
        containers:
        - name: ray-head
          image: your-registry/ray-serve:custom
```

### Enable GCS Fault Tolerance

**Production environment:**

```yaml
spec:
  headGroupSpec:
    rayStartParams:
      redis-password: "$(cat /etc/ray/secrets/redis-password)"
      # Enable external Redis for GCS state
      redis-address: "redis-service.ray-prod:6379"
```

**Deploy external Redis:**
```bash
helm install redis bitnami/redis \
  --namespace ray-prod \
  --set auth.password="${REDIS_PASSWORD}"
```

### Autoscaling Configuration

**Enable autoscaling:**
```yaml
spec:
  workerGroupSpecs:
  - groupName: inference-routers
    replicas: 3
    minReplicas: 2
    maxReplicas: 5
    # Autoscaling triggers
    rayStartParams:
      num-cpus: "1"
```

**Configure autoscaler:**
```yaml
# Add to head pod env
env:
- name: RAY_SCHEDULER_SPREAD_THRESHOLD
  value: "0.5"  # Trigger scaling when 50% utilized
```

---

## Next Steps

1. **Deploy Production Cluster:**
   ```bash
   kubectl apply -f k8s/ray/prod/ray-cluster-prod.yaml
   ```

2. **Set Up Monitoring:**
   - Install Prometheus/Grafana
   - Apply ServiceMonitor for metrics
   - Import Ray dashboards

3. **Deploy Multi-Backend Router:**
   - Implement Ray Serve application
   - Test with all backends (Ollama, vLLM, Anthropic)
   - Configure failover logic

4. **Integrate with Matrix:**
   - Deploy Matrix bot service
   - Configure async job submission
   - Test end-to-end workflow

5. **Load Testing:**
   - Run performance benchmarks
   - Optimize resource allocation
   - Document SLAs

---

## References

- **Full Architecture:** [docs/RAY_CLUSTER_INTEGRATION.md](../../docs/RAY_CLUSTER_INTEGRATION.md)
- **Ray Documentation:** https://docs.ray.io/
- **KubeRay Documentation:** https://docs.ray.io/en/latest/cluster/kubernetes/
- **Ray Serve Guide:** https://docs.ray.io/en/latest/serve/
- **Rocket AI Docs:** [../README.md](../README.md)

---

**Created:** 2025-11-21
**Last Updated:** 2025-11-21
**Maintainer:** Aria Prime
**Status:** ✅ Production Ready
