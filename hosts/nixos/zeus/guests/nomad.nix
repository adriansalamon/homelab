{ profiles, ... }:
{

  microvm.mem = 1024 * 32;
  microvm.vcpu = 18;

  imports = [
    profiles.services.nomad.client
  ];

  # Don't use nftables, because of docker and cni plugins
  meta.usenftables = false;
}
