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

    # NFS server state. Two reasons, either sufficient on its own:
    #
    # 1. Lock recovery. sm/sm.bak/state are the NSM peer records rpc.statd uses
    #    to reclaim locks after a reboot; wiped, clients holding locks are never
    #    notified and recovery is silent.
    #
    # 2. A boot race that took the media stack down on 2026-08-31. This host
    #    wipes / on boot, so /var/lib/nfs starts EMPTY — and rpc.mountd logged
    #    "couldn't open /var/lib/nfs/etab" and exited 0 (so systemd recorded the
    #    unit as started, and nothing restarted it). nfsd stayed up, so 2049 kept
    #    accepting connections and the host looked healthy to a port check, while
    #    every MOUNT RPC was refused. Result: every pod mounting media-scratch-nfs
    #    hung in ContainerCreating with no events, indefinitely. On a host that
    #    keeps /var/lib/nfs, a stale etab from the previous boot is present and
    #    mountd opens it regardless of when exportfs runs.
    persist.directories = [ "/var/lib/nfs" ];

    nixos = {
      # uid/gid sourced from users.deterministicIds registry (media = 1027:65536).
      users.users.media = {
        group = "media";
        isSystemUser = true;
      };
      users.groups.media = { };

      # NOT tmpfiles: systemd-tmpfiles refuses to operate beneath the
      # media-owned root ("unsafe path transition" canonicalization check,
      # not disable-able per rule). A oneshot creates the download tree with
      # correct ownership, ordered before the NFS server exports it.
      systemd.services.media-scratch-dirs = {
        description = "Create media scratch download tree";
        wantedBy = [ "multi-user.target" ];
        after = [ "local-fs.target" ];
        before = [ "nfs-server.service" ];
        requiredBy = [ "nfs-server.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          set -eu
          # Dirs only — pod-written files are already 1027:65536 (all_squash /
          # PUID); a recursive chown would walk the whole download tree at boot.
          for d in usenet usenet/incomplete usenet/complete torrents torrents/incomplete torrents/complete; do
            mkdir -p "${exportPath}/$d"
            chown media:media "${exportPath}/$d"
            chmod 0775 "${exportPath}/$d"
          done
        '';
      };

      services.nfs.server = {
        enable = true;
        # Client ranges: pod CIDR, management network, and the thunderbolt
        # fabric loopbacks (172.16.255.0/24) — peer kubelets mount over the
        # fabric and source from their loopback, as does pod traffic SNAT'd by
        # the fabric-source-snat invariant (thunderbolt-mesh-of.nix).
        exports =
          let
            opts = "(rw,no_subtree_check,all_squash,anonuid=1027,anongid=65536)";
          in
          ''
            ${exportPath} 172.20.0.0/16${opts} 10.10.10.0/24${opts} 172.16.255.0/24${opts}
          '';
      };

      networking.firewall.allowedTCPPorts = [ 2049 ];
    };
  };
}
