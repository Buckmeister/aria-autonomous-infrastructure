# Ray Cluster Quick Reference

Ray Cluster deployment commands. See [K8S.md](K8S.md) for full K8s operations.

---

## Quick Deploy

```bash
# Development cluster
kubectl apply -f ~/Development/aria-autonomous-infrastructure/k8s/ray/dev/ray-cluster-dev.yaml

# Production cluster
kubectl apply -f ~/Development/aria-autonomous-infrastructure/k8s/ray/prod/ray-cluster-prod.yaml
```

---

## Check Status

```bash
# Ray Cluster resource
kubectl get raycluster -n ray-dev

# Pods
kubectl get pods -n ray-dev

# Logs
kubectl logs -n ray-dev -l ray.io/node-type=head --follow
```

---

## Access Dashboard

```bash
# Port-forward
kubectl port-forward -n ray-dev svc/ray-cluster-dev-head-svc 8265:8265

# Or use kmgr
kmgr ray dashboard dev

# Open: http://localhost:8265
```

---

## Scale Workers

```bash
# Using kmgr
kmgr ray scale dev 10

# Or edit manifest
kubectl edit raycluster ray-cluster-dev -n ray-dev
# Change spec.workerGroupSpecs[0].replicas
```

---

## Delete and Recreate

```bash
kubectl delete raycluster ray-cluster-dev -n ray-dev
kubectl apply -f k8s/ray/dev/ray-cluster-dev.yaml
```

---

## Configuration

**Dev Cluster:** 1 head + 2 workers (autoscale 1-10)
**Prod Cluster:** 1 head + 4 workers (autoscale 2-20)

**Image:** rayproject/ray-ml:2.9.0 (~3-4GB)
**Namespace:** ray-dev (dev), ray-prod (prod)

**Ports:**
- 6379 - Redis (GCS)
- 8265 - Dashboard
- 10001 - Client
- 8000 - Serve API

---

## Integration Vision

**Future Rocket Deployment:**
- Deploy multiple backends on Ray
- Intelligent routing via Ray Serve
- Auto-scaling based on demand
- Distributed inference across 7 nodes

**Status:** Ray infrastructure ready, Rocket integration next phase

---

See [K8S.md](K8S.md) for complete Kubernetes operations.

**Last Updated:** 2025-11-22
