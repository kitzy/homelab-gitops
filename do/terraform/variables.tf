variable "cloudflare_account_id" {
  description = "Cloudflare account that owns the R2 buckets. CI sets TF_VAR_cloudflare_account_id from 1Password."
  type        = string
}

# App secrets. CI sets these as TF_VAR_* from op://GitHub/homelab-do app
# secrets and op://GitHub/R2 backups homelab-do.

variable "fleet_server_private_key" {
  type      = string
  sensitive = true
}

variable "fleet_license_key" {
  type      = string
  sensitive = true
}


variable "restic_password" {
  type      = string
  sensitive = true
}

variable "r2_backups_access_key_id" {
  type      = string
  sensitive = true
}

variable "r2_backups_secret_access_key" {
  type      = string
  sensitive = true
}

variable "hc_backup_url" {
  type      = string
  sensitive = true
}

variable "hc_check_url" {
  type      = string
  sensitive = true
}

variable "fleet_r2_access_key_id" {
  description = "S3 key pair scoped to the kitzy-fleet-installers R2 bucket (op://GitHub/Fleet R2 homelab-do)."
  type        = string
  sensitive   = true
}

variable "fleet_r2_secret_access_key" {
  type      = string
  sensitive = true
}


