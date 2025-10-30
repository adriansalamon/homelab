{ profiles, ... }:
{

  microvm.mem = 1024 * 10;
  microvm.vcpu = 5;

  imports = [
    profiles.services.nomad.client
  ];

  # Don't use nftables, because of docker and cni plugins
  meta.usenftables = false;
}
