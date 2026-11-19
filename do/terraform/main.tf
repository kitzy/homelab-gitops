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

# Authentik's uploaded files: application and source icons, brand logos,
# flow backgrounds. App Platform has no volumes, so Authentik's S3 backend
# stores them here and browsers load them through short-lived presigned URLs.
resource "cloudflare_r2_bucket" "authentik_files" {
  account_id    = var.cloudflare_account_id
  name          = "kitzy-authentik-files"
  location      = "enam"
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}

# Browsers fetch the presigned URLs cross-origin from auth.kitzy.net
# (authentik docs: sys-mgmt/ops/storage-s3).
resource "cloudflare_r2_bucket_cors" "authentik_files" {
  account_id  = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.authentik_files.name

  rules = [{
    allowed = {
      origins = ["https://auth.kitzy.net"]
      methods = ["GET"]
      headers = ["Authorization"]
    }
    max_age_seconds = 3000
  }]
}

