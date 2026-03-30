FROM ghcr.io/runatlantis/atlantis:v0.41.0


USER root

# Install dependencies
RUN apk add --no-cache curl xz git openssh-client ca-certificates coreutils

# Create /nix directory and configure Nix
RUN mkdir -m 0755 /nix && chown root /nix && \
    mkdir -p /etc/nix && \
    echo "build-users-group =" > /etc/nix/nix.conf && \
    echo "sandbox = false" >> /etc/nix/nix.conf && \
    echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

# Install Nix in single-user mode
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon --no-channel-add

# Setup environment for Nix
ENV USER=atlantis
ENV HOME=/home/atlantis
ENV NIX_PROFILES="/nix/var/nix/profiles/default"
ENV PATH="/nix/var/nix/profiles/default/bin:${PATH}"

RUN nix --version

# The atlantis user needs to be able to write to the Nix store
RUN chown -R atlantis:atlantis /nix

# Switch back to atlantis user
USER atlantis

# Entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]
CMD ["server"]
