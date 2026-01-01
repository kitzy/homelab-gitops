# Homelab GitOps

Infrastructure-as-Code for homelab K3s cluster using Flux.

## Structure

- `clusters/production/` - Flux bootstrap and cluster-specific configs
- `infrastructure/` - Core infrastructure components (cert-manager, external-secrets, etc)
- `apps/` - Application deployments (Fleet, Authentik, n8n)
