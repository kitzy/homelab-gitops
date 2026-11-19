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

## Fleet and Google Workspace

Fleet's admin sign-in and its IdP host vitals (full name, groups,
department) come from Google Workspace. Two pieces are configured in the
Google Admin console, because Google publishes no API for them; their exact
values are kept here. The Fleet side is code in
[kitzy/fleet-gitops](https://github.com/kitzy/fleet-gitops) (`default.yml`).

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
| Certificate | The IdP certificate created 2026-11-19, valid until 2031-11-18 (the older one had expired) |

Download the IdP metadata (XML) on the app's page. It goes into
`op://GitHub/FleetSecrets/SSO_METADATA` for fleet-gitops `sso_settings.metadata`,
**on one line**: fleetctl inserts environment values into the YAML text
unescaped, so a multi-line value breaks `default.yml`. When the certificate is
rotated (add a new one, select it for the app), download the metadata again,
since it embeds the certificate.

### Fleet directory sync: domain-wide delegation

Admin console > Security > Access and data control > API controls >
Manage domain-wide delegation > Add new. A super admin must do this.

| Setting | Value |
| --- | --- |
| Client ID | `110911369357226466616` (`fleet-directory-sync@kitzy-homelab.iam.gserviceaccount.com`; also the `fleet_directory_sync_client_id` Terraform output) |
| OAuth scopes | `https://www.googleapis.com/auth/admin.directory.user.readonly,https://www.googleapis.com/auth/admin.directory.group.readonly,https://www.googleapis.com/auth/admin.directory.group.member.readonly` |

### Fleet side (in kitzy/fleet-gitops `default.yml`)

| Setting | Value |
| --- | --- |
| `sso_settings` | `entity_id: fleet`, `idp_name: Google`, `metadata: '${SSO_METADATA}'` |
| `integrations.google_workspace` | `api_key_json` from `op://GitHub/Fleet Google Workspace/service_account_json`, domain `kitzy.com`, impersonating `admin-kitzy@kitzy.com` |

Fleet syncs the directory every 5 minutes and ignores SCIM while the Google
Workspace integration is configured.

### Users, groups, org units

Managed in the Admin console. The `hashicorp/googleworkspace` Terraform
provider is archived (no releases, issues or PRs), so it is not used.
