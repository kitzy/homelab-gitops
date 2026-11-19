# Keyless access for GitHub Actions. The workflow exchanges its GitHub OIDC
# token for a short-lived Google token through this pool, then impersonates
# the `terraform` service account. Only runs from kitzy/homelab-gitops are
# accepted. No service account key exists for CI.

resource "google_iam_workload_identity_pool" "github" {
  workload_identity_pool_id = "github"
  display_name              = "GitHub Actions"
  depends_on                = [google_project_service.this]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "homelab-gitops"
  display_name                       = "kitzy/homelab-gitops"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }
  attribute_condition = "assertion.repository == '${local.github_repo}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# The identity CI runs Terraform as. Project-level admin of exactly what this
# root manages, nothing at the organization level.
resource "google_service_account" "terraform" {
  account_id   = "terraform"
  display_name = "Terraform (homelab-gitops CI)"
  depends_on   = [google_project_service.this]
}

resource "google_project_iam_member" "terraform" {
  for_each = toset([
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountKeyAdmin",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/serviceusage.serviceUsageAdmin",
  ])

  project = local.project_id
  role    = each.key
  member  = "serviceAccount:${google_service_account.terraform.email}"
}

resource "google_service_account_iam_member" "terraform_github" {
  service_account_id = google_service_account.terraform.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${local.github_repo}"
}
