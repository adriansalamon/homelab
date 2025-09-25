### Auth

We use [Authelia](https://www.authelia.com/) for authentication.

It is connected to [lldap](https://github.com/lldap/lldap), a lightweight LDAP server.
It is there where password hashes, and user information are stored.

Authelia can be used as a traefik middleware to authenticate users to unsecured services,
just add `traefik.http.routers.<name>.middlewares=authelia` to the router.

Authelia also works as an OIDC provider, so it can be used for SSO with other services.

#### Adding a new OIDC client

1. Add a new line in `authelia.nix` like `(mkOidcSecrets <name>)`, where `<name>` is the name of the OIDC client.
2. Run `agenix generate` to automatically generate the new secrets. You can view the secret values with
`agenix edit`.
3. Run `agenix rekey` to rekey values. Add the rekeyed values to git.
4. Add your client configuration to `oidc_clients.yaml.j2`.
5. Run `deploy --remote-build -s .#nixos` to deploy the new configuration.
6. Profit???
