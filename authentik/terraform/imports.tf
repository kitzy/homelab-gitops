# Import blocks: adopt the objects that already exist in Authentik.
# Kept after the first apply so the history shows where each came from;
# Terraform ignores import blocks for resources already in state.

import {
  to = authentik_application.fleet_admin
  id = "fleet-admin"
}

import {
  to = authentik_application.fleet_scim_app
  id = "fleet-scim-app"
}

import {
  to = authentik_provider_scim.fleet_scim
  id = "3"
}

import {
  to = authentik_provider_saml.fleet_admin
  id = "2"
}

import {
  to = authentik_source_ldap.google_ldap
  id = "google-ldap"
}

import {
  to = authentik_source_oauth.google
  id = "google"
}

import {
  to = authentik_property_mapping_source_ldap.google_ldap_displayname_to_name
  id = "6e596271-ab01-4516-958b-9fa272990a38"
}

import {
  to = authentik_property_mapping_source_ldap.google_ldap_displayname_to_name__group
  id = "089b904e-0ac5-4136-9e40-3e579828eb56"
}

import {
  to = authentik_property_mapping_source_ldap.google_ldap_givenname_to_givenname
  id = "b6f045f2-e0d9-4d49-b67f-431d26f4cb4f"
}

import {
  to = authentik_property_mapping_source_ldap.google_ldap_mail_to_email
  id = "a7ed8937-a87c-4add-89d2-f19f54ff5dcc"
}

import {
  to = authentik_property_mapping_source_ldap.google_ldap_mail_to_username
  id = "7cef6049-8fd9-4045-893a-8c95d6a990e8"
}

import {
  to = authentik_property_mapping_source_ldap.google_ldap_objectsid_to_ldap_uniq
  id = "65509b79-6d7d-41b2-a2af-6aadc455abd5"
}

import {
  to = authentik_property_mapping_source_ldap.google_ldap_objectsid_to_ldap_uniq__group
  id = "f034f42f-6e95-41f0-8c8c-f63261cf3a9e"
}

import {
  to = authentik_property_mapping_source_ldap.google_ldap_sn_to_familyname
  id = "b52307db-d741-435f-9fad-4e45a1223849"
}

import {
  to = authentik_flow.admin_authentication_flow
  id = "admin-authentication-flow"
}

import {
  to = authentik_flow.auth_admin_local
  id = "auth-admin-local"
}

import {
  to = authentik_flow.auth_router
  id = "auth-router"
}

import {
  to = authentik_flow.auth_user_google
  id = "auth-user-google"
}

import {
  to = authentik_stage_identification.admin_identification
  id = "f6c64469-b810-41cb-bf5b-128a45770a52"
}

import {
  to = authentik_stage_authenticator_validate.admin_mfa_validate
  id = "2abddd12-8e3f-4ae6-bcee-0cd8ce26b36c"
}

import {
  to = authentik_stage_user_login.admin_user_login
  id = "739e75c0-4bd3-42bd-a644-6906e40e961b"
}

import {
  to = authentik_stage_identification.google_identification
  id = "41aab913-d70a-4842-ab86-62faed1aa03c"
}

import {
  to = authentik_stage_user_login.user_login
  id = "c2c2e0b6-e1aa-445b-a0b2-91bd9a667dcc"
}

import {
  to = authentik_stage_redirect.redirect_admin
  id = "816cb9e0-c5fa-43da-a449-3df37ae31adc"
}

import {
  to = authentik_stage_redirect.redirect_user
  id = "22a3e230-2976-4b32-a075-0016200cb843"
}

import {
  to = authentik_flow_stage_binding.auth_user_google_google_identification
  id = "02fa4af9-fdf4-4170-9dcb-91c069c2c1c8"
}

import {
  to = authentik_flow_stage_binding.admin_authentication_flow_admin_identification
  id = "4e3e0d6a-c1f3-405f-a78f-520deae0ea8a"
}

import {
  to = authentik_flow_stage_binding.auth_router_redirect_admin
  id = "8914a815-c924-4c03-8c7a-c4c173e9f25a"
}

import {
  to = authentik_flow_stage_binding.auth_admin_local_admin_identification
  id = "e4064128-24d4-4928-9c22-3713db8f7097"
}

import {
  to = authentik_flow_stage_binding.admin_authentication_flow_admin_mfa_validate
  id = "55fc935b-4cac-448d-a973-1719fff8fb7f"
}

import {
  to = authentik_flow_stage_binding.auth_admin_local_admin_user_login
  id = "055600e9-81ff-4d91-a6b7-b5839f7928d4"
}

import {
  to = authentik_flow_stage_binding.auth_user_google_user_login
  id = "4fd1b643-73b1-434c-afbc-e9e6526eb279"
}

import {
  to = authentik_flow_stage_binding.auth_admin_local_admin_mfa_validate
  id = "f15b822c-dbf7-419d-9afd-62ba2e2e2391"
}

import {
  to = authentik_flow_stage_binding.auth_router_redirect_user
  id = "b14b789b-2d41-4361-86a3-c1b5fa2d3903"
}

import {
  to = authentik_policy_expression.allow_workspace_domains
  id = "a8deda4e-f010-474a-bc51-a407260ed970"
}

import {
  to = authentik_policy_expression.is_admin
  id = "b95cfca6-eae5-40c6-ac93-ff10a530e2c1"
}

import {
  to = authentik_policy_expression.is_admin_interface
  id = "352fda38-a789-431c-84af-bc599cefa7ff"
}

import {
  to = authentik_policy_expression.map_username_to_email
  id = "0a68136f-c2cf-456c-aedf-f158a1484de8"
}

import {
  to = authentik_policy_binding.is_admin_interface
  id = "080fc51e-c2bc-4001-b7fe-298d6c7335b7"
}

import {
  to = authentik_policy_binding.allow_workspace_domains
  id = "4578dba3-1eee-4b81-b982-db6b00f0dc30"
}

import {
  to = authentik_policy_binding.is_admin
  id = "4767c938-ecb6-42d7-bc68-8fbfe0c0aa0b"
}

import {
  to = authentik_policy_binding.map_username_to_email
  id = "95776434-86a6-4612-803a-f74659d2dcf8"
}

import {
  to = authentik_group.authentik_admins
  id = "5df688cb-00dd-4d2e-8192-998dc3aa262e"
}

import {
  to = authentik_group.synology_nas
  id = "ee3c5a93-40e0-4d9c-a7bf-928954e0e4d2"
}

import {
  to = authentik_group.test
  id = "ce6d7a6b-73f3-41ff-9646-97a4e7bdd070"
}

import {
  to = authentik_brand.default
  id = "a252757c-909e-4c30-8bf9-96e1da1e35c9"
}

