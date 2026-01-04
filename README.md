# homelab-gitops

GitOps repository for homelab K3s cluster using Flux CD.

## Overview

This repository manages the complete infrastructure and application deployment for a production-grade 5-node Kubernetes cluster running on Proxmox. All configuration is declarative, version-controlled, and automatically synced to the cluster via Flux.

**Key principles:**
- Everything in Git - infrastructure, applications, and configuration
- No manual kubectl apply - all changes via git push
- Secrets never in Git - managed via 1Password Connect + External Secrets Operator
- GitOps workflow - Flux automatically syncs changes within seconds

## Architecture

### Cluster details

- **Platform**: K3s v1.33.6+k3s1
- **Nodes**: 5 VMs on Proxmox (3 control planes, 2 workers)
- **Storage**: Longhorn distributed block storage
- **GitOps**: Flux CD
- **Secrets**: 1Password Connect + External Secrets Operator
- **External access**: Cloudflare Tunnel
- **Certificates**: cert-manager with self-signed CA

### GitOps workflow

```
Developer                 GitHub                    K3s Cluster
   │                         │                          │
   │  1. git push            │                          │
   ├────────────────────────>│                          │
   │                         │                          │
   │                         │  2. Webhook notification │
   │                         ├─────────────────────────>│
   │                         │                          │
   │                         │  3. Flux source-controller pulls
   │                         │<─────────────────────────┤
   │                         │                          │
   │                         │  4. Flux kustomize-controller reconciles
   │                         │                          │
   │                         │                          ├──> Applies manifests
   │                         │                          ├──> Creates resources
   │                         │                          └──> Updates status
```

**Sync mechanism:**
- **Webhook-triggered**: GitHub webhook notifies Flux on every push (~5 second sync)
- **Polling fallback**: Flux polls repository every 1 minute as backup
- **Manual trigger**: `flux reconcile kustomization apps --with-source` forces immediate sync

## Repository structure

```
homelab-gitops/
├── infrastructure/           # Core cluster infrastructure
│   ├── sources/             # Helm chart repositories
│   │   ├── jetstack.yaml
│   │   ├── external-secrets.yaml
│   │   └── longhorn.yaml
│   ├── core/                # Essential cluster services
│   │   ├── cert-manager/
│   │   ├── external-secrets/
│   │   ├── 1password-connect/
│   │   └── cloudflare/
│   └── kustomization.yaml   # Infrastructure root kustomization
│
├── apps/                    # Application deployments
│   ├── hello-world/         # Test application (validates stack)
│   ├── fleet/               # FleetDM endpoint management
│   ├── scanopy/             # Network discovery platform
│   └── kustomization.yaml   # Apps root kustomization
│
└── clusters/production/     # Cluster-specific configuration
    ├── infrastructure.yaml  # Points to infrastructure/
    ├── apps.yaml            # Points to apps/
    └── flux-system/         # Flux bootstrap configuration
        ├── gotk-components.yaml
        ├── gotk-sync.yaml
        └── kustomization.yaml
```

## Getting started

### Prerequisites

- kubectl configured for K3s cluster
- Flux CLI installed (v2.4.0+)
- GitHub personal access token with repo permissions

### Deploying changes

1. **Make changes** to manifests in infrastructure/ or apps/
2. **Commit and push** to GitHub:
   ```bash
   git add .
   git commit -m "Add new service"
   git push
   ```
3. **Watch Flux sync** (usually completes in 5-10 seconds):
   ```bash
   flux get kustomizations --watch
   ```

### Adding a new application

1. Create application directory under `apps/`:
   ```bash
   mkdir -p apps/my-app
   ```

2. Add Kubernetes manifests:
   ```bash
   apps/my-app/
   ├── namespace.yaml
   ├── external-secret.yaml  # If secrets needed
   ├── deployment.yaml
   ├── service.yaml
   ├── ingress.yaml          # If external access needed
   └── kustomization.yaml
   ```

3. Add to apps kustomization:
   ```yaml
   # apps/kustomization.yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - hello-world
     - fleet
     - scanopy
     - my-app              # Add new app here
   ```

4. Commit and push - Flux handles the rest

### Secrets management

**Never commit secrets to Git.** Use 1Password + External Secrets Operator:

1. **Store secret in 1Password** (Homelab vault)

2. **Create ExternalSecret manifest**:
   ```yaml
   apiVersion: external-secrets.io/v1beta1
   kind: ExternalSecret
   metadata:
     name: my-app-secrets
     namespace: my-app
   spec:
     refreshInterval: 1h
     secretStoreRef:
       name: onepassword
       kind: ClusterSecretStore
     target:
       name: my-app-secrets
       creationPolicy: Owner
     data:
       - secretKey: DATABASE_PASSWORD
         remoteRef:
           key: My App Secrets      # 1Password item name
           property: password       # 1Password field name
   ```

3. **Reference secret in deployment**:
   ```yaml
   env:
     - name: DATABASE_PASSWORD
       valueFrom:
         secretKeyRef:
           name: my-app-secrets
           key: DATABASE_PASSWORD
   ```

## Common operations

### Force Flux to sync from GitHub

If Flux hasn't picked up your changes yet:

```bash
# Reconcile infrastructure
flux reconcile kustomization infrastructure --with-source

# Reconcile apps
flux reconcile kustomization apps --with-source

# Reconcile everything
flux reconcile kustomization flux-system --with-source
```

### Check Flux sync status

```bash
# View all kustomizations
flux get kustomizations

# Watch kustomizations (live updates)
flux get kustomizations --watch

# Check Git source status
flux get sources git

# View recent reconciliation events
flux events
```

### Suspend/resume automatic sync

```bash
# Suspend sync (for maintenance)
flux suspend kustomization apps

# Resume sync
flux resume kustomization apps
```

### View Flux logs

```bash
# Source controller (Git polling)
kubectl logs -n flux-system deploy/source-controller -f

# Kustomize controller (manifest application)
kubectl logs -n flux-system deploy/kustomize-controller -f

# Helm controller (if using Helm)
kubectl logs -n flux-system deploy/helm-controller -f
```

## Troubleshooting

### Changes not applying

**Symptoms:** Git push completes but changes don't appear in cluster

**Check sync status:**
```bash
flux get kustomizations
```

**Look for errors:**
```bash
# Check kustomization status
kubectl get kustomization -n flux-system apps -o yaml

# View recent events
flux events --for Kustomization/apps

# Check source sync
flux get sources git
```

**Force reconciliation:**
```bash
flux reconcile kustomization apps --with-source
```

**Common causes:**
- Invalid YAML syntax (check with `kubectl apply --dry-run=client`)
- Missing namespace (ensure namespace exists before resources)
- Dependency ordering (use `dependsOn` in kustomization.yaml)
- Webhook not triggering (check GitHub webhook delivery)

### Webhook not working

**Check webhook configuration:**
```bash
# Get webhook URL
flux create receiver github-receiver \
  --type github \
  --event ping,push \
  --secret-ref webhook-token \
  --resource GitRepository/flux-system \
  --export

# Test webhook from GitHub
# Go to repo Settings → Webhooks → click webhook → Recent Deliveries → Redeliver
```

**Fallback:** Flux polls every 1 minute regardless of webhook

### ExternalSecret not syncing

**Check ExternalSecret status:**
```bash
kubectl get externalsecret -n <namespace>
kubectl describe externalsecret <name> -n <namespace>
```

**Check 1Password Connect:**
```bash
# Verify pods running
kubectl get pods -n 1password

# Check logs
kubectl logs -n 1password -l app=onepassword-connect

# Test connection
kubectl get clustersecretstore onepassword -o yaml
```

**Common causes:**
- Typo in 1Password item name or field name (case-sensitive!)
- Item not in correct vault (must be "Homelab" vault)
- 1Password Connect token expired or invalid

### Deployment stuck in ImagePullBackOff

**Check image availability:**
```bash
kubectl describe pod <pod-name> -n <namespace>
```

**Common causes:**
- Typo in image name
- Private registry without imagePullSecrets
- Image doesn't exist for specified tag
- Rate limit on public registries

### Certificate issues

**Check certificate status:**
```bash
kubectl get certificate -A
kubectl describe certificate <name> -n <namespace>
```

**Check cert-manager logs:**
```bash
kubectl logs -n cert-manager deploy/cert-manager -f
```

**Verify CA issuer:**
```bash
kubectl get clusterissuer
kubectl describe clusterissuer ca-issuer
```

## Performance and resource limits

All deployments should include resource requests and limits to prevent OOM incidents:

```yaml
resources:
  requests:
    memory: "256Mi"
    cpu: "100m"
  limits:
    memory: "512Mi"
    cpu: "500m"
```

**Why this matters:** Without limits, a single misbehaving pod can exhaust node resources and cause cluster-wide issues.

## Related documentation

- **Migration Project**: [Proxmox Infrastructure Migration Project](https://www.notion.so/27ef8d994cff8155b9c7e0776dd7c272)
- **TLS Infrastructure**: [K3s Self-Signed TLS Infrastructure](https://www.notion.so/2ddf8d994cff818bbb90f39c48eae854)
- **Secrets Management**: [K3s secrets from 1Password](https://www.notion.so/2dcf8d994cff8148abf8c477803a1950)
- **Current Services**: [Docker Services (Current)](https://www.notion.so/ac72a6815fe745b4954b3b44bc80c9b4)
- **Service Dependencies**: [Service Dependencies](https://www.notion.so/4cead182b2ad45989fcc43303633afcf)

## Contributing

All changes must:
1. Follow existing directory structure and naming conventions
2. Include proper resource limits
3. Use External Secrets for any sensitive data
4. Be tested with `kubectl apply --dry-run=client` before committing
5. Update this README if adding new patterns or workflows

## Support

For issues or questions:
- Check Notion documentation (links above)
- Review Flux logs and events
- Search existing manifests for examples
- File issue in this repository for tracking