provider "cloudflare" {
  # Reads the API token from CLOUDFLARE_API_TOKEN. CI loads it from
  # op://GitHub/Cloudflare R2 Terraform (see .github/workflows/do-terraform.yaml).
  # The token has Workers R2 Storage Read + Write only: it can manage buckets,
  # but not zones or API tokens.
}
