# Fleet's Google Workspace integration reads users, groups and departments
# through the Admin SDK Directory API as this service account (Fleet:
# Settings > Integrations > Identity provider). It needs domain-wide
# delegation with three read-only scopes, which only a super admin can grant
# in the Admin console: see google/README.md.

resource "google_service_account" "fleet_directory_sync" {
  account_id   = "fleet-directory-sync"
  display_name = "Fleet directory sync"
  description  = "Fleet's Google Workspace integration (read-only directory access via domain-wide delegation)"
  depends_on   = [google_project_service.this]
}

# Fleet takes the JSON key. It lands in Terraform state (HCP, encrypted), as
# the provider documents; rotate by tainting this resource.
resource "google_service_account_key" "fleet_directory_sync" {
  service_account_id = google_service_account.fleet_directory_sync.name
}
