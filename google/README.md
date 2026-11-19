# google/

Google Cloud and Google Workspace pieces of the homelab.

## Terraform (`google/terraform/`)

Manages the Google Cloud project **`kitzy-homelab`** (number 421341155790,
organization `kitzy.com`), applied by `.github/workflows/google-terraform.yaml`
(plan on pull requests, apply on merge). State: HCP workspace
`homelab-google` (org `kitzy_net`, Local execution mode).

| File | Contents |
| --- | --- |
| `main.tf` | Enabled APIs: Admin SDK, Cloud Resource Manager, IAM, IAM Credentials, STS |
| `ci.tf` | Keyless CI: workload identity pool `github` whose provider accepts only `kitzy/homelab-gitops`, and the `terraform` service account CI impersonates (project-level admin of what this root manages, nothing at the organization level) |
| `fleet.tf` | `fleet-directory-sync` service account and its JSON key, for Fleet's Google Workspace integration |

CI needs no Google secret: `google-github-actions/auth` exchanges the run's
GitHub OIDC token for a short-lived token through the pool.

The project itself was created by hand (2026-11-19): creating projects needs
organization rights that CI should not hold. The first apply ran locally as
a super admin to create the CI identity; every apply since runs in CI.

## Not manageable as code

Google publishes no API for these, so they are configured in the Admin
console. The exact values are kept here.

### Fleet admin SSO: custom SAML app

Admin console > Apps > Web and mobile apps > Add app > Add custom SAML app.

| Setting | Value |
| --- | --- |
| App name | `Fleet` |
| ACS URL | `https://fleet.kitzy.net/api/v1/fleet/sso/callback` |
| Entity ID | `fleet` (must match `sso_settings.entity_id` in kitzy/fleet-gitops) |
| Start URL | empty |
| Signed response | off (Fleet accepts signed assertions) |
| Name ID format | `EMAIL` |
| Name ID | Basic Information > Primary email |
| Attribute mapping | none required: Fleet users already exist; their emails must match Google primary emails |
| User access | ON for everyone (Fleet only admits users that exist in Fleet) |

Download the IdP metadata (XML) on the app's page. It goes into
`op://GitHub/FleetSecrets/SSO_METADATA` for fleet-gitops `sso_settings.metadata`.

### Fleet directory sync: domain-wide delegation

Admin console > Security > Access and data control > API controls >
Manage domain-wide delegation > Add new. A super admin must do this.

| Setting | Value |
| --- | --- |
| Client ID | `110911369357226466616` (`fleet-directory-sync@kitzy-homelab.iam.gserviceaccount.com`; also the `fleet_directory_sync_client_id` Terraform output) |
| OAuth scopes | `https://www.googleapis.com/auth/admin.directory.user.readonly,https://www.googleapis.com/auth/admin.directory.group.readonly,https://www.googleapis.com/auth/admin.directory.group.member.readonly` |

### Fleet: Google Workspace integration

Fleet's GitOps YAML has no setting for this, so it is set once in Fleet:
Settings > Integrations > Identity provider (IdP) > Google Workspace.

| Field | Value |
| --- | --- |
| Service account JSON | `op://GitHub/Fleet Google Workspace/service_account_json` |
| Primary domain | `kitzy.com` |
| Admin email to impersonate | a super admin, e.g. `admin-kitzy@kitzy.com` |

Fleet ignores SCIM while this is configured.

### Users, groups, org units

Managed in the Admin console. The `hashicorp/googleworkspace` Terraform
provider is archived (no releases, issues or PRs), so it is not used.
