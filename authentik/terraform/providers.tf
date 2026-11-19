provider "authentik" {
  # Reads AUTHENTIK_URL and AUTHENTIK_TOKEN. CI loads the token from
  # op://GitHub/Authentik Terraform (the `terraform` service account, an
  # authentik Admins member).
}
