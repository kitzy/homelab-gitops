variable "contact_email" {
  description = "Email for the tailnet account/support/security contacts. Supplied via TF_VAR_contact_email (sourced from 1Password in CI) so it is never committed to the repo."
  type        = string
  sensitive   = true
}
