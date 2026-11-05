# uplink-dev: a dev microvm on uplink for den-ag-design sessions, which outgrew
# bitstream (32 GB, 12 threads). Delivered as a child of uplink (uplink.nix
# `guests`), modelled on cortex-cuda without the GPU.
#
# Storage:
#   /nix/store       uplink's store, read-only over virtiofs
#   /nix/.rw-store   the writable overlay on it, a scratch disk recreated empty at
#                    every start; with the nix db also fresh each boot (only the
#                    current closure, which uplink roots, is registered), uplink's
#                    GC can never delete a path this guest believes valid
#   /tmp             agents' scratchpads and local build dirs, a scratch disk too
#   /persist, /cache uplink's /{persist,cache}/microvms/uplink-dev over virtiofs
#
# TODO: memory to 96 GB once services move off uplink onto the cluster.
# TODO: nothing snapshots or backs up uplink's /persist (or any zfs-disk-single
#       host's): the property is set but no snapshot service runs. Beads databases
#       and unpushed worktrees here live only on that dataset.
{ den, lib, ... }:
let
  # Its own SSH host key (also its agenix identity): uplink decrypts it into
  # hostKeyShare, mounted read-only here at hostKeyDir; never uplink's identity.
  hostKeyShare = "/var/lib/microvms/uplink-dev/host-key";
  hostKeyDir = "/etc/ssh/host-key";
  mac = "02:00:00:01:02:01";
in
{
  den.hosts.x86_64-linux.uplink-dev = {
    channel = "nixos-unstable";
    environment = "dev";
    system-owner = "sini";
    system-access-groups = [ "server-access" ];
    intoAttr = [ ]; # delivered as a child of uplink, not a standalone nixosConfiguration

    # A raw guest entity: the host-submodule defaults for these never compute.
    secretPath = ./. + "/../../../.secrets/hosts/uplink-dev";
    public_key = ./. + "/../../../.secrets/hosts/uplink-dev/ssh_host_ed25519_key.pub";
    facts = ./. + "/../../../hosts/uplink/facter.json";

    # The guests policy forwards home-manager only for the raw entity's own
    # `users` (fleet access groups never resolve onto a raw guest).
    users.sini = { };

    # On the prod LAN beside the other static servers, through uplink's br0.
    networking.interfaces.vm-dev.ipv4 = [ "10.10.11.1/16" ];

    microvm.scratchVolumes = {
      "/nix/.rw-store" = 262144; # 256 GiB ceiling, sparse
      "/tmp" = 131072; # 128 GiB ceiling, sparse
    };
  };

  den.aspects.uplink-dev = {
    includes = with den.aspects; [
      roles.default
      roles.dev
      services.monitoring.prometheus-exporter
      services.alloy
      den.policies.microvm-guest-unpersist-pinned
    ];

    nixos =
      { config, ... }:
      {
        networking.hostName = "uplink-dev";
        # The guest gets an already-instantiated pkgs; its config is set there.
        nixpkgs.config = lib.mkForce { };

        microvm = {
          guest.enable = true;
          optimize.enable = true;
          vcpu = 16;
          mem = 65536;
          interfaces = [
            {
              id = "vm-dev";
              type = "tap";
              inherit mac;
            }
          ];
          shares = [
            {
              source = hostKeyShare;
              mountPoint = hostKeyDir;
              tag = "host-key";
              proto = "virtiofs";
            }
          ];
        };

        # The nix db is the tmpfs root's, so each boot registers only the current
        # closure; persisting /nix/var would let it outlive uplink's GC.
        assertions = [
          {
            assertion =
              !(lib.any (p: lib.any (d: lib.hasPrefix "/nix" (d.directory or d)) p.directories) (
                lib.attrValues (config.environment.persistence or { })
              ));
            message = "uplink-dev: /nix must not be persisted (see the host file)";
          }
        ];

        # No virtual console in the VM: vconsole setup can only fail.
        console.enable = false;

        environment.etc."machine-id" = {
          mode = "0644";
          text = (builtins.hashString "md5" "uplink-dev") + "\n";
        };

        networking.firewall.allowedTCPPorts = [ 22 ];

        systemd.network = {
          enable = true;
          networks."20-lan" = {
            matchConfig.MACAddress = mac;
            networkConfig = {
              Address = [ "10.10.11.1/16" ];
              Gateway = "10.10.0.1";
              DNS = [
                "1.1.1.1"
                "8.8.8.8"
              ];
              IPv6AcceptRA = true;
              DHCP = "no";
            };
          };
        };

        # core.users.shell enables zsh in the `os` class, but the guest delivery
        # route collects only `nixos`, so the users' zsh login shell needs it here.
        programs.zsh.enable = true;

        # The key share must be mounted before agenix runs in activation.
        fileSystems.${hostKeyDir}.neededForBoot = true;
        age.identityPaths = lib.mkForce [ "${hostKeyDir}/ssh_host_ed25519_key" ];

        services.openssh.hostKeys = lib.mkForce [
          {
            path = "${hostKeyDir}/ssh_host_ed25519_key";
            type = "ed25519";
          }
        ];
      };
  };
}
