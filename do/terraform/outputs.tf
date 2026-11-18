output "r2_s3_endpoint" {
  description = "S3 API endpoint for the account's R2 buckets."
  value       = "https://${var.cloudflare_account_id}.r2.cloudflarestorage.com"
}

output "r2_buckets" {
  description = "R2 bucket names."
  value = {
    fleet_installers = cloudflare_r2_bucket.fleet_installers.name
    backups          = cloudflare_r2_bucket.backups.name
  }
}
