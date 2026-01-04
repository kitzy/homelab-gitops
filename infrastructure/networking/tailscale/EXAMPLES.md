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
spec:
  ingressClassName: tailscale
  tls:
    - hosts:
        - hello-world.your-tailnet.ts.net
  defaultBackend:
    service:
      name: hello-world
      port:
        number: 80
```

**Note**: Replace `your-tailnet` with your actual Tailscale tailnet name (e.g., `tail26a1d8`).

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
- **Private**: `https://hello-world.your-tailnet.ts.net` (via Tailscale, only from devices on your tailnet)

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
    # Optional: Add Tailscale ACL tags
    tailscale.com/tags: "tag:k8s,tag:admin"
spec:
  ingressClassName: tailscale
  tls:
    - hosts:
        - fleet-admin.your-tailnet.ts.net
  defaultBackend:
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

You can then access your service at `https://hello-world.your-tailnet.ts.net` from any device connected to your Tailnet!

## Important Notes

- **Hostname Control**: Use `spec.tls.hosts` to specify the exact hostname for your service
- **TLS Certificates**: Let's Encrypt certificates are automatically provisioned on first HTTPS access
- **Certificate Transparency**: The first access may show a CT error for a few minutes while CT logs propagate
- **Tailnet Name**: Replace `your-tailnet` with your actual Tailscale tailnet domain (find it at https://login.tailscale.com/admin/dns)
