# NVMe download scratch — lives on the impermanence cache dataset
# (zroot/local/cache: survives reboot, excluded from persist/backup).
# Exported over NFS to the k8s pod network; downloaders mount it via
# local PV on this node, arr pods via NFS. Endpoint published via the
# media-scratch-exports quirk.
let
  exportPath = "/cache/media-scratch";
in
{
  den.aspects.services.storage.media-scratch = {
    media-scratch-exports =
      { host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit exportPath;
      };

    cache.directories = [
      {
        directory = exportPath;
        user = "media";
        group = "media";
        mode = "0775";
      }
    ];

    nixos = {
      # uid/gid sourced from users.deterministicIds registry (media = 1027:65536).
      users.users.media = {
        group = "media";
        isSystemUser = true;
      };
      users.groups.media = { };

      systemd.tmpfiles.rules = [
        "d ${exportPath}/usenet/incomplete 0775 media media -"
        "d ${exportPath}/usenet/complete 0775 media media -"
        "d ${exportPath}/torrents/incomplete 0775 media media -"
        "d ${exportPath}/torrents/complete 0775 media media -"
      ];

      services.nfs.server = {
        enable = true;
        exports = ''
          ${exportPath} 172.20.0.0/16(rw,no_subtree_check,all_squash,anonuid=1027,anongid=65536) 10.10.10.0/24(rw,no_subtree_check,all_squash,anonuid=1027,anongid=65536)
        '';
      };

      networking.firewall.allowedTCPPorts = [ 2049 ];
    };
  };
}
