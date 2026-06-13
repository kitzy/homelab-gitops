# Tailnet policy file: ACLs, grants, tag owners, and Tailscale SSH rules.
# The source of truth is policy.hujson (HuJSON — comments are preserved on apply).
resource "tailscale_acl" "homelab" {
  acl = file("${path.module}/policy.hujson")

  # policy.hujson was seeded verbatim from the live tailnet, so the first apply
  # only adds the resource to Terraform state and pushes an identical policy —
  # a no-op against the tailnet. overwrite_existing_content lets Terraform take
  # ownership without a prior `terraform import` of the existing policy.
  overwrite_existing_content = true
}
