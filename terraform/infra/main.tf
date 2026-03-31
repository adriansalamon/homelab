terraform {
  backend "consul" {
    address = "consul.local.salamon.xyz"
    scheme  = "https"
    path    = "terraform/infra"
  }

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "5.19.0-beta.3"
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
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "hcloud_server" "icarus" {
  name        = "icarus"
  server_type = "cx22"
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
