## Homelab

This is a place for all infra stuff at home. There are currently three sites + a
cloud environment.

- Olympus (G29)
- Erebus (B22)
- Pythia (B216)
- Aether (Hetzner)

With the main infra at Olympus.

### Infra

This repo uses OpenTofu and NixOS to manage the infrastructure. Most of the
configuration is done using Nix.

#### Hosts

|     | type   | name      | hardware                                         | use                                                                                    |
| --- | ------ | --------- | ------------------------------------------------ | -------------------------------------------------------------------------------------- |
| 💻  | laptop | atlas     | M1 Macbook Air                                   | Personal machine, has served me well.                                                  |
| 🖥️  | server | athena    | Dell R210 II<br>E3-1230v2, 8gb RAM               | Firewall/router. DHCP and DNS server. Internal reverse proxy and VPN gateway.          |
| 🖥️  | server | orpheus   | Supermicro 1U X9SCM<br>E3-1230, 16gb RAM         | Backup NAS/storage server. Runs not much currently.                                    |
| 🖥️  | server | zeus      | Supermicro X10DRU-i+<br>2xE5-2620v4, 64gb RAM    | Main VM and services host. Runs most of my services.                                   |
| 🖥️  | server | hermes    | Supermicro 2U X11SSH-LN4F<br>E3-1240v6, 32gb RAM | Storage server/NAS. Has a 16TB ZFS storage pool.                                       |
| 🖥️  | server | orpheus   | ASUS PN51<br>Ryzen 5 5500U, 16gb RAM             | Edge server at Erebus. Runs some services and VMs and acts as a local NAS at the site. |
| 🖥️  | server | proxmox01 | Dell R610<br>2x5690, 96gb RAM                    | Decommissioned. Very good at heating a home.                                           |
| ☁️  | VPS    | icarus    | Hetzner Cloud server                             | Proxy for local services. Nebula lighthouse, Headscale server.                         |

#### Services

|                       | service                | description                                                                                                        |
| --------------------- | ---------------------- | ------------------------------------------------------------------------------------------------------------------ |
| 🪪 SSO                | Authelia               | Single-Sign-On for hosted services. Uses lldap as an LDAP backend.                                                 |
| 📷 Photos             | Immich                 | Self hosted Google Images alternative. My phone backs up here via the Immich app.                                  |
| 📄 Documents          | Paperless              | Manager for physical and digital documents. Automatically ingests scans from my HP printer/scanner via Samba.      |
| 🌐 VPN                | Headscale              | Use as classic VPN for remote access with SSO login. Used to remotely access internal services.                    |
| 🏠 Home Automation    | Home Assistant         | Manages things (mostly IoT devices) in my home.                                                                    |
| 🍿 Media Server       | Jellyfin               | Used to view movies and TV series.                                                                                 |
| 🎞️ Media Management   | Radarr/Sonarr/Prowlarr | Used to automatically keep media in sync.                                                                          |
| 🗃️ Download client    | Deluge                 | Download client to download and cache files.                                                                       |
| 🛡️ Reverse Proxy      | Traefik                | Reverse proxy to secure access to services, uses Consul for dynamic service discovery.                             |
| 🗂️ Network Management | UniFi Controller       | Central network controller for all UniFi devices across all sites.                                                 |
| 📔 Notes              | Obsidian Livesync      | Synchronizes all my Obsidian clients, where I keep most of my digital notes.                                       |
| 🔊 Music              | Snapserver             | Acts as a streaming device from Spotify or AirPlay, and syncs multiroom audio. I run Raspberry Pis as snapclients. |
| 📂 File Server        | Samba                  | NAS file storage for clients on local network.                                                                     |

#### System

|                      | system     | description                                                                                                                                                                    |
| -------------------- | ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 📁 Service Discovery | Consul     | Consul cluster to manage service registrations. I also put DHCP leases as consul services and use the built-in distributed Consul DNS.                                         |
| 🌐 Networking        | Nebula     | Overlay encrypted mesh network. All services are connected and communicate over Nebula, and use groups and use strict Nebula firewall rules.                                   |
| 🔐 Secrets           | Age        | All secrets are stored in this repo, but encrypted using Age. Two YubiKeys (one offline backup) used for decryption. `agenix-rekey` enables me to encrypt per-service secrets. |
| 📃 Logs              | Loki       | Journald logs are sent to Loki, using vector. They can be queried using Grafana.                                                                                               |
| ⏱️ Metrics           | Prometheus | Metrics are collected using Prometheus and visualized using Grafana.                                                                                                           |
| ⛈️ Backups           | Restic     | Automatic backups off all my data to Hetzner Storage Boxes via restic.                                                                                                         |

TODO/add:

- Git server (Forgejo/Gitea)
- A simple cluster to learn about orchestration (k8s, k3s or nomad)
- Ad blocking DNS
- Dashboard (glance/homepage)

### Secrets 🔐

All secrets, e.g. passwords, API tokens, etc. are stored as age encrypted files.
These are encrypted using two YubiKeys (one offline backup). Using
[`agenix-rekey`](https://github.com/oddlama/agenix-rekey), secrets are
rekeyed/encrypted per host/server. Please see the documentation for the library
for more information.

Semi-secret data, like domain names, email addresses, and IP addresses, which
are not secrets in the traditional sense (I'm fine if they are in the Nix store)
but I would still like to keep hidden publicly on GitHub, are encrypted using
[`git-agecrypt`](https://github.com/vlaci/git-agecrypt). To set up after cloning
repo, use:

```bash
git-agecrypt init
git-agecrypt config -i secrets/yubikey-identity.pub
```

### Provisioning hosts

TODO: figure out how to make this work with `git-agecrypt`.

Boot into a NixOS live ISO, or try your luck with `nixos-anywhere`. Using
`nixos-anywhere`:

```
nix run github:nix-community/nixos-anywhere -- --flake #name <user>@<host> --build-on-remote
```

If you want to do it manually (e.g. there might be some data already there, and
you want to be careful). Read on. You can build a NixOS live ISO with
preconfigured ssh keys:

```bash
nix build --print-out-paths --no-link github:adriansalamon/homelab#live-iso
```

Then on the host run:

```bash
export host=<name>
nix-shell -p disko
sudo disko -m disko --flake github:adriansalamon/homelab#$host
sudo nixos-install --root /mnt --no-root-password --flake github:adriansalamon/homelab#$host
# Important! If the system has a zfs pool, otherwise it will fail to import on boot
sudo umount -l /mnt && sudo zpool export -a
```

### OpenTofu

Some things are managed using OpenTofu, e.g. Cloudflare DNS, Hetzner Cloud, and Consul.
To run, use:

```bash
nix run #tofu <command, e.g. plan|apply>
```

This also automatically sets up a tunnel to a Consul server.

## Credits

This configuration is heavily inspired by
[oddlama's](https://github.com/oddlama/nix-config) awesome configuration, with
many parts taken directly (and some modified and simplified). Huge thanks to
them!

Other sources of inspiration:

- [notthebee](https://github.com/notthebee/nix-config/) - His YouTube video
  pushed me to finally move to a NixOS based setup. -
  [PopeRigby](https://codeberg.org/PopeRigby/config) - Authelia setup is based
  on his config.
