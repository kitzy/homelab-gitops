# Cloudflare R2 buckets for the DigitalOcean move (see do/README.md).
#
# Each bucket has an object read/write token scoped to that bucket alone. The
# tokens are created outside Terraform: creating API tokens needs the Account
# API Tokens Write permission, which would let this root mint a token with any
# permission. They live in 1Password and reach the apps from there.

# Fleet software installers, plus everything Fleet keeps in the same bucket:
# software icons, bootstrap packages and org logos.
resource "cloudflare_r2_bucket" "fleet_installers" {
  account_id    = var.cloudflare_account_id
  name          = "kitzy-fleet-installers"
  location      = "enam"
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}

# Off-site restic repository for the nightly database dumps.
resource "cloudflare_r2_bucket" "backups" {
  account_id    = var.cloudflare_account_id
  name          = "kitzy-homelab-backups"
  location      = "enam"
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}
