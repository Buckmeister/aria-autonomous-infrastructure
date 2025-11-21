# Kustomize Overlays for Rocket Deployments

This directory contains Kustomize overlays for deploying Rocket across different environments.

## Directory Structure

```
overlays/
├── dev/         # Development environment
├── staging/     # Staging/pre-production environment
├── prod/        # Production environment
└── README.md    # This file
```

## Environment Comparison

| Feature | Dev | Staging | Prod |
|---------|-----|---------|------|
| **Namespace** | rocket-dev | rocket-staging | rocket-prod |
| **Replicas** | 1 | 2 | 3 |
| **Model** | qwen2.5:0.5b | qwen2.5:1.5b | qwen2.5:3b |
| **Memory Request** | 1Gi | 1.5Gi | 2Gi |
| **Memory Limit** | 2Gi | 3Gi | 4Gi |
| **Storage** | 3Gi | 8Gi | 15Gi |
| **Image Tag** | latest | latest | 0.1.29 (pinned) |

## Quick Deployment

### Deploy to Development

```bash
# Build and view manifests
kubectl kustomize k8s/overlays/dev

# Apply to cluster
kubectl apply -k k8s/overlays/dev

# Verify deployment
kubectl get pods -n rocket-dev
```

### Deploy to Staging

```bash
# Apply to cluster
kubectl apply -k k8s/overlays/staging

# Verify deployment
kubectl get pods -n rocket-staging
kubectl logs -n rocket-staging deployment/staging-rocket-ollama -c ollama-server
```

### Deploy to Production

```bash
# Review changes first
kubectl diff -k k8s/overlays/prod

# Apply to cluster
kubectl apply -k k8s/overlays/prod

# Monitor rollout
kubectl rollout status deployment/prod-rocket-ollama -n rocket-prod

# Verify all replicas are running
kubectl get pods -n rocket-prod
```

## Switching Between Environments

You can have all three environments running simultaneously on the same cluster:

```bash
# List all Rocket deployments
kubectl get deployments -A | grep rocket

# Output:
# rocket-dev       dev-rocket-ollama       1/1     1            1           5m
# rocket-staging   staging-rocket-ollama   2/2     2            2           3m
# rocket-prod      prod-rocket-ollama      3/3     3            3           1m
```

## Customizing Overlays

### Changing Resource Limits

Edit the overlay's `kustomization.yaml`:

```yaml
patches:
  - target:
      kind: Deployment
      name: rocket-ollama
    patch: |-
      - op: replace
        path: /spec/template/spec/containers/0/resources/requests/memory
        value: "2Gi"
```

### Using Different Models

```yaml
patches:
  - target:
      kind: ConfigMap
      name: rocket-ollama-config
    patch: |-
      - op: replace
        path: /data/MODEL_NAME
        value: "qwen2.5:7b"
```

### Scaling Replicas

```bash
# Via kubectl
kubectl scale deployment/staging-rocket-ollama --replicas=4 -n rocket-staging

# Or update kustomization.yaml
patches:
  - target:
      kind: Deployment
      name: rocket-ollama
    patch: |-
      - op: replace
        path: /spec/replicas
        value: 4
```

## Cleanup

### Remove Specific Environment

```bash
# Remove dev environment
kubectl delete -k k8s/overlays/dev

# Remove staging environment
kubectl delete -k k8s/overlays/staging

# Remove production environment
kubectl delete -k k8s/overlays/prod
```

### Remove All Environments

```bash
# Delete all Rocket namespaces
kubectl delete namespace rocket-dev rocket-staging rocket-prod
```

## Best Practices

1. **Development**: Use for rapid iteration, small models, minimal resources
2. **Staging**: Mirror production configuration, test upgrades and changes here first
3. **Production**: Use pinned image versions, enable monitoring, multiple replicas for HA

## Next Steps

- Add Ingress manifests for HTTP/HTTPS routing
- Configure TLS certificates for HTTPS
- Set up monitoring and alerting (Prometheus, Grafana)
- Implement PodDisruptionBudgets for HA
- Configure HorizontalPodAutoscaler for auto-scaling
