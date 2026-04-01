# Vault TLS Certificates

This directory contains the CA for Vault TLS certificates. Server certificates are automatically generated per-host using the `age.secrets.generator` in the vault-server profile.

## Required Files

- `vault-ca.pem` - CA certificate (plaintext, checked into git)
- `vault-ca-key.pem.age` - CA private key (age-encrypted, checked into git)

Server certificates (`vault-server.pem` and `vault-server-key.pem.age`) are automatically generated per-host during agenix-rekey.

## Generating the CA (One-Time Setup)

Only the CA needs to be generated manually. Run this once:

```bash
cd secrets/vault

# Generate CA private key
openssl genrsa -out vault-ca-key.pem 4096

# Generate CA certificate (valid for 10 years)
openssl req -new -x509 -days 3650 \
  -key vault-ca-key.pem \
  -out vault-ca.pem \
  -subj "/CN=Vault CA"

# Encrypt the CA private key with age
agenix -e vault-ca-key.pem.age
# Paste the contents of vault-ca-key.pem and save

# Remove unencrypted CA key
rm vault-ca-key.pem

# Commit both files to git
git add vault-ca.pem vault-ca-key.pem.age
```

## How Server Certificates are Generated

Each vault server automatically generates its own certificate during `agenix rekey`:

1. The generator in `profiles/services/vault-server.nix` runs
2. It generates a unique private key and CSR for the host
3. It signs the CSR with the CA key (decrypted on-the-fly)
4. The certificate includes SANs:
   - DNS: `localhost`, `vault.service.consul`, `active.vault.service.consul`, `vault-{hostname}`
   - IP: `127.0.0.1` and the host's Nebula IP

Generated files (per host):

- `secrets/generated/{hostname}/vault-server-key.pem.age` - Server private key (encrypted)
- `secrets/generated/{hostname}/vault-server.pem` - Server certificate (plaintext)

## Triggering Certificate Generation

After creating the CA, run:

```bash
agenix rekey -a
```

This will generate certificates for all three vault servers (athena, charon, pythia).

## Certificate Rotation

When certificates expire:

1. Just run `agenix rekey -a` to regenerate all server certificates
2. Or regenerate the CA and server certificates by following the generation steps again
3. Deploy the new certificates with `deploy`

The generator ensures each server always gets a fresh certificate with the correct SANs.
