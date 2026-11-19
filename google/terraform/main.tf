# Google Cloud project for the homelab. The project itself was created by
# hand (2026-11-19, `gcloud projects create kitzy-homelab --organization
# 489946875572`): creating projects needs organization-level rights that CI
# should not have. Everything inside it is managed here.
locals {
  project_id     = "kitzy-homelab"
  project_number = "421341155790"
  github_repo    = "kitzy/homelab-gitops"
}

resource "google_project_service" "this" {
  for_each = toset([
    "admin.googleapis.com",                # Admin SDK: Fleet's directory sync
    "cloudresourcemanager.googleapis.com", # project IAM
    "iam.googleapis.com",                  # service accounts
    "iamcredentials.googleapis.com",       # CI impersonation tokens
    "sts.googleapis.com",                  # workload identity federation
  ])

  service = each.key
  # Turning an API off could break whatever still uses it; never do it from
  # a refactor.
  disable_on_destroy = false
}
