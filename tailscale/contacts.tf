# Tailnet contact emails (account / support / security). The address is supplied
# via the contact_email variable (from 1Password in CI) rather than committed —
# see variables.tf.
resource "tailscale_contacts" "homelab" {
  account {
    email = var.contact_email
  }
  support {
    email = var.contact_email
  }
  security {
    email = var.contact_email
  }
}
