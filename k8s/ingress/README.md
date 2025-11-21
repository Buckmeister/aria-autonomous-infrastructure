# Ingress Configuration for Rocket

This directory contains Ingress manifests for exposing Rocket services via HTTP/HTTPS.

## Files

- **ollama-ingress-http.yaml**: HTTP Ingress (dev/testing only, not encrypted)
- **ollama-ingress-https.yaml**: HTTPS Ingress (production-ready, TLS encrypted)
- **cert-issuer.yaml**: cert-manager ClusterIssuers for automatic TLS certificates
- **README.md**: This file

## Prerequisites

### 1. Nginx Ingress Controller

Install the Nginx Ingress Controller on your MicroK8s cluster:

```bash
# Enable ingress addon
ssh debian@cp-1
sudo microk8s enable ingress

# Verify installation
sudo microk8s kubectl get pods -n ingress
```

### 2. DNS or /etc/hosts

For testing, add entries to your /etc/hosts file:

```bash
# Example: Point rocket domains to worker-1's IP
echo "192.168.1.100  rocket-ollama.local" | sudo tee -a /etc/hosts
echo "192.168.1.100  rocket.yourdomain.com" | sudo tee -a /etc/hosts
```

For production, configure proper DNS A records pointing to your cluster's external IP or load balancer.

## Quick Start: HTTP Ingress (Development)

### Deploy HTTP Ingress

```bash
# Apply HTTP Ingress
kubectl apply -f k8s/ingress/ollama-ingress-http.yaml

# Verify Ingress created
kubectl get ingress -n rocket

# Expected output:
# NAME                 CLASS   HOSTS                  ADDRESS   PORTS   AGE
# rocket-ollama-http   nginx   rocket-ollama.local    ...       80      1m
```

### Test HTTP Access

```bash
# Test API listing
curl http://rocket-ollama.local/api/tags

# Test inference
curl http://rocket-ollama.local/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:0.5b",
    "messages": [
      {"role": "user", "content": "Hello! How are you?"}
    ]
  }'
```

## Production: HTTPS Ingress with TLS

### Option 1: cert-manager + Let's Encrypt (Recommended)

This automatically provisions and renews TLS certificates from Let's Encrypt.

#### Step 1: Install cert-manager

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Wait for cert-manager pods to be ready
kubectl get pods -n cert-manager
```

#### Step 2: Configure ClusterIssuers

```bash
# Edit cert-issuer.yaml and update email addresses
vi k8s/ingress/cert-issuer.yaml
# Change: email: your-email@example.com

# Apply ClusterIssuers
kubectl apply -f k8s/ingress/cert-issuer.yaml

# Verify ClusterIssuers
kubectl get clusterissuers
```

#### Step 3: Deploy HTTPS Ingress

```bash
# Edit ollama-ingress-https.yaml
# - Update host: to your domain
# - Ensure annotation uses correct issuer (start with staging)
#   cert-manager.io/cluster-issuer: "letsencrypt-staging"

# Apply HTTPS Ingress
kubectl apply -f k8s/ingress/ollama-ingress-https.yaml

# Watch certificate provisioning
kubectl get certificate -n rocket -w

# Check certificate details
kubectl describe certificate rocket-ollama-tls -n rocket
```

#### Step 4: Switch to Production Issuer

Once staging works:

```bash
# Update annotation in ollama-ingress-https.yaml:
#   cert-manager.io/cluster-issuer: "letsencrypt-prod"

# Reapply
kubectl apply -f k8s/ingress/ollama-ingress-https.yaml

# New certificate will be issued
kubectl get certificate -n rocket
```

### Option 2: Self-Signed Certificate (Testing Only)

For local testing without public DNS:

```bash
# Generate self-signed certificate
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout tls.key -out tls.crt \
  -subj "/CN=rocket.yourdomain.com/O=Rocket Dev"

# Create TLS secret
kubectl create secret tls rocket-ollama-tls \
  --cert=tls.crt \
  --key=tls.key \
  -n rocket

# Remove cert-manager annotation from ollama-ingress-https.yaml
# Then apply
kubectl apply -f k8s/ingress/ollama-ingress-https.yaml
```

### Test HTTPS Access

```bash
# Test with self-signed cert (ignore cert warning)
curl -k https://rocket.yourdomain.com/api/tags

# Test inference
curl -k https://rocket.yourdomain.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen2.5:0.5b",
    "messages": [
      {"role": "user", "content": "Hello! How are you?"}
    ]
  }'
```

## Advanced Configuration

### Custom Timeout Settings

For long-running inference requests, adjust timeouts:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"  # 10 minutes
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "600"
```

### Rate Limiting

Protect your API with rate limits:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/limit-rps: "10"  # 10 requests per second
    nginx.ingress.kubernetes.io/limit-connections: "5"  # Max 5 concurrent connections
```

### IP Whitelisting

Restrict access to specific IPs:

```yaml
metadata:
  annotations:
    nginx.ingress.kubernetes.io/whitelist-source-range: "192.168.1.0/24,10.0.0.0/8"
```

### Basic Authentication

Add basic auth for additional security:

```bash
# Create htpasswd file
htpasswd -c auth rocket-user

# Create secret
kubectl create secret generic rocket-basic-auth \
  --from-file=auth=auth \
  -n rocket

# Add annotation to Ingress
nginx.ingress.kubernetes.io/auth-type: basic
nginx.ingress.kubernetes.io/auth-secret: rocket-basic-auth
nginx.ingress.kubernetes.io/auth-realm: "Rocket API Authentication"
```

## Monitoring

### Check Ingress Status

```bash
# List all ingresses
kubectl get ingress -A

# Describe specific ingress
kubectl describe ingress rocket-ollama-https -n rocket

# View Nginx controller logs
kubectl logs -n ingress deployment/nginx-ingress-microk8s-controller -f
```

### Check TLS Certificate

```bash
# Check certificate status
kubectl get certificate -n rocket

# View certificate details
kubectl describe certificate rocket-ollama-tls -n rocket

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager -f
```

## Troubleshooting

### Ingress Not Working

1. **Check Ingress Controller**:
   ```bash
   kubectl get pods -n ingress
   kubectl logs -n ingress deployment/nginx-ingress-microk8s-controller
   ```

2. **Check Service**:
   ```bash
   kubectl get svc -n rocket
   # Ensure rocket-ollama service exists and has endpoints
   ```

3. **Check DNS**:
   ```bash
   nslookup rocket.yourdomain.com
   # Or check /etc/hosts
   ```

### Certificate Issues

1. **Certificate Pending**:
   ```bash
   kubectl get certificate -n rocket
   kubectl describe certificate rocket-ollama-tls -n rocket
   kubectl get orders,challenges -n rocket
   ```

2. **HTTP-01 Challenge Failing**:
   - Ensure domain points to cluster IP
   - Check firewall allows port 80 (required for challenge)
   - Verify Ingress controller is running

3. **Rate Limit Hit**:
   - Use staging issuer first
   - Wait for rate limit reset (weekly)
   - Consider DNS-01 challenge instead

## Multi-Environment Setup

You can create different Ingresses for each environment:

```bash
# Dev environment (HTTP)
kubectl apply -f k8s/ingress/ollama-ingress-http.yaml -n rocket-dev

# Staging (HTTPS with staging certs)
kubectl apply -f k8s/ingress/ollama-ingress-https.yaml -n rocket-staging

# Production (HTTPS with production certs)
kubectl apply -f k8s/ingress/ollama-ingress-https.yaml -n rocket-prod
```

Update host names for each environment:
- Dev: `rocket-dev.yourdomain.com`
- Staging: `rocket-staging.yourdomain.com`
- Prod: `rocket.yourdomain.com`

## Cleanup

```bash
# Remove HTTP Ingress
kubectl delete -f k8s/ingress/ollama-ingress-http.yaml

# Remove HTTPS Ingress
kubectl delete -f k8s/ingress/ollama-ingress-https.yaml

# Remove ClusterIssuers
kubectl delete -f k8s/ingress/cert-issuer.yaml

# Remove TLS secret
kubectl delete secret rocket-ollama-tls -n rocket
```

## Next Steps

- Configure monitoring and alerting for Ingress
- Set up WAF (Web Application Firewall) rules
- Implement API key authentication
- Add request/response caching
- Configure CDN for global distribution
