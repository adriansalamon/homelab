terraform {
  backend "consul" {
    address = "consul.local.salamon.xyz"
    scheme  = "https"
    path    = "terraform/infra"
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.19.0-beta.5"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.0"
    }
    consul = {
      source  = "hashicorp/consul"
      version = "~> 2.0"
    }
    nomad = {
      source  = "hashicorp/nomad"
      version = "~> 2.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "eu-north-1"
}

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_key = var.cloudflare_api_token
  email   = var.cloudflare_email
}

### AWS SMTP user (maybe broken?)

resource "aws_iam_user" "smtp_user" {
  name = "smtp_user"
}

resource "aws_iam_access_key" "smtp_user" {
  user = aws_iam_user.smtp_user.name
}

data "aws_iam_policy_document" "ses_sender" {
  statement {
    actions   = ["ses:SendRawEmail"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ses_sender" {
  name        = "ses_sender"
  description = "Allows sending of e-mails via Simple Email Service"
  policy      = data.aws_iam_policy_document.ses_sender.json
}

resource "aws_iam_user_policy_attachment" "ses_attachment" {
  user       = aws_iam_user.smtp_user.name
  policy_arn = aws_iam_policy.ses_sender.arn
}

### Cloudflare DNS challenge token

data "cloudflare_accounts" "main" {}

data "cloudflare_account_api_token_permission_groups_list" "all" {
  account_id = data.cloudflare_accounts.main.result[0].id
}

locals {
  dns_permissions = {
    for x in data.cloudflare_account_api_token_permission_groups_list.all.result :
    x.name => x.id
    if contains(["DNS Write"], x.name)
  }
}

resource "cloudflare_api_token" "acme_dns_challenge" {
  name = "acme token"
  provisioner "local-exec" {
    command     = <<BASH
      filename="hosts/nixos/athena/secrets/cloudflare-dns-api-token.env"
      rm "$filename.age"
      echo "CF_DNS_API_TOKEN=${self.value}" > $filename
      agenix edit -i "$filename" "$filename.age"
      rm $filename
    BASH
    working_dir = "."
  }
  policies = [{
    resources = jsonencode({
      "com.cloudflare.api.account.zone.*" = "*"
    })
    effect = "allow"
    permission_groups = [{
      id = local.dns_permissions["DNS Write"]
    }]
  }]
}


### Hetzner VPS

resource "hcloud_network" "main" {
  name     = "main"
  ip_range = "10.88.0.0/16"
}

resource "hcloud_network_subnet" "main_subnet" {
  type         = "cloud"
  network_id   = hcloud_network.main.id
  network_zone = "eu-central"
  ip_range     = "10.88.0.0/24"
}

resource "hcloud_ssh_key" "main" {
  name       = "main-ssh-key"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICOfx4SWN/ygsiUkWWWRCFcTz/SBBRO0qKirHiYuvr3x asalamon@kth.se\n"
}

resource "hcloud_ssh_key" "yubikey" {
  name       = "yubikey piv"
  public_key = "ecdsa-sha2-nistp384 AAAAE2VjZHNhLXNoYTItbmlzdHAzODQAAAAIbmlzdHAzODQAAABhBDmOgdi09i0CnGRAaXDzkOCJ+XAVDvF3jFKgWMl5yfrxeqczLqk0wB9xqVr4I4TQEYJNkM6TiYzh/e9alknR9apD49m68cB3Jl4CuR4Nygcrl51pw8lSzE9JmtIBhsG1tA=="
}

resource "hcloud_server" "icarus" {
  name        = "icarus"
  server_type = "cx23"
  image       = "debian-12"
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  network {
    network_id = hcloud_network.main.id
    ip         = "10.88.0.2"
  }
  ssh_keys = [hcloud_ssh_key.main.id]

  lifecycle {
    ignore_changes = [ssh_keys]
  }

  depends_on = [hcloud_network_subnet.main_subnet]
}


resource "hcloud_server" "daedalus" {
  name        = "daedalus"
  server_type = "cx23"
  image       = "debian-12"
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }
  network {
    network_id = hcloud_network.main.id
    ip         = "10.88.0.3"
  }
  ssh_keys = [hcloud_ssh_key.yubikey.id]

  lifecycle {
    ignore_changes = [ssh_keys]
  }

  depends_on = [hcloud_network_subnet.main_subnet]
}


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
