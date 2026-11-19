# authentik/

Authentik's configuration as code: the `goauthentik/authentik` Terraform
provider, applied by `.github/workflows/authentik-terraform.yaml` (plan on
pull requests, apply on merge). State lives in the HCP Terraform workspace
`homelab-authentik` (org `kitzy_net`, Local execution mode).

Change Authentik through this directory, not the admin UI: an apply puts
back anything managed here that was changed by hand.

## What is managed

| File | Contents |
| --- | --- |
| `fleet.tf` | Fleet (Admin) SAML application and provider; Fleet SCIM application and provider |
| `sources.tf` | Google OAuth source; Google Workspace LDAP source and its 8 property mappings |
| `flows.tf` | Login routing: `auth-router` (the brand's login flow) sends `/if/admin` requests to `admin-authentication-flow` (identify, then MFA) and everyone else to `auth-user-google`; `auth-admin-local` is a local admin login with MFA. Their stages, stage bindings, expression policies and policy bindings |
| `groups.tf` | `authentik Admins` (membership is not managed). Groups from Google Workspace (`Synology NAS`, `test`, `Amazon Web Services`) belong to the LDAP sync, not Terraform |
| `brand.tf` | The default brand's flows |
| `data.tf` | Built-in objects referred to but not managed: default flows and stages, SAML/SCIM property mappings, the `saml-signing` certificate |
| `imports.tf` | How each object was adopted from the running Authentik (2026-11-19) |

Not managed: users, groups synced from Google LDAP, Authentik's built-in default flows/stages/policies (they
come from Authentik's own blueprints), certificates (no key material in the
config), the embedded outpost.

## Secrets

The Authentik API never returns these, so they come from 1Password (`GitHub`
vault) as Terraform variables:

| Item | Field | Used for |
| --- | --- | --- |
| `Authentik Terraform` | `credential` | API token of the `terraform` service account (authentik Admins) |
| `Authentik Terraform secrets` | `google_ldap_bind_password` | Google Secure LDAP access credential (copy of `Homelab/Google LDAP Authentik`) |
| | `google_oauth_client_secret` | Google OAuth client of the `google` source |
| | `fleet_scim_token` | Fleet API token used by the Fleet SCIM provider |

## Notes

- Authentik runs one web worker; the workflow uses `-parallelism=2` because
  more concurrent API calls made it return 500s.
- The login stages bind sessions to continent and network (ASN). The
  provider's default is no binding, so `geoip_binding` / `network_binding`
  must stay explicit in `flows.tf`.
