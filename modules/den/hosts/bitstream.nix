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

      # sini's and vic's nodes here, each linked to the other and to sini@cortex,
      # authenticated by the xmsg CA (federation plan §6.7). vic has full rights on
      # sini's nodes, matching herdr-pair, which already shares sini's sessions.
      applications.dev.ai.mcp.xmsg.federation.nodes = {
        sini = {
          peers."sini.cortex" = { };
          peers."vic.bitstream" = { };
          # genie-guard's pod on axon (kubernetes/services/ai/genie-guard.nix) collects
          # the guard's requests here and answers them; nothing else reaches it.
          leaves = [
            {
              identity = "spiffe://json64.dev/ns/genie/sa/genie-guard";
              cluster = "axon";
              targets = [ "genie-guard" ];
            }
          ];
        };
        vic = {
          port = 7789;
          peers."sini.bitstream" = { };
          peers."sini.cortex" = { };
        };
      };

      # @genie support bot: #support:json64.dev (testing), #denful:matrix.org and a private room.
      services.matrix-xmsg = {
        rooms = [
          "!dj6ESTc_Wy5FaLnR-Sj1o_WOqnDeUZWoloV8HuijXs8"
          "!mafjNSATIwbTXcmNzX:matrix.org"
          "!qqfdClEfuMzZNEjvGO:matrix.org" # private room (invite)
        ];
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
    ];

    sini.includes = with den.aspects; [ services.ai.genie-bank-review ];
    vic.includes = with den.aspects; [ roles.dev ];
  };
}
