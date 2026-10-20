{ den, ... }:
{
  den.hosts.x86_64-linux.bitstream = {
    channel = "nixos-unstable";
    environment = "dev";
    system-owner = "sini";
    system-access-groups = [ "server-access" ];

    networking = {
      bonds.bond0 = {
        interfaces = [
          "eno1"
          "enp2s0"
        ];
        mode = "balance-xor";
        transmitHashPolicy = "layer3+4";
      };
      interfaces.bond0 = {
        ipv4 = [ "10.9.1.1/16" ];
        ipv6 = [ "2001:5a8:608c:4a00::1/64" ];
      };
    };

    settings = {
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-NVMe_CA6-8D1024_0023065001TG";
      core.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = false;
      };

      applications.dev.mux.herdr-pair.session = "default";
      applications.dev.mux.herdr-pair.pairs.sini = [ "vic" ];

      # sini's and vic's xmsg nodes here. Their links (to each other and to sini@cortex)
      # and the genie-guard pod's leaf are derived (policies/xmsg.nix).
      applications.dev.ai.mcp.xmsg.federation.nodes = {
        sini = { };
        vic.port = 7789;
      };

      # @genie support bot: #support:json64.dev (testing), #denful:matrix.org and a private room.
      services.matrix-xmsg = {
        rooms = [
          "!dj6ESTc_Wy5FaLnR-Sj1o_WOqnDeUZWoloV8HuijXs8"
          "!mafjNSATIwbTXcmNzX:matrix.org"
          "!qqfdClEfuMzZNEjvGO:matrix.org" # private room (invite)
          "!NbOtAeWMLV6MjYH3QtXolO8MuGXp6dBfnB0uO8nSpJI" # #genie-dev: tier 1's vetting room (invite)
        ];
        # #genie-dev goes to genie-agent's Tier 1, whose guard-in screens every request;
        # the other rooms stay on genie-support, screened by the bot.
        roomRoutes."!NbOtAeWMLV6MjYH3QtXolO8MuGXp6dBfnB0uO8nSpJI" = {
          expertRef = "genie";
          screenMentions = false;
        };
        extraTrustedMxids = [
          "@theutz:matrix.org"
          "@drupol:matrix.org"
          "@vborja:matrix.org"
          "@sini:matrix.org"
          "@fmway:gitter.im"
        ];
      };
    };
  };

  den.aspects.bitstream = {
    includes = with den.aspects; [
      roles.default
      roles.server
      roles.dev
      roles.nix-builder

      disk.zfs-disk-single
      core.boot.network-initrd
      hardware.cpu.amd
      hardware.gpu.amd

      applications.dev.mux.herdr-pair
      services.matrix-xmsg
      services.ai.genie-expert
      services.ai.genie-xmsg
      services.ai.genie-tier1
    ];

    # TODO: remove once the Samsung has booted as zroot (nix-config#183).
    # The replacement disk carries pool znew, which can only be renamed on import,
    # and zroot is held while the CA6 runs. With no zroot present, import that pool
    # (by GUID) as zroot; the stock script then sees it imported and runs the clevis
    # unlock as usual. mkAfter keeps this behind network-initrd's `load-key -a`,
    # which fails on a prompt-keyed pool imported before it. Any zroot on disk,
    # including this one after the rename, disarms it.
    nixos =
      { config, lib, ... }:
      let
        guid = "15927363162138547936";
        zpool = "${config.boot.zfs.package}/sbin/zpool";
      in
      {
        boot.initrd.systemd.services.zfs-import-zroot.preStart = lib.mkAfter ''
          if ! ${zpool} list zroot >/dev/null 2>&1; then
            found=
            for _ in $(seq 1 30); do
              found="$(${zpool} import -d /dev/disk/by-id/ 2>/dev/null)" || true
              case "$found" in *"pool: zroot"* | *"id: ${guid}"*) break ;; esac
              sleep 1
            done
            case "$found" in
              *"pool: zroot"*) ;;
              *"id: ${guid}"*) ${zpool} import -d /dev/disk/by-id/ -N $ZFS_FORCE ${guid} zroot || true ;;
            esac
          fi
        '';
      };

    sini.includes = with den.aspects; [ services.ai.genie-bank-review ];
    vic.includes = with den.aspects; [ roles.dev ];
  };
}
