# Ray Cluster + Rocket AI Integration Architecture

**Status:** Design Phase
**Created:** 2025-11-21
**Target Platform:** MicroK8s 7-node cluster (kcl1)

---

## Executive Summary

This document outlines the architecture for integrating Ray Cluster with the Rocket AI deployment system to enable:

- **Distributed LLM Inference** across multiple backends
- **Intelligent Load Balancing** via Ray Serve
- **Auto-scaling** based on inference demand
- **Unified API Gateway** for all Rocket backends
- **Fault-tolerant** execution with automatic failover

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Infrastructure Analysis](#infrastructure-analysis)
3. [Ray Cluster Design](#ray-cluster-design)
4. [Integration Patterns](#integration-patterns)
5. [Deployment Strategy](#deployment-strategy)
6. [Resource Allocation](#resource-allocation)
7. [Networking & Services](#networking--services)
8. [Multi-Environment Setup](#multi-environment-setup)
9. [Implementation Roadmap](#implementation-roadmap)
10. [Testing & Validation](#testing--validation)

---

## Architecture Overview

### High-Level Design

```
┌─────────────────────────────────────────────────────────────┐
│                    Matrix Communication Layer                │
│                  (Message Bus & Job Coordination)            │
└─────────────────────────────────────────────────────────────┘
                              │
                              ↓
┌─────────────────────────────────────────────────────────────┐
│                    Ray Serve API Gateway                      │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  Multi-Backend Router                                │  │
│  │  - Request batching & dynamic request handling       │  │
│  │  - Load balancing across inference backends          │  │
│  │  - Health checking & automatic failover              │  │
│  │  - Metrics collection & monitoring                   │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
         │              │              │              │
         ↓              ↓              ↓              ↓
    ┌────────┐    ┌────────┐    ┌────────┐    ┌────────┐
    │ Ollama │    │ vLLM   │    │Anthropic│   │LM Studio│
    │ Rocket │    │ Rocket │    │  API    │   │ Rocket  │
    │Instance│    │Instance│    │ Adapter │   │ Instance│
    └────────┘    └────────┘    └────────┘    └────────┘
    MicroK8s       MicroK8s      Cloud         Remote Host
    Pod            Pod           Service       (wks-bckx01)
```

### Key Components

1. **Ray Cluster (on MicroK8s)**
   - Head node: Cluster coordination, GCS, dashboard
   - Worker nodes: Task execution, inference routing
   - Object Store: Distributed memory for model weights (optional)

2. **Ray Serve**
   - HTTP API gateway (port 8000)
   - Multi-backend router deployment
   - Dynamic batching for throughput
   - Auto-scaling replicas

3. **Rocket Backends**
   - Ollama: CPU-optimized inference (K8s pods)
   - vLLM: GPU-accelerated inference (K8s pods or remote)
   - Anthropic: Cloud API adapter (K8s deployment)
   - LM Studio: External hybrid service (wks-bckx01)

4. **Matrix Integration**
   - Async job submission from Matrix rooms
   - Progress tracking via Matrix messages
   - Result delivery to Matrix channels

---

## Infrastructure Analysis

### Current MicroK8s Cluster (kcl1)

**Cluster Topology:**
- Control Plane: 3 nodes (kcl1-cp-1, kcl1-cp-2, kcl1-cp-3)
- Workers: 4 nodes (kcl1-worker-1, kcl1-worker-2, kcl1-worker-3, kcl1-worker-4)
- Hypervisor: XCP-NG on 5-host cluster (opt-bck01/02/03, lat-bck04, xcp-ng-z440)

**Resource Constraints:**
- **Memory per node:** ~1.8Gi allocatable
- **CPU per node:** Variable (likely 2-4 cores)
- **Network:** Internal 192.168.x.x network
- **Storage:** NFS shared storage available

**Existing Services:**
- Portainer UI (worker-1:30779)
- Ingress controller (Nginx)
- Existing Rocket Ollama deployments

### Resource Availability Assessment

**Memory Budget per Node (1.8Gi total):**
```
OS + K8s:        ~400Mi
Existing pods:   ~200Mi (variable)
Available:       ~1.2Gi per node
```

**Recommended Ray Allocation:**
```
Head node:       1Gi    (GCS + Dashboard + Scheduler)
Worker node:     1.2Gi  (Raylet + Object Store + Python workers)
```

---

## Ray Cluster Design

### Design Principles

1. **Conservative Resource Allocation:** Respect 1.8Gi memory limits
2. **External Inference Backends:** Use Ray for routing, not model hosting
3. **Horizontal Scaling:** Add workers incrementally as needed
4. **Fault Tolerance:** Enable GCS fault tolerance for production

### Ray Cluster Configuration

#### Development Environment

```yaml
apiVersion: ray.io/v1alpha1
kind: RayCluster
metadata:
  name: ray-cluster-dev
  namespace: ray-dev
spec:
  rayVersion: "2.9.0"

  # Head node - minimal resources
  headGroupSpec:
    replicas: 1
    rayStartParams:
      dashboard-host: "0.0.0.0"
      num-cpus: "0"  # Don't schedule tasks on head
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray-ml:2.9.0
          resources:
            limits:
              cpu: 500m
              memory: 1Gi
            requests:
              cpu: 500m
              memory: 1Gi
          ports:
          - containerPort: 6379   # Redis/GCS
            name: gcs
          - containerPort: 8265   # Dashboard
            name: dashboard
          - containerPort: 10001  # Ray Client
            name: client
          - containerPort: 8000   # Ray Serve
            name: serve

  # Worker group - inference routers
  workerGroupSpecs:
  - groupName: inference-routers
    replicas: 2
    minReplicas: 1
    maxReplicas: 3
    rayStartParams:
      num-cpus: "1"
    template:
      spec:
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.9.0
          resources:
            limits:
              cpu: 500m
              memory: 1.2Gi
            requests:
              cpu: 500m
              memory: 1.2Gi
```

#### Production Environment

```yaml
apiVersion: ray.io/v1alpha1
kind: RayCluster
metadata:
  name: ray-cluster-prod
  namespace: ray-prod
spec:
  rayVersion: "2.9.0"

  headGroupSpec:
    replicas: 1
    rayStartParams:
      dashboard-host: "0.0.0.0"
      num-cpus: "0"
      # Enable GCS fault tolerance
      redis-password: "${REDIS_PASSWORD}"  # From K8s secret
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray-ml:2.9.0
          resources:
            limits:
              cpu: 1000m
              memory: 1.5Gi
            requests:
              cpu: 1000m
              memory: 1.5Gi
          ports:
          - containerPort: 6379
          - containerPort: 8265
          - containerPort: 10001
          - containerPort: 8000
          - containerPort: 8080   # Metrics
          volumeMounts:
          - name: ray-logs
            mountPath: /tmp/ray
        volumes:
        - name: ray-logs
          persistentVolumeClaim:
            claimName: ray-head-logs

  workerGroupSpecs:
  - groupName: inference-routers
    replicas: 3
    minReplicas: 2
    maxReplicas: 4
    rayStartParams:
      num-cpus: "1"
    template:
      spec:
        containers:
        - name: ray-worker
          image: rayproject/ray-ml:2.9.0
          resources:
            limits:
              cpu: 1000m
              memory: 1.4Gi
            requests:
              cpu: 1000m
              memory: 1.4Gi
```

---

## Integration Patterns

### Pattern 1: Ray Serve as API Gateway

**Use Case:** Unified HTTP endpoint for all inference backends

**Implementation:**

```python
# deploy/ray_serve/multi_backend_router.py

from ray import serve
import httpx
import asyncio
from typing import Dict, Any

@serve.deployment(
    num_replicas=2,
    max_concurrent_queries=10,
    autoscaling_config={
        "min_replicas": 1,
        "max_replicas": 4,
        "target_num_ongoing_requests_per_replica": 5
    }
)
class MultiBackendRouter:
    """
    Intelligent router for multiple Rocket inference backends.

    Backends:
    - ollama: Local Kubernetes pod (rocket-ollama-service:11434)
    - vllm: GPU-accelerated pod (rocket-vllm-service:8000)
    - anthropic: Cloud API adapter (rocket-anthropic-service:8000)
    - lm-studio: External service (wks-bckx01:1234)
    """

    def __init__(self):
        self.backends = {
            "ollama": "http://rocket-ollama-service.rocket:11434",
            "vllm": "http://rocket-vllm-service.rocket:8000",
            "anthropic": "http://rocket-anthropic-service.rocket:8000",
            "lm-studio": "http://wks-bckx01:1234"
        }

        self.client = httpx.AsyncClient(timeout=300.0)
        self.health_status = {k: True for k in self.backends.keys()}

    async def health_check(self, backend: str) -> bool:
        """Check if backend is healthy."""
        try:
            url = self.backends[backend]
            if "anthropic" in backend:
                # Anthropic doesn't have health endpoint, assume healthy
                return True

            health_url = f"{url}/health" if "vllm" in backend else f"{url}/api/tags"
            response = await self.client.get(health_url, timeout=5.0)
            return response.status_code == 200
        except:
            return False

    async def select_backend(self, requested: str = None) -> str:
        """
        Select healthy backend with fallback.

        Priority:
        1. Requested backend (if specified and healthy)
        2. vLLM (if healthy, fastest)
        3. Ollama (if healthy, reliable)
        4. LM Studio (if healthy, external)
        5. Anthropic (cloud fallback)
        """
        if requested and requested in self.backends:
            if await self.health_check(requested):
                return requested

        # Fallback cascade
        for backend in ["vllm", "ollama", "lm-studio", "anthropic"]:
            if await self.health_check(backend):
                return backend

        raise RuntimeError("No healthy backends available")

    async def __call__(self, request: serve.Request) -> Dict[str, Any]:
        """
        Handle inference request with automatic backend selection.

        Request format (OpenAI-compatible):
        {
            "model": "qwen2.5:0.5b",  # Optional: backend hint
            "messages": [...],
            "backend": "ollama",      # Optional: explicit backend
            "temperature": 0.7,
            "max_tokens": 256
        }
        """
        data = await request.json()

        # Extract backend preference
        requested_backend = data.pop("backend", None)

        # Select backend with fallback
        selected_backend = await self.select_backend(requested_backend)
        backend_url = self.backends[selected_backend]

        # Forward request to selected backend
        try:
            # Convert to backend-specific format if needed
            if selected_backend == "ollama":
                endpoint = f"{backend_url}/v1/chat/completions"
            elif selected_backend == "vllm":
                endpoint = f"{backend_url}/v1/chat/completions"
            elif selected_backend == "lm-studio":
                endpoint = f"{backend_url}/v1/chat/completions"
            elif selected_backend == "anthropic":
                endpoint = f"{backend_url}/v1/chat/completions"

            response = await self.client.post(endpoint, json=data)
            response.raise_for_status()

            result = response.json()
            result["_backend"] = selected_backend  # Add metadata
            return result

        except Exception as e:
            # Mark backend as unhealthy and retry with fallback
            self.health_status[selected_backend] = False

            # Try one more time with different backend
            fallback_backend = await self.select_backend()
            if fallback_backend != selected_backend:
                return await self.__call__(request)

            raise RuntimeError(f"Inference failed: {str(e)}")

# Deployment entry point
app = MultiBackendRouter.bind()
```

**Deployment:**

```bash
# Deploy Ray Serve application
ray job submit --address http://ray-cluster-dev-head-svc:8265 \
  --working-dir ./deploy/ray_serve \
  -- python -m serve run multi_backend_router:app
```

### Pattern 2: Distributed Batch Inference

**Use Case:** Process large batches of prompts in parallel

**Implementation:**

```python
# deploy/ray_serve/batch_inference.py

import ray
from ray import serve
from typing import List, Dict

@ray.remote
class InferenceTask:
    """Single inference task executed on Ray worker."""

    def __init__(self, backend_url: str):
        self.backend_url = backend_url

    async def execute(self, prompt: str, params: dict) -> dict:
        import httpx

        client = httpx.AsyncClient()
        response = await client.post(
            f"{self.backend_url}/v1/chat/completions",
            json={
                "messages": [{"role": "user", "content": prompt}],
                **params
            }
        )
        return response.json()

@serve.deployment
class BatchInferenceAPI:
    """
    Batch inference API for processing multiple prompts in parallel.
    """

    async def __call__(self, request: serve.Request) -> List[Dict]:
        data = await request.json()
        prompts = data["prompts"]  # List of prompts
        backend = data.get("backend", "ollama")
        params = data.get("params", {})

        # Determine backend URL
        backend_urls = {
            "ollama": "http://rocket-ollama-service.rocket:11434",
            "vllm": "http://rocket-vllm-service.rocket:8000",
        }
        backend_url = backend_urls[backend]

        # Create Ray tasks for parallel execution
        tasks = [
            InferenceTask.remote(backend_url)
            for _ in prompts
        ]

        # Execute all tasks in parallel
        futures = [
            task.execute.remote(prompt, params)
            for task, prompt in zip(tasks, prompts)
        ]

        # Wait for all results
        results = await asyncio.gather(*[ray.get(f) for f in futures])

        return {
            "results": results,
            "count": len(results),
            "backend": backend
        }

app = BatchInferenceAPI.bind()
```

### Pattern 3: Matrix Integration

**Use Case:** Submit inference jobs from Matrix, receive results in Matrix

**Implementation:**

```python
# deploy/ray_serve/matrix_integration.py

from ray import serve
import asyncio
from matrix_client import MatrixClient

@serve.deployment
class MatrixInferenceBot:
    """
    Matrix-integrated inference bot.
    Listens to Matrix room, processes requests, sends responses.
    """

    def __init__(self):
        self.matrix_client = MatrixClient(
            server="http://srv1:8008",
            user_id="@ray-bot:srv1.local",
            access_token="..."  # From K8s secret
        )

        self.router = serve.get_deployment("MultiBackendRouter").get_handle()

    async def process_matrix_message(self, room_id: str, message: str):
        """Process incoming Matrix message as inference request."""

        # Parse message for inference request
        if not message.startswith("!infer"):
            return

        prompt = message.replace("!infer", "").strip()

        # Submit to Ray Serve router
        result = await self.router.remote({
            "messages": [{"role": "user", "content": prompt}],
            "backend": "ollama"  # Default
        })

        # Send response back to Matrix
        response_text = result["choices"][0]["message"]["content"]
        backend_used = result["_backend"]

        await self.matrix_client.send_message(
            room_id,
            f"[{backend_used}] {response_text}"
        )

    async def start_listening(self):
        """Start listening to Matrix room for requests."""
        await self.matrix_client.listen(
            room_id="!UCEurIvKNNMvYlrntC:srv1.local",
            callback=self.process_matrix_message
        )

app = MatrixInferenceBot.bind()
```

---

## Deployment Strategy

### Phase 1: Cluster Setup (Week 1)

**Objectives:**
- Install KubeRay operator on MicroK8s
- Deploy minimal Ray cluster (dev environment)
- Verify Ray Dashboard accessibility
- Test basic Ray job submission

**Tasks:**
1. Install KubeRay operator via Helm
2. Create `ray-dev` namespace
3. Deploy development RayCluster manifest
4. Port-forward to Ray Dashboard (8265)
5. Submit test job

### Phase 2: Ray Serve Deployment (Week 1-2)

**Objectives:**
- Deploy multi-backend router
- Integrate with existing Rocket Ollama pods
- Test inference routing and failover
- Benchmark performance vs direct calls

**Tasks:**
1. Create Ray Serve application code
2. Package with dependencies (httpx, etc.)
3. Deploy via `ray job submit`
4. Test OpenAI-compatible API
5. Measure latency and throughput

### Phase 3: Multi-Backend Integration (Week 2-3)

**Objectives:**
- Integrate vLLM backend
- Add Anthropic API adapter
- Connect LM Studio external service
- Implement health checking and failover

**Tasks:**
1. Deploy vLLM Rocket instance to K8s
2. Create Anthropic API adapter service
3. Configure network access to LM Studio
4. Test multi-backend routing logic
5. Validate failover scenarios

### Phase 4: Production Hardening (Week 3-4)

**Objectives:**
- Enable GCS fault tolerance
- Add persistent volumes for logs
- Configure auto-scaling
- Set up Prometheus metrics
- Deploy to production namespace

**Tasks:**
1. Create `ray-prod` namespace
2. Deploy production RayCluster with HA
3. Configure PersistentVolumeClaims
4. Set up ServiceMonitor for Prometheus
5. Load testing and optimization

---

## Resource Allocation

### Recommended Node Assignment

**Scenario: 7-node MicroK8s cluster**

```
Control Plane Nodes (cp-1, cp-2, cp-3):
  - Kubernetes control plane services only
  - No Ray workloads scheduled

Worker Node 1:
  - Ray Head Node (1Gi memory)
  - Small utility pods

Worker Node 2:
  - Ray Worker 1 (1.2Gi memory)
  - Rocket Ollama Pod (1.2Gi memory) [if co-located]

Worker Node 3:
  - Ray Worker 2 (1.2Gi memory)
  - Rocket vLLM Pod (GPU if available)

Worker Node 4:
  - Ray Worker 3 (1.2Gi memory)
  - Rocket Anthropic Adapter (256Mi)
```

### Memory Budget Summary

**Per Worker Node (1.8Gi total):**
```
Kubernetes (kubelet, kube-proxy):  ~300Mi
Container runtime overhead:        ~100Mi
Ray Worker container:              1.2Gi
Available for Ray tasks:           ~200Mi
```

**Ray Worker Internal Allocation (1.2Gi):**
```
Python process (Raylet):           ~400Mi
Object Store (30% by default):     ~360Mi
Task execution memory:             ~440Mi
```

---

## Networking & Services

### Service Exposure

```yaml
---
apiVersion: v1
kind: Service
metadata:
  name: ray-cluster-dev-head-svc
  namespace: ray-dev
spec:
  type: ClusterIP
  selector:
    ray.io/cluster: ray-cluster-dev
    ray.io/node-type: head
  ports:
  - name: gcs
    port: 6379
    targetPort: 6379
  - name: dashboard
    port: 8265
    targetPort: 8265
  - name: client
    port: 10001
    targetPort: 10001
  - name: serve
    port: 8000
    targetPort: 8000
  - name: metrics
    port: 8080
    targetPort: 8080
```

### Ingress for Ray Dashboard

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ray-dashboard
  namespace: ray-dev
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx
  rules:
  - host: ray-dashboard.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ray-cluster-dev-head-svc
            port:
              number: 8265
```

### Ingress for Ray Serve API

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: ray-serve-api
  namespace: ray-dev
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
    nginx.ingress.kubernetes.io/proxy-body-size: "100m"
spec:
  ingressClassName: nginx
  rules:
  - host: ray-serve.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: ray-cluster-dev-head-svc
            port:
              number: 8000
```

---

## Multi-Environment Setup

### Development Environment

**Namespace:** `ray-dev`
**Purpose:** Testing, development, experimentation
**Resources:**
- Head: 1Gi memory, 500m CPU
- Workers: 2 replicas, 1.2Gi memory each
- No persistent storage
- Autoscaling disabled

### Staging Environment

**Namespace:** `ray-staging`
**Purpose:** Pre-production validation, load testing
**Resources:**
- Head: 1.2Gi memory, 750m CPU
- Workers: 3 replicas (min 2, max 4), 1.2Gi memory each
- Persistent logs: 500Mi PVC
- Autoscaling enabled

### Production Environment

**Namespace:** `ray-prod`
**Purpose:** Production inference serving
**Resources:**
- Head: 1.5Gi memory, 1000m CPU, HA mode
- Workers: 3 replicas (min 2, max 4), 1.4Gi memory each
- Persistent logs: 1Gi PVC
- Autoscaling enabled
- Prometheus metrics enabled

---

## Implementation Roadmap

### Quick Start (1-2 hours)

✅ **Phase 1A: KubeRay Operator Installation**

```bash
# 1. Add KubeRay Helm repo
helm repo add kuberay https://ray-project.github.io/kuberay-helm/
helm repo update

# 2. Install operator in ray-system namespace
helm install kuberay-operator kuberay/kuberay-operator \
  --namespace ray-system \
  --create-namespace \
  --version 1.0.0

# 3. Verify CRDs installed
kubectl get crd | grep ray.io

# Expected output:
# rayclusters.ray.io
# rayjobs.ray.io
# rayservices.ray.io
```

✅ **Phase 1B: Deploy Development Ray Cluster**

```bash
# 1. Create ray-dev namespace
kubectl create namespace ray-dev

# 2. Deploy minimal cluster
kubectl apply -f k8s/ray/dev/ray-cluster-dev.yaml

# 3. Wait for pods
kubectl wait --for=condition=Ready pod -l ray.io/cluster=ray-cluster-dev -n ray-dev --timeout=300s

# 4. Port-forward to dashboard
kubectl port-forward -n ray-dev svc/ray-cluster-dev-head-svc 8265:8265

# 5. Access dashboard at http://localhost:8265
```

✅ **Phase 1C: Test Basic Functionality**

```bash
# Submit test job
ray job submit \
  --address http://localhost:8265 \
  -- python -c "import ray; ray.init(); print(f'Ray cluster has {ray.cluster_resources()} resources')"

# Expected output:
# Ray cluster has {'CPU': 2.0, 'memory': 2400000000, 'node:...' ...}
```

### Week 1: Core Infrastructure

**Days 1-2: Ray Cluster Setup**
- ✅ KubeRay operator installation
- ✅ Dev cluster deployment
- ✅ Dashboard access verification
- Test basic Ray job submission
- Document cluster access patterns

**Days 3-4: Ray Serve Basics**
- Create simple Ray Serve deployment
- Test HTTP endpoint
- Implement health check endpoint
- Test scaling behavior

**Days 5-7: Ollama Integration**
- Deploy MultiBackendRouter with Ollama only
- Test inference routing
- Benchmark latency vs direct Ollama calls
- Implement error handling

### Week 2: Multi-Backend Integration

**Days 1-3: vLLM Backend**
- Deploy vLLM Rocket instance
- Add vLLM to router configuration
- Test GPU vs CPU routing
- Implement backend selection logic

**Days 4-5: External Backends**
- Add LM Studio connection
- Add Anthropic API adapter
- Test cross-backend failover
- Benchmark multi-backend performance

**Days 6-7: Health & Monitoring**
- Implement health check system
- Add circuit breaker pattern
- Deploy Prometheus metrics
- Create Grafana dashboards

### Week 3: Production Features

**Days 1-2: Fault Tolerance**
- Enable GCS fault tolerance
- Add persistent storage
- Test head node recovery
- Document disaster recovery

**Days 3-4: Auto-scaling**
- Configure HPA for Ray workers
- Test scaling triggers
- Optimize scaling parameters
- Document scaling behavior

**Days 5-7: Matrix Integration**
- Implement Matrix bot
- Test async job submission
- Add progress tracking
- Deploy production instance

### Week 4: Production Deployment

**Days 1-2: Staging Validation**
- Deploy to ray-staging
- Load testing with realistic traffic
- Performance tuning
- Security hardening

**Days 3-4: Production Rollout**
- Deploy to ray-prod
- Blue-green deployment strategy
- Monitor metrics and logs
- Update documentation

**Days 5-7: Optimization & Documentation**
- Performance optimization
- Cost analysis
- Complete documentation
- Team training

---

## Testing & Validation

### Unit Tests

```python
# tests/test_multi_backend_router.py

import pytest
from unittest.mock import Mock, AsyncMock
from ray_serve.multi_backend_router import MultiBackendRouter

@pytest.mark.asyncio
async def test_backend_selection():
    """Test backend selection with fallback."""
    router = MultiBackendRouter()

    # Mock health checks
    router.health_check = AsyncMock(side_effect=[
        False,  # vLLM unhealthy
        True,   # Ollama healthy
    ])

    backend = await router.select_backend("vllm")
    assert backend == "ollama"  # Fallback to Ollama

@pytest.mark.asyncio
async def test_inference_request():
    """Test full inference flow."""
    router = MultiBackendRouter()

    # Mock request
    mock_request = Mock()
    mock_request.json = AsyncMock(return_value={
        "messages": [{"role": "user", "content": "Hello"}],
        "backend": "ollama"
    })

    # Mock client response
    router.client.post = AsyncMock(return_value=Mock(
        status_code=200,
        json=lambda: {"choices": [{"message": {"content": "Hi!"}}]}
    ))

    result = await router(mock_request)
    assert result["_backend"] == "ollama"
    assert "choices" in result
```

### Integration Tests

```bash
# tests/integration/test_ray_serve.sh

#!/bin/bash
set -e

echo "Testing Ray Serve multi-backend router..."

# 1. Test Ollama backend
curl -X POST http://ray-serve.local/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "backend": "ollama",
    "messages": [{"role": "user", "content": "Hello"}],
    "temperature": 0.7
  }'

# 2. Test vLLM backend
curl -X POST http://ray-serve.local/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "backend": "vllm",
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# 3. Test automatic failover
# (stop Ollama pod and verify fallback to vLLM)
kubectl scale deployment rocket-ollama -n rocket --replicas=0

curl -X POST http://ray-serve.local/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "backend": "ollama",
    "messages": [{"role": "user", "content": "Hello"}]
  }'

# Should automatically route to vLLM
kubectl scale deployment rocket-ollama -n rocket --replicas=1
```

### Load Testing

```python
# tests/load/locustfile.py

from locust import HttpUser, task, between

class InferenceUser(HttpUser):
    wait_time = between(1, 3)

    @task
    def inference_request(self):
        self.client.post("/v1/chat/completions", json={
            "messages": [{"role": "user", "content": "Hello, how are you?"}],
            "backend": "ollama",
            "temperature": 0.7,
            "max_tokens": 50
        })
```

```bash
# Run load test
locust -f tests/load/locustfile.py \
  --host http://ray-serve.local \
  --users 10 \
  --spawn-rate 2 \
  --run-time 5m
```

### Performance Benchmarks

**Target Metrics:**

| Metric | Target | Measurement |
|--------|--------|-------------|
| Latency (p50) | < 500ms | Time to first token |
| Latency (p95) | < 2s | Time to first token |
| Throughput | > 10 req/s | Concurrent requests |
| Error Rate | < 1% | Failed requests |
| Failover Time | < 5s | Backend failure to recovery |
| Memory Usage | < 1.5Gi | Per worker pod |

---

## Monitoring & Observability

### Prometheus Metrics

```yaml
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: ray-cluster
  namespace: ray-prod
spec:
  selector:
    matchLabels:
      ray.io/cluster: ray-cluster-prod
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Key Metrics to Monitor

1. **Ray Cluster Health:**
   - `ray_node_alive`: Number of alive nodes
   - `ray_gcs_memory_mb`: GCS memory usage
   - `ray_cluster_active_tasks`: Active tasks count

2. **Ray Serve Performance:**
   - `ray_serve_deployment_request_counter`: Request count per deployment
   - `ray_serve_deployment_processing_latency_ms`: Latency histogram
   - `ray_serve_deployment_error_counter`: Error count

3. **Backend Health:**
   - `backend_health_status`: Per-backend health (custom metric)
   - `backend_request_count`: Requests routed to each backend
   - `backend_error_rate`: Errors per backend

### Grafana Dashboard

```json
{
  "dashboard": {
    "title": "Ray Serve - Multi-Backend Inference",
    "panels": [
      {
        "title": "Request Rate",
        "targets": [
          {
            "expr": "rate(ray_serve_deployment_request_counter[5m])"
          }
        ]
      },
      {
        "title": "Latency (p50, p95, p99)",
        "targets": [
          {
            "expr": "histogram_quantile(0.50, ray_serve_deployment_processing_latency_ms)"
          },
          {
            "expr": "histogram_quantile(0.95, ray_serve_deployment_processing_latency_ms)"
          },
          {
            "expr": "histogram_quantile(0.99, ray_serve_deployment_processing_latency_ms)"
          }
        ]
      },
      {
        "title": "Backend Health Status",
        "targets": [
          {
            "expr": "backend_health_status"
          }
        ]
      }
    ]
  }
}
```

---

## Cost Analysis

### Resource Costs

**Development Environment:**
```
Ray Head:      1Gi memory × 1 = 1Gi
Ray Workers:   1.2Gi × 2 = 2.4Gi
Total:         3.4Gi / 12.6Gi available = 27% cluster utilization
```

**Production Environment:**
```
Ray Head:      1.5Gi × 1 = 1.5Gi
Ray Workers:   1.4Gi × 3 = 4.2Gi
Rocket Pods:   ~2Gi (existing)
Total:         7.7Gi / 12.6Gi = 61% utilization
```

**Conclusion:** Fits comfortably within cluster capacity with room for scaling.

---

## Security Considerations

### Network Policies

```yaml
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: ray-cluster-network-policy
  namespace: ray-prod
spec:
  podSelector:
    matchLabels:
      ray.io/cluster: ray-cluster-prod
  policyTypes:
  - Ingress
  - Egress
  ingress:
  # Allow from Ingress controller
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress
    ports:
    - protocol: TCP
      port: 8000
  # Allow from Rocket pods
  - from:
    - namespaceSelector:
        matchLabels:
          name: rocket
    ports:
    - protocol: TCP
      port: 8000
  egress:
  # Allow to Rocket services
  - to:
    - namespaceSelector:
        matchLabels:
          name: rocket
    ports:
    - protocol: TCP
      port: 11434  # Ollama
    - protocol: TCP
      port: 8000   # vLLM
  # Allow DNS
  - to:
    - namespaceSelector:
        matchLabels:
          name: kube-system
    ports:
    - protocol: UDP
      port: 53
```

### Secrets Management

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: ray-secrets
  namespace: ray-prod
type: Opaque
stringData:
  redis-password: "${REDIS_PASSWORD}"  # GCS password
  matrix-token: "${MATRIX_ACCESS_TOKEN}"  # Matrix bot token
  anthropic-api-key: "${ANTHROPIC_API_KEY}"  # Anthropic API
```

---

## Troubleshooting Guide

### Common Issues

#### 1. Pod OOMKilled

**Symptom:** Ray worker pods restarted due to OOM
**Cause:** Memory limit too low for workload
**Solution:**
```bash
# Reduce object store percentage
kubectl set env deployment/ray-worker -n ray-dev RAY_object_store_memory=200000000

# Or increase memory limit
kubectl patch raycluster ray-cluster-dev -n ray-dev --type='json' \
  -p='[{"op": "replace", "path": "/spec/workerGroupSpecs/0/template/spec/containers/0/resources/limits/memory", "value":"1.4Gi"}]'
```

#### 2. GCS Connection Timeout

**Symptom:** Workers can't connect to head node
**Cause:** Network policy or service misconfiguration
**Solution:**
```bash
# Check service
kubectl get svc -n ray-dev | grep head

# Test connectivity from worker pod
kubectl exec -it -n ray-dev ray-cluster-dev-worker-xxx -- curl ray-cluster-dev-head-svc:6379
```

#### 3. Slow Inference

**Symptom:** High latency on inference requests
**Cause:** Backend overload or network bottleneck
**Solution:**
```bash
# Scale Ray workers
kubectl patch raycluster ray-cluster-dev -n ray-dev --type='json' \
  -p='[{"op": "replace", "path": "/spec/workerGroupSpecs/0/replicas", "value":3}]'

# Check backend pod metrics
kubectl top pod -n rocket
```

---

## Future Enhancements

### Phase 2 Features (3-6 months)

1. **Advanced Batching:**
   - Continuous batching for LLM generation
   - Dynamic batch size optimization
   - Multi-model batching

2. **Model Caching:**
   - Distributed model weight cache
   - Warm model pool management
   - Predictive preloading

3. **Multi-Cluster Federation:**
   - Deploy Ray across multiple K8s clusters
   - Cross-cluster job scheduling
   - Geo-distributed inference

4. **Cost Optimization:**
   - Spot instance integration
   - Idle resource reclamation
   - Power-aware scheduling

5. **Advanced Monitoring:**
   - Request tracing (OpenTelemetry)
   - A/B testing framework
   - Canary deployments

---

## References

- [Ray Documentation](https://docs.ray.io/)
- [KubeRay Documentation](https://docs.ray.io/en/latest/cluster/kubernetes/)
- [Ray Serve Documentation](https://docs.ray.io/en/latest/serve/)
- [vLLM Integration Guide](https://docs.ray.io/en/latest/serve/tutorials/vllm-example.html)
- [Rocket AI Infrastructure](/docs/README.md)
- [MicroK8s Deployment Guide](/k8s/README.md)

---

## Appendix A: Complete Manifest Files

See `/k8s/ray/` directory for complete Kubernetes manifests:

- `dev/ray-cluster-dev.yaml` - Development cluster
- `staging/ray-cluster-staging.yaml` - Staging cluster
- `prod/ray-cluster-prod.yaml` - Production cluster with HA
- `shared/ray-secrets.yaml` - Secret templates
- `shared/ray-network-policy.yaml` - Network policies
- `ingress/ray-dashboard-ingress.yaml` - Dashboard ingress
- `ingress/ray-serve-ingress.yaml` - Serve API ingress

---

**Document Version:** 1.0
**Last Updated:** 2025-11-21
**Author:** Aria Prime
**Status:** Design Complete - Ready for Implementation
