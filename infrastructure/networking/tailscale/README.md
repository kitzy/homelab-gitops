# Tailscale Kubernetes Operator

This directory contains the configuration for the Tailscale Kubernetes Operator, which allows you to expose cluster workloads to your Tailnet.

## Setup

### Prerequisites

1. **Tailscale Account**: You need access to the Tailscale admin console
2. **OAuth Client**: Create an OAuth client with the following scopes:
   - `Devices Core` (write)
   - `Auth Keys` (write)
   - `Services` (write)
   - Tagged with `tag:k8s-operator`

### Creating the OAuth Client

1. Go to your [Tailscale Admin Console](https://login.tailscale.com/admin/settings/oauth)
2. Navigate to Settings > OAuth Clients
3. Click "Generate OAuth Client"
4. Configure:
   - **Scopes**: Select `Devices Core`, `Auth Keys`, and `Services` with write permissions
   - **Tags**: Add `tag:k8s-operator`
5. Save the **Client ID** and **Client Secret**

### Storing OAuth Credentials in 1Password

Store the OAuth credentials in your Homelab 1Password vault:

1. Create a new item named `tailscale-operator`
2. Add two fields:
   - `client_id`: Your OAuth Client ID
   - `client_secret`: Your OAuth Client Secret

### Configuring Tailscale ACLs

Add the following to your [tailnet policy file](https://login.tailscale.com/admin/acls):

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

## Usage

### Exposing a Service with Ingress

You can expose a Kubernetes Service to your Tailnet using a Tailscale Ingress resource:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: my-app
  namespace: my-app
  annotations:
    # Use TLS with Let's Encrypt
    tailscale.com/tls: "true"
spec:
  ingressClassName: tailscale
  rules:
    - host: my-app
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
```

This will:
- Create a Tailscale device named `my-app` in your tailnet
- Expose the service at `https://my-app.<tailnet-name>.ts.net`
- Automatically provision TLS certificates from Let's Encrypt

### Exposing a Service with LoadBalancer

Alternatively, you can use the LoadBalancer service type:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
  namespace: my-app
  annotations:
    # Expose this service to the tailnet
    tailscale.com/expose: "true"
    # Optional: Customize the hostname
    tailscale.com/hostname: "my-custom-name"
spec:
  type: LoadBalancer
  loadBalancerClass: tailscale
  ports:
    - port: 80
      targetPort: 8080
      protocol: TCP
  selector:
    app: my-app
```

### Comparison with Cloudflare Tunnel

You can choose to use either Tailscale or Cloudflare Tunnel (or both) for exposing workloads:

| Feature | Tailscale | Cloudflare Tunnel |
|---------|-----------|-------------------|
| **Access** | Requires Tailscale client | Public internet |
| **Authentication** | Tailscale ACLs | Cloudflare Access |
| **TLS** | Automatic (Let's Encrypt) | Automatic (Cloudflare) |
| **Private Services** | ✅ Yes (default) | ⚠️ Requires Cloudflare Access |
| **Public Services** | ❌ No | ✅ Yes |
| **Setup Complexity** | Low | Medium |

**When to use Tailscale**:
- Internal services that should only be accessible to your team
- Development/staging environments
- Admin panels and dashboards
- Database management tools
- Monitoring and observability tools

**When to use Cloudflare Tunnel**:
- Public-facing applications
- Services that need to be accessible without VPN
- Services requiring CDN capabilities
- Services needing DDoS protection

### Example: Exposing Multiple Services

You can expose multiple services in the same namespace:

```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-api
  namespace: my-app
  annotations:
    tailscale.com/tls: "true"
spec:
  ingressClassName: tailscale
  rules:
    - host: app-api
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: api
                port:
                  number: 3000
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-admin
  namespace: my-app
  annotations:
    tailscale.com/tls: "true"
spec:
  ingressClassName: tailscale
  rules:
    - host: app-admin
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: admin
                port:
                  number: 8080
```

## Monitoring

The operator will create devices in your Tailscale admin console. You can view them at:
https://login.tailscale.com/admin/machines

Each exposed service will appear as a separate device tagged with `tag:k8s`.

## Troubleshooting

### Check Operator Status

```bash
# Check operator pod logs
kubectl logs -n tailscale deployment/tailscale-operator

# Check if OAuth credentials are configured
kubectl get secret -n tailscale operator-oauth

# Check operator device in Tailscale
# Visit: https://login.tailscale.com/admin/machines
# Look for device named "tailscale-operator"
```

### Common Issues

1. **OAuth Secret Not Found**:
   - Ensure the External Secret is synced: `kubectl get externalsecret -n tailscale`
   - Check 1Password credentials are correctly configured

2. **Service Not Accessible**:
   - Verify the Tailscale device is online in the admin console
   - Check ACLs allow access to `tag:k8s` devices
   - Ensure you're connected to your Tailnet

3. **Certificate Issues**:
   - Certificates are automatically issued by Let's Encrypt
   - First request may take a few seconds
   - Check operator logs for certificate issuance errors

## References

- [Tailscale Kubernetes Operator Documentation](https://tailscale.com/kb/1236/kubernetes-operator)
- [Cluster Ingress Guide](https://tailscale.com/kb/1439/kubernetes-operator-cluster-ingress)
- [Cluster Egress Guide](https://tailscale.com/kb/1438/kubernetes-operator-cluster-egress)
