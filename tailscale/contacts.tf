# Tailnet contact emails (account / support / security), captured verbatim.
resource "tailscale_contacts" "homelab" {
  account {
    email = "kitzy@kitzy.com"
  }
  support {
    email = "kitzy@kitzy.com"
  }
  security {
    email = "kitzy@kitzy.com"
  }
}
