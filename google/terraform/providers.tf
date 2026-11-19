provider "google" {
  project = local.project_id
  # Bill API quota to this project, not to the caller's default.
  user_project_override = true
  billing_project       = local.project_id
  # CI authenticates keylessly through workload identity federation (see
  # ci.tf and .github/workflows/google-terraform.yaml).
}
