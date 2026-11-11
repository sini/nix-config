{ den, ... }:
{
  den.hosts.x86_64-linux.uplink = {
    channel = "nixpkgs-master";
    environment = "prod";
    system-owner = "sini";
    system-access-groups = [ "server-access" ];

    networking.interfaces.enp4s0 = {
      ipv4 = [ "10.10.10.1/16" ];
      ipv6 = [
        "fe80::3c7a:6eff:fee5:d3a6"
        # Blocky's stable IPv6 address, ::53 in prod's ULA; the ISP prefix can change.
        (builtins.replaceStrings [ "::/64" ] [ "::53/64" ] den.environments.prod.networks.default.ipv6_cidr)
      ];
      # br0 adopts the NIC's own MAC, so the router, ARP caches and the SLAAC
      # addresses see no change from bridging.
      mac = "24:8a:07:e0:a8:b0";
      # The LAN reaches Blocky's ::53 on-link: br0 advertises the ULA's prefix.
      advertiseUla = true;
    };

    # enp4s0 moves into br0 with the addressing above; the networking aspect
    # matches `vm-*` taps into br0, so guests land directly on the LAN.
    networking.bridges.br0 = [ "enp4s0" ];

    # den-ag-design sessions with uplink's memory (uplink-dev.nix).
    guests.uplink-dev = den.hosts.x86_64-linux.uplink-dev;

    settings = {
      services.bgp.localAsn = 65000;
      # 32 cores / 128 GB: the fleet's heaviest builder (an axon is 16 / 64). Four builds of
      # eight cores keep the product at the core count, so two link-heavy builds cannot square it.
      core.nix = {
        maxJobs = 4;
        cores = 8;
      };
      roles.nix-builder = {
        maxJobs = 4;
        speedFactor = 4;
      };
      # Break-glass jumpbox: sshd stays publicly reachable (all other hosts are
      # tailnet/LAN-only).
      core.security.openssh.exposure = "public";
      disk.zfs-disk-single.device_id = "/dev/disk/by-id/nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
      core.impermanence = {
        wipeRootOnBoot = true;
        wipeHomeOnBoot = true;
      };
      # Always-on Syncthing hub for replicated home dirs (the bgp pattern: the
      # aspect declares the option, the host file sets it).
      core.network.syncthing.isHub = true;
      # The prod resolver instance (Blocky, docs/dns-resolver.md), the same pattern.
      services.networking.blocky.isResolver = true;
      # Fleet alerting, mailed straight to Proton (not via the cluster relay).
      services.monitoring.alertmanager.smtp = {
        host = "smtp.protonmail.ch";
        username = "infra@json64.dev";
        passwordSecret = "smtp-infra-at-json64-dev.age";
      };
      # Credential reset / account recovery mail, through the cluster's Postfix
      # relay to Proton (kubernetes/services/communication/smtp-relay.nix).
      services.security.kanidm.mailSender = {
        relay = "smtp://smtp.json64.dev:587";
        fromAddress = "infra@json64.dev";
        replyToAddress = "jason@json64.dev";
        instanceDisplayName = "json64";
      };
      # nginx accepts PROXY v2 from the cluster gateway here (kanidm holds
      # 127.0.0.1:8443).
      services.networking.gateway-upstream = {
        proxyProtocolPort = 8444;
        # The gateway sends PROXY v2 there, so nginx logs the client address.
        proxyProtocol = true;
      };
    };
  };

  den.aspects.uplink = {
    includes = with den.aspects; [
      roles.default
      core.boot.network-initrd
      disk.zfs-disk-single
      roles.server
      roles.unlock
      roles.nix-builder
      services.monitoring.alertmanager
      services.bgp.hub
      services.networking.headscale
      services.networking.blocky
      services.security.acme
      dns-state-passphrase
      unifi-state-passphrase
      github-state-passphrase
      services.networking.nginx
      services.security.kanidm
      services.networking.gateway-upstream
      services.media.jellyfin
      services.web.homepage
      services.security.oauth2-proxy
      services.ai.ollama
      services.ai.open-webui
      services.nix.attic
      core.network.tailscale
      core.network.tailscale.exit-node
      core.network.syncthing.hub
      services.web.den-docs-mirror
      services.web.gen-status
      services.web.container-registry
      # The admin panel runs in the cluster (kubernetes.services.network.blocky-ui).
      #services.networking.blocky-ui
      virtualization.podman
      virtualization.microvm-host
      hardware.cpu.amd
      hardware.gpu.intel
    ];

    # uplink-dev's own host key, copied (not symlinked: the guest cannot follow
    # a link into /run/agenix) into the dir shared to it.
    nixos.age.secrets.uplink-dev-host-key = {
      rekeyFile = ./. + "/../../../.secrets/hosts/uplink-dev/ssh_host_ed25519_key.age";
      path = "/var/lib/microvms/uplink-dev/host-key/ssh_host_ed25519_key";
      symlink = false;
      mode = "0400";
    };
  };
}
