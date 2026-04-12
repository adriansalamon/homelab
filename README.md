## Homelab

Infrastructure as code for a multi-site homelab setup. All servers run NixOS
with configurations managed in this repo. Also contains configuration for
workloads running as Nomad jobs, and other infra configuration.

### Hosts

|     | type   | name     | hardware                                         | use                                                                           |
| --- | ------ | -------- | ------------------------------------------------ | ----------------------------------------------------------------------------- |
| 💻  | laptop | atlas    | M1 Macbook Air                                   | Personal machine, has served me well.                                         |
| 🖥️  | server | athena   | Dell R210 II<br>E3-1230v2, 8gb RAM               | Firewall/router. DHCP and DNS server. Internal reverse proxy and VPN gateway. |
| 🖥️  | server | demeter  | Supermicro 1U X9SCM<br>E3-1230, 16gb RAM         | Backup NAS/storage server. Nomad client.                                      |
| 🖥️  | server | zeus     | Supermicro X10DRU-i+<br>2xE5-2620v4, 64gb RAM    | Main VM and services host. Runs most of my services.                          |
| 🖥️  | server | hermes   | Supermicro 2U X11SSH-LN4F<br>E3-1240v6, 32gb RAM | Storage server/NAS. Has a 16TB ZFS storage pool.                              |
| 🖥️  | server | orpheus  | ASUS PN51<br>Ryzen 5 5500U, 16gb RAM             | Edge server at Erebus. Local NAS, Nomad client.                               |
| 🖥️  | server | charon   | Intel N150<br>12gb RAM                           | Firewall/router at Erebus.                                                    |
| 🖥️  | server | pythia   | Intel N150<br>12gb RAM                           | Firewall/router at Delphi.                                                    |
| 🖥️  | server | penelope | Intel N150<br>12gb RAM                           | Firewall/router at Ithaca.                                                    |
| 🖥️  | server | pan      | UBNT Edgerouter Lite                             | Firewall/router at Arcadia. Runs OpenWrt.                                     |
| 🖥️  | server | callisto | Raspberry Pi 3                                   | At Arcadia. Runs zigbee2mqtt.                                                 |
| ☁️  | VPS    | icarus   | Hetzner Cloud server                             | Proxy for local services. Nebula lighthouse, Headscale server.                |

### Infrastructure

#### Nomad

Container orchestration with Nomad. Jobs can be defined as either:

- **HCL files** in `nomad/jobs/*.nomad.hcl` (legacy)
- **Nix expressions** using
  [nix-nomad](https://github.com/tristanpemble/nix-nomad) to generate JSON
  jobspecs

Jobs deployed across multiple Nomad clients for high availability. Services use
Consul for service discovery and custom [Nebula CNI
plugin](https://github.com/adriansalamon/nebula-nomad-cni) for networking with
strict firewall rules per service.

Job deployment managed via Terranix+OpenTofu (see below).

#### Networking

**Nebula**: Encrypted mesh overlay network connecting all sites. Every service
communicates over Nebula with firewall rules defined per task using groups
(e.g., `postgres-client`, `redis-client`). Also used for traditional
site-to-site subnet routing for client devices. Lighthouse runs on Hetzner VPS.

**Traefik**: Ingress/reverse proxy. Runs on all sites + on VPS for access to
services.

**Consul**: Service discovery and distributed DNS. DHCP leases registered as
Consul services. Traefik uses Consul catalog for dynamic routing.

**CoreDNS**: Primary DNS server, forwards to Consul DNS and includes
ad-blocking. Does split DNS to local Traefik instance for internal resources.

**Headscale**: Tailscale-compatible VPN for remote access to internal services.
OIDC authentication via Authelia.

#### Secrets Management

**Age**: Secrets encrypted using Age with YubiKey identities (one offline
backup). [`agenix-rekey`](https://github.com/oddlama/agenix-rekey) handles
per-host secret encryption. Also used to generate sops encrypted files for
provisioning into Vault.

Useful commands:

```bash
# generate secrets
agenix generate -a
# rekey secrets for hosts
agenix rekey -a
# rekey secrets for provisioning into Vault
nix run \#sops-rekey
```

**Vault**: Runtime secrets for Nomad jobs. Auto-unseal using AWS KMS. Nomad jobs
use Vault integration to fetch secrets at runtime. Secrets are provisioned into
Vault via sops terraform provider.

**sops**: Semi-sensitive data (domain names, IPs) encrypted in git but
available in Nix store. Not traditional secrets but kept out of public repo.
Uses git filter for transparent encryption/decryption:

```gitconfig
[filter "sops"]
  smudge = sops --decrypt --input-type binary /dev/stdin
  clean = sops --encrypt --input-type binary --output-type binary /dev/stdin
  required = true
```

#### Observability

**Prometheus**: Metrics collection from all hosts and services.

**Loki**: Centralized logging. Journald logs forwarded via Vector.

**Grafana**: Dashboards for metrics and logs. OIDC auth via Authelia.

#### Storage & Backups

**SeaweedFS**: Distributed S3-compatible object storage replicated across sites.
Used for Nomad CSI volumes.

**Restic**: Automated backups to Hetzner Storage Box.

**ZFS**: Local storage pools on NAS hosts.

#### Terraform/Terranix

Two separate Terraform configurations:

**External infrastructure** (`terraform/infra/`): Traditional HCL for cloud
resources

- Cloudflare DNS records
- Hetzner VPS
- AWS resources (SES SMTP, KMS for Vault auto-unseal)

```bash
tofu -chdir=terraform/infra <init|plan|apply>
```

**Internal cluster** (`terraform/jobs/`): [Terranix](https://terranix.org/)
(Nix-based) for cluster provisioning

- Nomad configuration
- Nomad job deployments (automatically collects from `nomad/jobs/*`)
- Consul configuration
- Vault configuration
- Vault secrets

```bash
nix run #terraform-jobs.<init|plan|apply>
```

### CI/CD

Automated builds and deployments via GitHub Actions:

**NixOS system builds** (`.github/workflows/build-derivations.yaml`):

- Builds all NixOS system derivations on GitHub-hosted runners
- Pushes to Attic binary cache
- Updates deployment pointer in Consul KV store (via consul-kv-proxy)
- Hosts poll Consul KV and pull new system closures when available

**Cluster configuration** (`.github/workflows/terraform-apply.yaml`):

- Runs on self-hosted runner with access to internal cluster
- Applies Terranix-generated Terraform for Nomad/Consul/Vault
- Automatically deploys all Nomad jobs

### Provisioning

New hosts provisioned using
[nixos-anywhere](https://github.com/nix-community/nixos-anywhere) with
[disko](https://github.com/nix-community/disko) for declarative disk
partitioning.

Build custom live ISO with SSH keys:

```bash
nix build --print-out-paths --no-link github:adriansalamon/homelab#live-iso
```

Deploy to new host:

```bash
nix run github:nix-community/nixos-anywhere -- --flake .#hostname <user>@<host> --build-on-remote
```

After install, add host SSH key to `<host>/secrets/host.pub` and rekey secrets.

## Credits

This configuration is heavily inspired by
[oddlama's](https://github.com/oddlama/nix-config) awesome configuration, with
many parts taken directly (and some modified and simplified). Huge thanks to
them!

Other sources of inspiration:

- [notthebee](https://github.com/notthebee/nix-config/) - His YouTube video
  pushed me to finally move to a NixOS based setup.
- [PopeRigby](https://codeberg.org/PopeRigby/config) - Authelia setup is based
  on his config.
- [Diogo Correia](https://github.com/diogotcorreia/dotfiles) - My automatic
  build and deployment setup is heavily inspired by his.
