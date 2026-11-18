variable "cloudflare_account_id" {
  description = "Cloudflare account that owns the R2 buckets. CI sets TF_VAR_cloudflare_account_id from 1Password."
  type        = string
}
