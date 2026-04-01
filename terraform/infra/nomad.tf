# nomad
provider "nomad" {
  address = var.nomad_url
}

resource "nomad_acl_policy" "admin" {
  name        = "admin"
  description = "Policy for admin users"
  rules_hcl   = <<EOT
namespace "*" {
  policy = "write"
}

node {
  policy = "write"
}

agent {
  policy = "write"
}

host_volume "*" {
  policy = "write"
}

plugin {
  policy = "write"
}
EOT
}

resource "nomad_acl_policy" "operator" {
  name      = "nomad-gitops-operator"
  rules_hcl = <<EOT
namespace "*" {
  policy = "write"
}

host_volume "*" {
  policy = "write"
}
  EOT
}

resource "nomad_acl_policy" "nebula_cni" {
  name        = "nebula-cni"
  description = "Policy for nebula-nomad-cni plugin to read allocations and nodes"

  rules_hcl = <<-POLICY
    # Required to get allocation details including task metadata
    namespace "*" {
      capabilities = ["read-job", "list-jobs"]
    }

    # To list nodes and get node allocations
    node {
      policy = "read"
    }
  POLICY
}


resource "nomad_acl_policy" "github_runner_dispatch" {
  name        = "github-runner-dispatch"
  description = "Policy for GitHub webhook to dispatch runner jobs"
  rules_hcl   = <<-POLICY
    namespace "*" {
      policy       = "read"
      capabilities = ["dispatch-job"]
    }
  POLICY

  job_acl {
    namespace = "default"
    job_id    = "github-webhook"
  }
}

resource "nomad_acl_token" "operator_token" {
  type     = "client"
  policies = [nomad_acl_policy.operator.name]
}

resource "nomad_acl_token" "nebula_cni" {
  name     = "nebula-cni"
  type     = "client"
  policies = [nomad_acl_policy.nebula_cni.name]
}

resource "nomad_acl_token" "atlantis" {
  name     = "atlantis"
  type     = "client"
  policies = [nomad_acl_policy.operator.name]
}

resource "nomad_acl_auth_method" "authelia" {
  name              = "authelia"
  max_token_ttl     = "24h0m0s"
  token_locality    = "global"
  type              = "OIDC"
  token_name_format = "authelia-$${value.username}"
  config {
    oidc_discovery_url = "https://auth.${var.domain}"
    oidc_client_id     = "nomad"
    oidc_client_secret = var.nomad_oidc_client_secret
    bound_audiences    = ["nomad"]
    allowed_redirect_uris = [
      "${var.nomad_url}/ui/settings/tokens",
      "http://localhost:4649/oidc/callback"
    ]
    oidc_scopes         = ["openid", "profile", "groups"]
    claim_mappings      = { "preferred_username" : "username" }
    list_claim_mappings = { "groups" : "groups" }
  }
}

resource "nomad_acl_binding_rule" "authelia_admin" {
  auth_method = nomad_acl_auth_method.authelia.name
  selector    = "admin in list.groups"
  bind_type   = "policy"
  bind_name   = nomad_acl_policy.admin.name
}

resource "nomad_scheduler_config" "scheduler" {
  memory_oversubscription_enabled = true
  preemption_config = {
    batch_scheduler_enabled    = false
    service_scheduler_enabled  = false
    sysbatch_scheduler_enabled = false
    system_scheduler_enabled   = false
  }
}
