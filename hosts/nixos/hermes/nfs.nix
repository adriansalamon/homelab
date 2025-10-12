{ config, globals, ... }:
let
  host = config.node.name;

  getUid = userName: toString config.users.users.${userName}.uid;
  getGid = groupName: toString config.users.groups.${groupName}.gid;
in
{

  # NFS exports
  services.nfs.server = {
    enable = true;
    hostName = globals.nebula.mesh.hosts.${host}.ipv4;

    exports = ''
      # media server
      /data/tank02/media ${globals.nebula.mesh.cidrv4}(rw,sync,no_subtree_check,no_root_squash,anonuid=${getUid "media"},anongid=${getGid "media"})

      # paperless scanning
      /data/tank02/shared/scanning ${globals.nebula.mesh.cidrv4}(rw,sync,no_subtree_check,no_root_squash,anonuid=${getUid "paperless"},anongid=${getGid "scanning"})

      # adrian images
      /data/tank02/homes/adrian/Bilder ${globals.nebula.mesh.hosts.zeus.ipv4}(ro,sync,no_subtree_check,no_root_squash,anonuid=${getUid "immich"},anongid=${getGid "adrian-photos"})
      /data/tank03/adrian/Images ${globals.nebula.mesh.hosts.zeus.ipv4}(ro,sync,no_subtree_check,no_root_squash,anonuid=${getUid "immich"},anongid=${getGid "adrian-photos"})
    '';
  };

  globals.nebula.mesh.hosts.${host}.firewall.inbound = [
    {
      port = "2049";
      proto = "tcp";
      group = "nfs-client";
    }
  ];
}
