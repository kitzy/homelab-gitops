# Example: Using Tailscale Ingress with Existing Workload

This example shows how to add Tailscale Ingress to an existing workload like `hello-world`.

## Option 1: Add Tailscale Ingress Alongside Existing Setup

You can expose the same service through both Cloudflare Tunnel AND Tailscale:

### Create a Tailscale Ingress

Create `apps/hello-world/tailscale-ingress.yaml`:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: hello-world-tailscale
  namespace: hello-world
  annotations:
    # Enable TLS with automatic Let's Encrypt certificates
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
```

### Add to Kustomization

Update `apps/hello-world/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml
  - certificate.yaml  # Cloudflare certificate (existing)
  - tailscale-ingress.yaml  # NEW: Tailscale ingress
```

Now your app will be accessible at:
- **Public**: `https://hello-world.yourdomain.com` (via Cloudflare)
- **Private**: `https://hello-world-internal.<tailnet>.ts.net` (via Tailscale)

## Option 2: Use Only Tailscale

If you want to expose a service ONLY through Tailscale (not publicly):

1. Remove or don't create the Cloudflare certificate
2. Only create the Tailscale Ingress
3. Access will be restricted to devices on your Tailnet

## Example: Fleet Application with Private Admin Panel

Let's say you want to expose Fleet publicly but keep the admin panel private:

```yaml
---
# Public Fleet access via Cloudflare
apiVersion: v1
kind: Service
metadata:
  name: fleet
  namespace: fleet
spec:
  # This can be accessed publicly through Cloudflare
  type: ClusterIP
  ports:
    - port: 8080
      targetPort: 8080
---
# Private admin panel via Tailscale
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: fleet-admin
  namespace: fleet
  annotations:
    tailscale.com/tls: "true"
    # Optional: Add Tailscale ACL tags
    tailscale.com/tags: "tag:k8s,tag:admin"
spec:
  ingressClassName: tailscale
  rules:
    - host: fleet-admin
      http:
        paths:
          - path: /admin
            pathType: Prefix
            backend:
              service:
                name: fleet
                port:
                  number: 8080
```

## Benefits of Dual Exposure

1. **Security**: Admin panels and sensitive endpoints stay private
2. **Flexibility**: Different access methods for different users
3. **Performance**: Internal users can bypass Cloudflare
4. **Development**: Easier testing without exposing to internet

## Deployment

After creating the Tailscale Ingress:

```bash
# Commit and push your changes
git add .
git commit -m "Add Tailscale ingress for private access"
git push

# Flux will automatically reconcile
flux reconcile kustomization apps --with-source

# Check the Tailscale device was created
kubectl get ingress -n hello-world
kubectl logs -n tailscale deployment/tailscale-operator
```

You can then access your service at `https://hello-world-internal.<tailnet-name>.ts.net` from any device connected to your Tailnet!
