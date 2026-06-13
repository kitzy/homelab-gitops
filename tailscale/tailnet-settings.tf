# Tailnet-wide settings (admin console "Settings"). Captured verbatim from the
# live tailnet, with ONE deliberate change: acls_externally_managed_on is set to
# true. Because the policy file is managed by Terraform/GitOps in this repo, this
# locks the admin-console ACL editor to prevent out-of-band edits and drift, and
# surfaces a link back to where the ACL actually lives.
resource "tailscale_tailnet_settings" "homelab" {
  acls_externally_managed_on = true
  acls_external_link         = "https://github.com/kitzy/homelab-gitops/tree/main/tailscale"

  devices_approval_on            = false
  devices_auto_updates_on        = true
  devices_key_duration_days      = 180
  https_enabled                  = true
  network_flow_logging_on        = false
  posture_identity_collection_on = false
  regional_routing_on            = false
  users_approval_on              = true

  users_role_allowed_to_join_external_tailnet = "admin"
}
