# Groups native to Authentik. Membership is not managed here.

resource "authentik_group" "authentik_admins" {
  attributes   = jsonencode({})
  is_superuser = true
  name         = "authentik Admins"
  parents      = []
  roles        = []
  users        = [5, 8, 9976]

  # Membership is managed in Authentik (and by the Google LDAP sync).
  lifecycle {
    ignore_changes = [users]
  }
}

# Google Workspace groups ("Synology NAS", "test", "Amazon Web Services")
# come from the Google LDAP source, which creates and updates them on every
# sync. They are owned there, not here; these were adopted by mistake and are
# released from Terraform without being deleted.
removed {
  from = authentik_group.synology_nas
  lifecycle {
    destroy = false
  }
}

removed {
  from = authentik_group.test
  lifecycle {
    destroy = false
  }
}
