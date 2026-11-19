# The default brand: which flows handle login, logout and user settings.

resource "authentik_brand" "default" {
  attributes                       = jsonencode({})
  branding_default_flow_background = "/static/dist/assets/images/flow_background.jpg"
  branding_favicon                 = "/static/dist/assets/icons/icon.png"
  branding_logo                    = "/static/dist/assets/icons/icon_left_brand.svg"
  branding_title                   = "authentik"
  client_certificates              = []
  default                          = true
  domain                           = "authentik-default"
  flow_authentication              = authentik_flow.auth_router.uuid
  flow_invalidation                = data.authentik_flow.default_invalidation_flow.id
  flow_user_settings               = data.authentik_flow.default_user_settings_flow.id
}
