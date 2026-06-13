# Tailscale Kubernetes Operator Setup - Next Steps

## What Has Been Created

The Tailscale Kubernetes Operator has been configured in your GitOps repository with the following structure:

```
infrastructure/networking/tailscale/
├── README.md              # Full documentation
├── EXAMPLES.md            # Usage examples
├── namespace.yaml         # Tailscale namespace
├── external-secret.yaml   # OAuth credentials from 1Password
├── helm-release.yaml      # Helm deployment configuration
└── kustomization.yaml     # Kustomize configuration
```

## Required Steps to Complete Setup

### 1. Configure Tailscale ACLs

Go to your [Tailscale Admin Console ACLs page](https://login.tailscale.com/admin/acls) and add:

```json
{
  "tagOwners": {
    "tag:k8s-operator": [],
    "tag:k8s": ["tag:k8s-operator"]
  },
  "acls": [
    {
      "action": "accept",
      "src": ["*"],
      "dst": ["tag:k8s:*"]
    }
  ]
}
```

This allows:
- The operator to manage devices tagged with `tag:k8s`
- All devices on your tailnet to access k8s services

### 2. Create OAuth Client

1. Go to [OAuth Clients page](https://login.tailscale.com/admin/settings/oauth)
2. Click "Generate OAuth Client"
3. Configure:
   - **Scopes**: `Devices Core` (write), `Auth Keys` (write), `Services` (write)
   - **Tags**: `tag:k8s-operator`
4. Save the Client ID and Client Secret

### 3. Store Credentials in 1Password

In your `Homelab` vault in 1Password, create a new item:

- **Name**: `tailscale-operator`
- **Fields**:
  - `client_id` = (Your OAuth Client ID)
  - `client_secret` = (Your OAuth Client Secret)

### 4. Deploy to Your Cluster

```bash
# Commit the changes
git add infrastructure/networking/tailscale/
git commit -m "Add Tailscale Kubernetes Operator"
git push

# Flux will automatically reconcile
# Or manually trigger:
flux reconcile kustomization infrastructure-networking --with-source
```

### 5. Verify Installation

```bash
# Check that the namespace was created
kubectl get namespace tailscale

# Check external secret is synced
kubectl get externalsecret -n tailscale operator-oauth

# Check the operator pod is running
kubectl get pods -n tailscale

# Check operator logs
kubectl logs -n tailscale deployment/tailscale-operator

# Verify in Tailscale admin console
# Visit: https://login.tailscale.com/admin/machines
# Look for device named "tailscale-operator" with tag:k8s-operator
```

## Using Tailscale Operator

### Quick Start: Expose a Service

Create an Ingress resource for any service:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-service
  namespace: my-namespace
  annotations:
    tailscale.com/tls: "true"
spec:
  ingressClassName: tailscale
  rules:
    - host: my-service
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-service
                port:
                  number: 80
```

Access your service at: `https://my-service.<tailnet-name>.ts.net`

### Example: Add Tailscale to hello-world

```bash
# Create a Tailscale ingress for hello-world
cat <<EOF > apps/hello-world/tailscale-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-tailscale
  namespace: hello-world
  annotations:
    tailscale.com/tls: "true"
spec:
  ingressClassName: tailscale
  rules:
    - host: hello-world-internal
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: hello-world
                port:
                  number: 80
EOF

# Update kustomization.yaml to include it
# Add 'tailscale-ingress.yaml' to resources list

# Commit and deploy
git add apps/hello-world/
git commit -m "Add Tailscale access to hello-world"
git push
```

## Choosing Between Tailscale and Cloudflare

| Use Case | Recommended Solution |
|----------|---------------------|
| Public website/API | Cloudflare Tunnel |
| Admin panels | Tailscale |
| Internal tools | Tailscale |
| Development/staging | Tailscale |
| Database GUIs | Tailscale |
| Monitoring dashboards | Tailscale |
| Public blog/docs | Cloudflare Tunnel |
| Customer-facing apps | Cloudflare Tunnel |

You can use BOTH for the same application:
- Public frontend → Cloudflare
- Admin panel → Tailscale

## Troubleshooting

If something doesn't work:

1. **Check External Secret**: `kubectl describe externalsecret -n tailscale operator-oauth`
2. **Check Operator Logs**: `kubectl logs -n tailscale deployment/tailscale-operator`
3. **Verify OAuth Scopes**: Make sure all three scopes are enabled (Devices Core, Auth Keys, Services)
4. **Check Tailscale ACLs**: Ensure `tag:k8s-operator` owns `tag:k8s`
5. **Verify Network**: Ensure your cluster has outbound internet access to Tailscale

## Documentation

- [Full README](./README.md) - Complete documentation
- [Usage Examples](./EXAMPLES.md) - Practical examples
- [Tailscale Docs](https://tailscale.com/kb/1236/kubernetes-operator) - Official documentation

## Security Notes

1. **OAuth Credentials**: Stored securely in 1Password, never in git
2. **Access Control**: Managed through Tailscale ACLs
3. **TLS**: Automatic certificates from Let's Encrypt
4. **Private by Default**: Services only accessible on your Tailnet
5. **Audit Trail**: All access logged in Tailscale admin console
