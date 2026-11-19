# Secrets the Authentik API never returns. CI reads them from 1Password.

variable "google_ldap_bind_password" {
  description = "Google Workspace Secure LDAP access credential password (op://GitHub/Authentik Terraform secrets)."
  type        = string
  sensitive   = true
}

variable "google_oauth_client_secret" {
  description = "Client secret of the Google OAuth client used by the google source."
  type        = string
  sensitive   = true
}

variable "fleet_scim_token" {
  description = "Fleet API token that the Fleet SCIM provider authenticates with."
  type        = string
  sensitive   = true
}
