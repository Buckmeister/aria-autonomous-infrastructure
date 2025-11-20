# Aria Autonomous Infrastructure Roadmap

**Version:** 2.1
**Last Updated:** 2025-11-20
**Status:** Phase 1 Complete

## Overview

This roadmap documents the architectural evolution of aria-autonomous-infrastructure from standalone Docker deployments to a production-ready distributed inference platform with intelligent GPU/CPU scheduling.

## Design Philosophy

1. **Incremental Evolution**: Each phase builds on previous work while maintaining backward compatibility
2. **Flexibility First**: Design for multiple deployment targets from day one
3. **Proven Patterns**: Apply architectural patterns from successful projects (dotfiles, Ray, Kubernetes)
4. **Production-Ready**: Focus on maintainability, observability, and fault tolerance

## Phase 1: Unified Docker Deployment ✅ COMPLETE

**Goal:** Single script supporting all Docker deployment scenarios

### Features Implemented

- ✅ **Unified Deployment Script** (`launch-rocket-unified.sh`)
  - CPU and GPU model support
  - Direct Docker and Docker Compose modes
  - Local and remote Docker host support
  - HuggingFace models (CPU) and GGUF models (GPU)

- ✅ **Shared Library Architecture** (`bin/lib/deployment_utils.sh`)
  - Centralized logging functions
  - Docker operation helpers
  - SSH operation helpers
  - Configuration file helpers
  - 60% reduction in code duplication

- ✅ **Docker Host Parameterization**
  - Local: `unix:///var/run/docker.sock` (default)
  - Remote TCP: `tcp://host:2375`
  - Remote SSH: `ssh://user@host`

### Usage Examples

```bash
# Local CPU deployment
./bin/launch-rocket-unified.sh \
    --model Qwen/Qwen2.5-0.5B-Instruct \
    --matrix-server http://srv1:8008 \
    --matrix-user @rocket:srv1.local \
    --matrix-token syt_abc123 \
    --matrix-room '!xyz:srv1.local'

# Remote GPU deployment via SSH
./bin/launch-rocket-unified.sh \
    --use-gpu --use-compose \
    --docker-host ssh://Aria@wks-bckx01 \
    --model-path "/models/gemma-3-12b-it-Q4_K_M.gguf" \
    --models-dir "D:\Models" \
    --matrix-server http://srv1:8008 \
    --matrix-user @rocket:srv1.local \
    --matrix-token syt_abc123 \
    --matrix-room '!xyz:srv1.local'
```

### Key Benefits

- **One Script, Any Target**: Eliminate script duplication
- **Consistent Interface**: Same arguments regardless of deployment location
- **Remote Deployment**: Deploy to GPU-enabled hosts from any machine
- **Easy Testing**: Switch between CPU and GPU models without code changes

---

## Phase 2: Kubernetes Migration 🎯 PLANNED

**Goal:** Migrate Docker Compose deployments to Kubernetes for better orchestration

**Timeline:** Q1 2026
**Status:** Planning

### Objectives

1. **Convert to Kubernetes Manifests**
   - Transform docker-compose.yml to K8s Deployment, Service, ConfigMap
   - Use `kompose` for initial conversion, then refine
   - Maintain same configuration interface as Docker deployments

2. **Add Kubernetes-Specific Features**
   - Health checks (liveness and readiness probes)
   - Resource limits and requests
   - Auto-scaling based on CPU/GPU utilization
   - Persistent volumes for model caching

3. **Deployment Tooling**
   - Update launch-rocket-unified.sh to support `--target kubernetes`
   - Create Helm charts for templated deployments
   - Support multiple namespaces (dev, staging, prod)

### Architecture

```yaml
# Example: rocket-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rocket-inference
  labels:
    app: rocket
    component: inference
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rocket
      component: inference
  template:
    metadata:
      labels:
        app: rocket
        component: inference
    spec:
      # Prefer GPU nodes, tolerate CPU nodes
      nodeSelector:
        workload-type: inference
      tolerations:
        - key: nvidia.com/gpu
          operator: Exists
      containers:
      - name: inference-server
        image: rocket-inference:latest
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            memory: "4Gi"
            cpu: "2"
            nvidia.com/gpu: 1  # Request GPU
          limits:
            memory: "8Gi"
            cpu: "4"
            nvidia.com/gpu: 1
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 5
        volumeMounts:
        - name: models
          mountPath: /models
          readOnly: true
      volumes:
      - name: models
        persistentVolumeClaim:
          claimName: models-pvc
```

### Migration Path

1. **Proof of Concept**: Deploy single Rocket instance on K8s
2. **Feature Parity**: Match all Docker Compose features
3. **Enhanced Monitoring**: Add Prometheus metrics, Grafana dashboards
4. **Production Deployment**: Migrate existing deployments

### Benefits

- **Better Orchestration**: Automatic restarts, rolling updates
- **Resource Management**: Fine-grained CPU/GPU allocation
- **Scalability**: Easy horizontal scaling for multiple instances
- **Production Features**: Health checks, auto-scaling, load balancing

---

## Phase 3: Ray Cluster with GPU/CPU Fallback 🚀 FUTURE

**Goal:** Distributed inference with intelligent GPU-preferred, CPU-fallback scheduling

**Timeline:** Q2-Q3 2026
**Status:** Research & Design

### Objectives

1. **Deploy Ray on Kubernetes (KubeRay)**
   - Install KubeRay operator
   - Create RayCluster custom resources
   - Configure heterogeneous node pools (GPU + CPU)

2. **Implement Ray Serve for Inference**
   - Deploy models as Ray Serve deployments
   - Configure GPU-preferred placement
   - Automatic CPU fallback when GPUs unavailable
   - Dynamic batching for throughput optimization

3. **Intelligent Scheduling**
   - Ray's built-in resource-aware scheduling
   - Custom placement strategies for cost optimization
   - Automatic GPU memory management
   - Request routing based on model requirements

### Architecture

```python
# Example: ray_serve_rocket.py
from ray import serve
from ray.serve import Application
import ray

@serve.deployment(
    name="rocket-inference",
    num_replicas=3,
    ray_actor_options={
        "num_gpus": 1,        # Request 1 GPU
        "num_cpus": 2,        # Fallback: 2 CPUs
        "resources": {"GPU": 1},  # Custom resource for GPU nodes
    },
    autoscaling_config={
        "min_replicas": 1,
        "max_replicas": 10,
        "target_num_ongoing_requests_per_replica": 5,
    }
)
class RocketModel:
    def __init__(self):
        import torch
        from transformers import AutoModelForCausalLM, AutoTokenizer

        # Ray automatically places this on GPU if available, CPU otherwise
        self.device = "cuda" if torch.cuda.is_available() else "cpu"
        self.model = AutoModelForCausalLM.from_pretrained(
            "Qwen/Qwen2.5-7B-Instruct",
            device_map=self.device
        )
        self.tokenizer = AutoTokenizer.from_pretrained("Qwen/Qwen2.5-7B-Instruct")
        print(f"Model loaded on {self.device}")

    async def __call__(self, request):
        """Handle inference request"""
        prompt = request.query_params.get("prompt", "")
        inputs = self.tokenizer(prompt, return_tensors="pt").to(self.device)
        outputs = self.model.generate(**inputs, max_new_tokens=150)
        response = self.tokenizer.decode(outputs[0], skip_special_tokens=True)
        return {"response": response, "device": self.device}

# Deploy to Ray Serve
app = RocketModel.bind()
serve.run(app, host="0.0.0.0", port=8080)
```

### KubeRay Deployment

```yaml
# ray-cluster.yaml
apiVersion: ray.io/v1
kind: RayCluster
metadata:
  name: rocket-ray-cluster
spec:
  rayVersion: '2.9.0'
  headGroupSpec:
    rayStartParams:
      dashboard-host: '0.0.0.0'
    template:
      spec:
        containers:
        - name: ray-head
          image: rayproject/ray:2.9.0-gpu
          resources:
            limits:
              cpu: "4"
              memory: "8Gi"
  workerGroupSpecs:
  # GPU worker group (preferred)
  - groupName: gpu-workers
    replicas: 2
    minReplicas: 1
    maxReplicas: 5
    rayStartParams: {}
    template:
      spec:
        nodeSelector:
          accelerator: nvidia-gpu
        containers:
        - name: ray-worker
          image: rayproject/ray:2.9.0-gpu
          resources:
            limits:
              nvidia.com/gpu: 1
              cpu: "8"
              memory: "16Gi"

  # CPU worker group (fallback)
  - groupName: cpu-workers
    replicas: 3
    minReplicas: 1
    maxReplicas: 10
    rayStartParams: {}
    template:
      spec:
        nodeSelector:
          workload-type: inference
        containers:
        - name: ray-worker
          image: rayproject/ray:2.9.0
          resources:
            limits:
              cpu: "4"
              memory: "8Gi"
```

### Benefits

- **Heterogeneous Cluster**: Mix GPU and CPU nodes seamlessly
- **Cost Optimization**: Use GPUs when available, fall back to CPU
- **Auto-Scaling**: Ray scales workers based on demand
- **Fault Tolerance**: Automatic failover if nodes fail
- **Resource Efficiency**: Share GPU resources across multiple models
- **Simplified Deployment**: Ray handles orchestration complexity

### Implementation Steps

1. **Deploy KubeRay Operator**: Install operator on existing K8s cluster
2. **Create RayCluster**: Deploy GPU + CPU worker groups
3. **Port Inference Code**: Convert Flask server to Ray Serve deployment
4. **Test GPU Fallback**: Verify CPU fallback when GPUs unavailable
5. **Performance Tuning**: Optimize batching, caching, and resource allocation
6. **Production Rollout**: Migrate workloads from K8s to Ray

---

## Phase 4: Multi-Node Model Sharding 🌟 ADVANCED

**Goal:** Distribute large models (70B+ parameters) across multiple nodes

**Timeline:** Q4 2026
**Status:** Future Research

### Objectives

1. **Tensor Parallelism**
   - Split model layers across multiple GPUs
   - Use Ray's distributed tensor primitives
   - Support models that don't fit on single GPU

2. **Pipeline Parallelism**
   - Distribute model stages across nodes
   - Optimize inter-node communication
   - Batch processing for efficiency

3. **Hybrid Execution**
   - Some layers on GPU, others on CPU
   - Intelligent placement based on layer compute requirements
   - Memory-efficient activation offloading

### Example Architecture

```python
# Multi-node model sharding with Ray
import ray
from ray.util.placement_group import placement_group

# Create placement group for multi-node deployment
pg = placement_group([
    {"GPU": 1, "CPU": 4},  # Node 1
    {"GPU": 1, "CPU": 4},  # Node 2
    {"CPU": 8},            # Node 3 (CPU fallback)
], strategy="STRICT_SPREAD")

@ray.remote(num_gpus=1, placement_group=pg)
class ModelShard:
    def __init__(self, shard_id, num_shards):
        """Initialize one shard of the model"""
        self.shard_id = shard_id
        # Load only this shard's layers
        self.layers = load_model_shard(shard_id, num_shards)

    def forward(self, hidden_states):
        """Process through this shard's layers"""
        return self.layers(hidden_states)

# Orchestrate multi-shard inference
class DistributedModel:
    def __init__(self, num_shards=3):
        self.shards = [
            ModelShard.remote(i, num_shards)
            for i in range(num_shards)
        ]

    async def generate(self, prompt):
        """Generate text using distributed model"""
        hidden_states = self.tokenize(prompt)

        # Pipeline through shards
        for shard in self.shards:
            hidden_states = await shard.forward.remote(hidden_states)

        return self.decode(hidden_states)
```

### Benefits

- **Large Model Support**: Deploy 70B, 175B+ parameter models
- **Resource Pooling**: Combine GPU resources from multiple machines
- **Cost Effective**: Use multiple smaller GPUs instead of expensive A100s
- **Flexible Scaling**: Add/remove nodes based on demand

---

## Technical Considerations

### Migration Compatibility

Each phase maintains backward compatibility:
- Phase 1: Docker/Docker Compose scripts continue to work
- Phase 2: K8s deployments coexist with Docker
- Phase 3: Ray Serve wraps existing inference code
- Phase 4: Sharding is opt-in for large models

### Infrastructure Requirements

**Phase 1 (Current):**
- Docker host with SSH access
- Network connectivity between deployment host and Docker host

**Phase 2 (Kubernetes):**
- Kubernetes cluster (1.25+)
- kubectl configured
- Helm 3.x
- Storage class for PersistentVolumes

**Phase 3 (Ray Cluster):**
- Kubernetes cluster with KubeRay operator
- Mixed node pool (GPU + CPU nodes)
- High-bandwidth inter-node networking
- Ray 2.9+

**Phase 4 (Multi-Node Sharding):**
- Multiple GPU nodes (2-8)
- Low-latency networking (10Gbps+)
- Large shared storage for model weights
- Advanced Ray configuration

### Monitoring & Observability

**Current (Phase 1):**
- Docker logs
- Matrix notifications
- Manual health checks

**Future (Phase 2-3):**
- Prometheus metrics
- Grafana dashboards
- Ray Dashboard
- Distributed tracing (Jaeger/Tempo)
- Alerting (AlertManager)

---

## Success Metrics

### Phase 1 ✅
- ✅ Single unified deployment script
- ✅ Support for local and remote Docker hosts
- ✅ CPU and GPU deployment modes
- ✅ 60% reduction in code duplication

### Phase 2 (Target)
- [ ] Deploy to Kubernetes cluster
- [ ] Auto-scaling working (1-10 replicas)
- [ ] Health checks operational
- [ ] <30s deployment time

### Phase 3 (Target)
- [ ] Ray Cluster operational
- [ ] GPU-preferred scheduling working
- [ ] Automatic CPU fallback functional
- [ ] 5x throughput improvement vs Phase 2

### Phase 4 (Target)
- [ ] 70B model running on cluster
- [ ] <2s latency for 100-token generation
- [ ] Linear scaling with number of nodes
- [ ] <10% inter-node communication overhead

---

## Resources & References

### Documentation
- [Docker Remote Host Configuration](https://docs.docker.com/engine/reference/commandline/dockerd/#daemon-socket-option)
- [Kubernetes Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [KubeRay Documentation](https://docs.ray.io/en/latest/cluster/kubernetes/index.html)
- [Ray Serve Guide](https://docs.ray.io/en/latest/serve/index.html)

### Tools
- **Kompose**: Convert Docker Compose to Kubernetes manifests
- **Helm**: Kubernetes package manager
- **KubeRay**: Ray operator for Kubernetes
- **Prometheus**: Metrics and monitoring
- **Grafana**: Visualization and dashboards

### Related Projects
- **vLLM**: High-performance LLM inference (could integrate in Phase 3-4)
- **Text Generation Inference (TGI)**: Hugging Face's inference server
- **llama.cpp**: GGUF model serving (currently used for GPU)

---

## Contributing

This roadmap is a living document. As we implement each phase, we'll update with:
- Actual implementation details
- Lessons learned
- Performance benchmarks
- Updated timelines

**Current Status:** Phase 1 complete, beginning Phase 2 planning.

---

## Changelog

**2025-11-20 - v2.1**
- Created comprehensive roadmap document
- Completed Phase 1: Unified Docker deployment
- Defined Phases 2-4 with detailed technical specifications
- Added code examples and architecture diagrams

---

**Document Maintainers:**
- Thomas (Architect)
- Aria Prime (Implementation)

**Last Review:** 2025-11-20
