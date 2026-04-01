### AWS KMS key for Vault auto-unseal

resource "aws_kms_key" "vault_unseal" {
  description             = "KMS key for Vault auto-unseal"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  multi_region            = false

  tags = {
    Name    = "vault-unseal"
    Purpose = "vault-auto-unseal"
  }
}

resource "aws_kms_alias" "vault_unseal" {
  name          = "alias/vault-unseal"
  target_key_id = aws_kms_key.vault_unseal.key_id
}


resource "aws_iam_user" "vault_unseal" {
  name = "vault-unseal"
  path = "/system/"

  tags = {
    Purpose = "vault-auto-unseal"
  }
}

resource "aws_iam_access_key" "vault_unseal" {
  user = aws_iam_user.vault_unseal.name
}

resource "aws_iam_user_policy" "vault_unseal" {
  name = "vault-unseal-kms"
  user = aws_iam_user.vault_unseal.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "VaultUnsealKMS"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:DescribeKey",
        ]
        Resource = aws_kms_key.vault_unseal.arn
      }
    ]
  })
}

###

provider "vault" {}

resource "vault_policy" "admin" {
  name   = "admin"
  policy = <<EOT
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOT
}


resource "vault_jwt_auth_backend" "authelia" {
  description        = "Authelia OIDC"
  path               = "oidc"
  type               = "oidc"
  oidc_discovery_url = "https://auth.${var.domain}"
  oidc_client_id     = "vault"
  oidc_client_secret = var.authelia_oidc_client_secret
  default_role       = "admin"

  tune {
    listing_visibility = "unauth"
  }
}


resource "vault_jwt_auth_backend_role" "admin" {
  backend        = vault_jwt_auth_backend.authelia.path
  role_name      = "admin"
  token_policies = [vault_policy.admin.name]

  user_claim   = "preferred_username"
  groups_claim = "groups"

  oidc_scopes = ["openid", "profile", "groups", "email"]

  # Allow the UI and the local CLI to receive the auth callbacks
  allowed_redirect_uris = [
    "https://vault.local.${var.domain}/ui/vault/auth/oidc/oidc/callback",
    "http://localhost:8250/oidc/callback"
  ]

  bound_claims_type = "string"
  bound_claims = {
    groups = "admin"
  }
}


resource "vault_mount" "kvv2" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "Standard KV-V2 Mount"
}


resource "vault_consul_secret_backend" "consul" {
  path        = "consul"
  description = "Consul Secrets Engine for dynamic ACL tokens"
  address     = "https://consul.local.${var.domain}"
  token       = var.consul_bootstrap_token
}

resource "vault_consul_secret_backend_role" "example_client" {
  name    = "example-client-role"
  backend = vault_consul_secret_backend.consul.path

  # Link this to an existing Consul policy name.
  consul_policies = [
    consul_acl_policy.base_agent.name
  ]

  ttl     = 3600  # 1 hour
  max_ttl = 86400 # 24 hours
}

# Module to setup Vault with Nomad Workload Identities
module "vault_setup" {
  source = "./vault-nomad-setup"

  nomad_jwks_url = "${var.nomad_url}/.well-known/jwks.json"

  policy_names = [
    vault_policy.nomad_workloads.name,
  ]
}

resource "vault_policy" "nomad_workloads" {
  name   = "nomad-workloads"
  policy = <<EOT
path "secret/data/{{identity.entity.aliases.${module.vault_setup.auth_backend_accessor}.metadata.nomad_namespace}}/{{identity.entity.aliases.${module.vault_setup.auth_backend_accessor}.metadata.nomad_job_id}}/*" {
  capabilities = ["read"]
}

path "secret/data/{{identity.entity.aliases.${module.vault_setup.auth_backend_accessor}.metadata.nomad_namespace}}/{{identity.entity.aliases.${module.vault_setup.auth_backend_accessor}.metadata.nomad_job_id}}" {
  capabilities = ["read"]
}

path "secret/metadata/{{identity.entity.aliases.${module.vault_setup.auth_backend_accessor}.metadata.nomad_namespace}}/*" {
  capabilities = ["list"]
}

path "secret/metadata/*" {
  capabilities = ["list"]
}


path "kv/data/{{identity.entity.aliases.${module.vault_setup.auth_backend_accessor}.metadata.nomad_namespace}}/{{identity.entity.aliases.${module.vault_setup.auth_backend_accessor}.metadata.nomad_job_id}}/*" {
  capabilities = ["read"]
}

path "kv/data/{{identity.entity.aliases.${module.vault_setup.auth_backend_accessor}.metadata.nomad_namespace}}/{{identity.entity.aliases.${module.vault_setup.auth_backend_accessor}.metadata.nomad_job_id}}" {
  capabilities = ["read"]
}

path "kv/metadata/{{identity.entity.aliases.${module.vault_setup.auth_backend_accessor}.metadata.nomad_namespace}}/*" {
  capabilities = ["list"]
}

path "kv/metadata/*" {
  capabilities = ["list"]
}
EOT
}
