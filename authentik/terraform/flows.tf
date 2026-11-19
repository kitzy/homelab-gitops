# Login routing. The brand sends every login to auth-router, which sends
# admin-interface requests to admin-authentication-flow (identify, then MFA)
# and everyone else to auth-user-google (Google sign-in). auth-admin-local is
# a local admin login with MFA.

resource "authentik_flow" "admin_authentication_flow" {
  # Empty: Authentik shows its default background. The provider would
  # otherwise write its default image path explicitly.
  background         = ""
  authentication     = "require_authenticated"
  compatibility_mode = false
  denied_action      = "message_continue"
  designation        = "authentication"
  layout             = "stacked"
  name               = "admin-authentication-flow"
  policy_engine_mode = "any"
  slug               = "admin-authentication-flow"
  title              = "admin-authentication-flow"
}

resource "authentik_flow" "auth_admin_local" {
  # Empty: Authentik shows its default background. The provider would
  # otherwise write its default image path explicitly.
  background         = ""
  authentication     = "none"
  compatibility_mode = false
  denied_action      = "message_continue"
  designation        = "authentication"
  layout             = "stacked"
  name               = "auth-admin-local"
  policy_engine_mode = "any"
  slug               = "auth-admin-local"
  title              = "auth-admin-local"
}

resource "authentik_flow" "auth_router" {
  # Empty: Authentik shows its default background. The provider would
  # otherwise write its default image path explicitly.
  background         = ""
  authentication     = "none"
  compatibility_mode = false
  denied_action      = "message_continue"
  designation        = "authentication"
  layout             = "stacked"
  name               = "auth-router"
  policy_engine_mode = "any"
  slug               = "auth-router"
  title              = "auth-router"
}

resource "authentik_flow" "auth_user_google" {
  # Empty: Authentik shows its default background. The provider would
  # otherwise write its default image path explicitly.
  background         = ""
  authentication     = "none"
  compatibility_mode = false
  denied_action      = "message_continue"
  designation        = "authentication"
  layout             = "stacked"
  name               = "auth-user-google"
  policy_engine_mode = "any"
  slug               = "auth-user-google"
  title              = "auth-user-google"
}

resource "authentik_flow_stage_binding" "admin_authentication_flow_admin_identification" {
  evaluate_on_plan        = false
  invalid_response_action = "retry"
  order                   = 0
  policy_engine_mode      = "any"
  re_evaluate_policies    = true
  stage                   = authentik_stage_identification.admin_identification.id
  target                  = authentik_flow.admin_authentication_flow.uuid
}

resource "authentik_flow_stage_binding" "admin_authentication_flow_admin_mfa_validate" {
  evaluate_on_plan        = false
  invalid_response_action = "retry"
  order                   = 1
  policy_engine_mode      = "any"
  re_evaluate_policies    = true
  stage                   = authentik_stage_authenticator_validate.admin_mfa_validate.id
  target                  = authentik_flow.admin_authentication_flow.uuid
}

resource "authentik_flow_stage_binding" "auth_admin_local_admin_identification" {
  evaluate_on_plan        = false
  invalid_response_action = "retry"
  order                   = 0
  policy_engine_mode      = "any"
  re_evaluate_policies    = true
  stage                   = authentik_stage_identification.admin_identification.id
  target                  = authentik_flow.auth_admin_local.uuid
}

resource "authentik_flow_stage_binding" "auth_admin_local_admin_mfa_validate" {
  evaluate_on_plan        = false
  invalid_response_action = "retry"
  order                   = 20
  policy_engine_mode      = "any"
  re_evaluate_policies    = true
  stage                   = authentik_stage_authenticator_validate.admin_mfa_validate.id
  target                  = authentik_flow.auth_admin_local.uuid
}

resource "authentik_flow_stage_binding" "auth_admin_local_admin_user_login" {
  evaluate_on_plan        = false
  invalid_response_action = "retry"
  order                   = 10
  policy_engine_mode      = "any"
  re_evaluate_policies    = true
  stage                   = authentik_stage_user_login.admin_user_login.id
  target                  = authentik_flow.auth_admin_local.uuid
}

resource "authentik_flow_stage_binding" "auth_router_redirect_admin" {
  evaluate_on_plan        = false
  invalid_response_action = "retry"
  order                   = 0
  policy_engine_mode      = "any"
  re_evaluate_policies    = true
  stage                   = authentik_stage_redirect.redirect_admin.id
  target                  = authentik_flow.auth_router.uuid
}

resource "authentik_flow_stage_binding" "auth_router_redirect_user" {
  evaluate_on_plan        = false
  invalid_response_action = "retry"
  order                   = 100
  policy_engine_mode      = "any"
  re_evaluate_policies    = true
  stage                   = authentik_stage_redirect.redirect_user.id
  target                  = authentik_flow.auth_router.uuid
}

resource "authentik_flow_stage_binding" "auth_user_google_google_identification" {
  evaluate_on_plan        = false
  invalid_response_action = "retry"
  order                   = 0
  policy_engine_mode      = "any"
  re_evaluate_policies    = true
  stage                   = authentik_stage_identification.google_identification.id
  target                  = authentik_flow.auth_user_google.uuid
}

resource "authentik_flow_stage_binding" "auth_user_google_user_login" {
  evaluate_on_plan        = false
  invalid_response_action = "retry"
  order                   = 10
  policy_engine_mode      = "any"
  re_evaluate_policies    = true
  stage                   = authentik_stage_user_login.user_login.id
  target                  = authentik_flow.auth_user_google.uuid
}

resource "authentik_stage_identification" "admin_identification" {
  case_insensitive_matching = true
  enable_remember_me        = false
  name                      = "admin-identification"
  pretend_user_exists       = true
  show_matched_user         = true
  show_source_labels        = false
  sources                   = [authentik_source_oauth.google.uuid]
  user_fields               = ["username", "email"]
}

resource "authentik_stage_identification" "google_identification" {
  case_insensitive_matching = true
  enable_remember_me        = false
  name                      = "google-identification"
  pretend_user_exists       = true
  show_matched_user         = true
  show_source_labels        = false
  sources                   = [authentik_source_oauth.google.uuid]
  user_fields               = []
}

resource "authentik_stage_authenticator_validate" "admin_mfa_validate" {
  configuration_stages          = [data.authentik_stage.default_authenticator_totp_setup.id, data.authentik_stage.default_authenticator_webauthn_setup.id]
  device_classes                = ["totp", "webauthn"]
  email_otp_throttling_factor   = 1
  last_auth_threshold           = "seconds=0"
  name                          = "admin-mfa-validate"
  not_configured_action         = "configure"
  sms_otp_throttling_factor     = 1
  static_otp_throttling_factor  = 1
  totp_otp_throttling_factor    = 1
  webauthn_allowed_device_types = []
  webauthn_hints                = []
  webauthn_user_verification    = "required"
}

resource "authentik_stage_user_login" "admin_user_login" {
  # Bind sessions to the continent and network (ASN) they started from.
  # The provider default is no_binding, so these must stay explicit.
  geoip_binding            = "bind_continent"
  network_binding          = "bind_asn"
  name                     = "admin-user-login"
  remember_device          = "days=30"
  remember_me_offset       = "seconds=0"
  session_duration         = "seconds=0"
  terminate_other_sessions = false
}

resource "authentik_stage_user_login" "user_login" {
  # Bind sessions to the continent and network (ASN) they started from.
  # The provider default is no_binding, so these must stay explicit.
  geoip_binding            = "bind_continent"
  network_binding          = "bind_asn"
  name                     = "user-login"
  remember_device          = "days=30"
  remember_me_offset       = "seconds=0"
  session_duration         = "seconds=0"
  terminate_other_sessions = false
}

resource "authentik_stage_redirect" "redirect_admin" {
  keep_context = true
  mode         = "flow"
  name         = "redirect-admin"
  target_flow  = authentik_flow.auth_admin_local.uuid
}

resource "authentik_stage_redirect" "redirect_user" {
  keep_context = true
  mode         = "flow"
  name         = "redirect-user"
  target_flow  = authentik_flow.auth_user_google.uuid
}

resource "authentik_policy_expression" "allow_workspace_domains" {
  execution_logging = false
  expression        = "allowed = {\"kitzy.com\", \"kitzy.net\"}\nctx = request.context or {}\nemail = (ctx.get(\"oauth_userinfo\", {}) or ctx.get(\"jwt\", {})).get(\"email\") or (user and user.email) or \"\"\nhd = (ctx.get(\"oauth_userinfo\", {}) or ctx.get(\"jwt\", {})).get(\"hd\", \"\")\ndomain = (hd or email.split(\"@\")[-1]).lower()\nreturn domain in allowed"
  name              = "allow-workspace-domains"
}

resource "authentik_policy_expression" "is_admin" {
  execution_logging = false
  expression        = "# allow superusers or members of \"admins\"\nreturn user.is_superuser or user.groups.filter(name=\"authentik Admins\").exists()"
  name              = "is-admin"
}

resource "authentik_policy_expression" "is_admin_interface" {
  execution_logging = false
  expression        = "req = request.http_request\nreturn bool(req) and req.path.startswith('/if/admin')"
  name              = "is-admin-interface"
}

resource "authentik_policy_expression" "map_username_to_email" {
  execution_logging = false
  expression        = "email = request.context[\"prompt_data\"][\"email\"]\n# Direct set username to email\nrequest.context[\"prompt_data\"][\"username\"] = email\n# Set username to email without domain\n# request.context[\"prompt_data\"][\"username\"] = email.split(\"@\")[0]\nreturn False"
  name              = "map-username-to-email"
}

resource "authentik_policy_binding" "allow_workspace_domains" {
  enabled        = true
  failure_result = false
  negate         = false
  order          = 0
  policy         = authentik_policy_expression.allow_workspace_domains.id
  target         = authentik_source_oauth.google.uuid
  timeout        = 30
  user           = 0
}

resource "authentik_policy_binding" "is_admin" {
  enabled        = true
  failure_result = false
  negate         = false
  order          = 0
  policy         = authentik_policy_expression.is_admin.id
  target         = authentik_flow.admin_authentication_flow.uuid
  timeout        = 30
  user           = 0
}

resource "authentik_policy_binding" "is_admin_interface" {
  enabled        = true
  failure_result = false
  negate         = false
  order          = 0
  policy         = authentik_policy_expression.is_admin_interface.id
  target         = authentik_flow_stage_binding.auth_router_redirect_admin.id
  timeout        = 30
  user           = 0
}

resource "authentik_policy_binding" "map_username_to_email" {
  enabled        = true
  failure_result = false
  negate         = false
  order          = 0
  policy         = authentik_policy_expression.map_username_to_email.id
  target         = data.authentik_flow.default_source_enrollment.id
  timeout        = 30
  user           = 0
}
