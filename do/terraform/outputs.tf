output "r2_s3_endpoint" {
  description = "S3 API endpoint for the account's R2 buckets."
  value       = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
}

output "r2_buckets" {
  description = "R2 bucket names."
  value = {
    fleet_installers = cloudflare_r2_bucket.fleet_installers.name
    backups          = cloudflare_r2_bucket.backups.name
    authentik_files  = cloudflare_r2_bucket.authentik_files.name
  }
}

output "app_default_urls" {
  description = "Default *.ondigitalocean.app URLs. The DNS CNAMEs for each app's domain point at its host."
  value = {
    authentik = digitalocean_app.authentik.default_ingress
    fleet     = digitalocean_app.fleet.default_ingress
  }
}

output "backups_app_id" {
  description = "App ID of the backups app. The workflow force-rebuilds it when do/backup/ changes."
  value       = digitalocean_app.backups.id
}
