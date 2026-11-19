output "ci_workload_identity_provider" {
  description = "For google-github-actions/auth in the workflow."
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "ci_service_account" {
  value = google_service_account.terraform.email
}

output "fleet_directory_sync_client_id" {
  description = "Client ID to authorize for domain-wide delegation in the Google Admin console."
  value       = google_service_account.fleet_directory_sync.unique_id
}

output "fleet_directory_sync_key_json" {
  description = "JSON key to paste into Fleet's Google Workspace integration."
  value       = base64decode(google_service_account_key.fleet_directory_sync.private_key)
  sensitive   = true
}
