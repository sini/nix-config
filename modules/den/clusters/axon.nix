# Axon k3s cluster — 3-node production cluster with dual-stack networking.
#
# Network topology:
#   control-plane   — management VLAN, carries kube-apiserver VIP
#   kubernetes-pods — CNI pod overlay (Cilium, dual-stack)
#   kubernetes-services — ClusterIP range (dual-stack), CoreDNS lives here
#   kubernetes-loadbalancers — external LB pool advertised via BGP
{ den, ... }:
{
  den.clusters.axon = {
    environment = "prod";
    role = "k3s";
    kubeVersion = "1.36.1";
    secretPath = ./. + "/../../../.secrets/clusters/axon";

    # Coder bootstrap complete: the first admin was created via the wizard and
    # promoted to owner, so lock the login page to kanidm OIDC only
    # (bootstrap=false → CODER_DISABLE_PASSWORD_AUTH=true; owners keep a password
    # backdoor per Coder's anti-lockout). Set back to true to re-run first-user
    # setup. See modules/den/aspects/kubernetes/services/dev/coder/settings.nix.
    settings.kubernetes.services.dev.coder.coder.bootstrap = false;

    # Pin Cilium's datapath devices to the physical NICs: enp2s0 (WAN
    # ingress/egress + masquerade) and the thunderbolt-fabric NICs
    # enp199s0f5/f6 (inter-node geneve, routed by OpenFabric). The `enp+`
    # wildcard excludes tailscale0, which Cilium's auto-detection otherwise
    # pulls into its masquerade/device-watch set — the admin tailnet does not
    # carry cluster data-plane traffic. See
    # modules/den/aspects/kubernetes/services/network/cilium/settings.nix.
    settings.kubernetes.services.network.cilium.devices = "enp+";

    # RomM initial full-library scan: the ~100k-ROM first pass far exceeds RomM's
    # 4h default scan window, so give the scan job a 14-day timeout and raise the
    # per-ROM scan concurrency (SCAN_WORKERS — an asyncio semaphore over
    # metadata-provider I/O) well above the serial default. Replicas stay at 1:
    # they do not speed a single scan. See
    # modules/den/aspects/kubernetes/services/media/romm-settings.nix.
    settings.kubernetes.services.media.romm.scanTimeout = 14 * 24 * 60 * 60; # 14 days
    settings.kubernetes.services.media.romm.scanWorkers = 10;

    # Postfix relay to Proton: all mail leaves as infra@json64.dev, the address
    # the SMTP submission token belongs to. smtp.json64.dev resolves to the
    # smtp-relay-internal LB address below (domains/domains.nix). See
    # modules/den/aspects/kubernetes/services/communication/smtp-relay.nix.
    settings.kubernetes.services.communication.smtp-relay = {
      domain = "json64.dev";
      hostname = "smtp.json64.dev";
      issuer = "json64-dev";
      upstream = {
        host = "smtp.protonmail.ch";
        username = "infra@json64.dev";
        passwordSecret = "smtp-infra-at-json64-dev.age";
      };
    };

    networks = {
      control-plane = {
        cidr = "10.10.10.0/24";
        description = "Cluster control plane (VIP on management network)";
        assignments = {
          kube-apiserver-vip = "10.10.10.100";
        };
      };

      kubernetes-pods = {
        cidr = "172.20.0.0/16";
        ipv6_cidr = "fdfd:cafe:00:0001::/96";
        description = "Kubernetes pod network";
      };

      kubernetes-services = {
        cidr = "172.21.0.0/16";
        ipv6_cidr = "fdfd:cafe:00:8001::/112";
        description = "Kubernetes service network";
        assignments = {
          coredns = "172.21.0.10";
        };
      };

      kubernetes-loadbalancers = {
        cidr = "10.11.0.0/16";
        description = "LoadBalancer service IP range";
        assignments = {
          cilium-ingress-controller = "10.11.0.2";
          default-gateway = "10.11.0.1";
          # Internal-only LB for Shoko's API, reached by Jellyfin/Shokofin on the
          # uplink host (off-cluster) so it bypasses the OIDC-gated public route.
          # BGP-advertised to uplink, NOT internet-routable. See media/shoko.nix.
          shoko-internal = "10.11.0.10";

          # ai stack, .20-.29 — private-network reach for the memory bank and the
          # inference endpoints, so LAN hosts and workstations can use them
          # without a public HTTPRoute. BGP-advertised, NOT internet-routable.
          # The llama-cpp names are derived from the instance keys in
          # kubernetes.services.ai.llama-cpp.instances: adding an instance
          # without adding its address here fails at eval, by design.
          hindsight-internal = "10.11.0.20";
          # .21 held llama-cpp-qwen-internal until the qwen instance was
          # dropped (see llama-cpp-settings.nix for why, and for the entry to
          # restore). Left reserved rather than reused so bringing it back is
          # additive.
          llama-cpp-gpt-oss-internal = "10.11.0.22";
          hindsight-cp-internal = "10.11.0.23";

          # Postfix relay to Proton (communication/smtp-relay.nix), published
          # as smtp.json64.dev. BGP-advertised, NOT internet-routable.
          smtp-relay-internal = "10.11.0.30";

          # Host metrics/log push into Prometheus + Loki
          # (monitoring/ingest.nix), published as ingest.json64.dev.
          monitoring-ingest = "10.11.0.31";
        };
      };
    };

    # Reserved (NOT networks entries — nothing should iterate these as cluster
    # networks): thunderbolt fabric loopbacks, assigned per-host in
    # hosts/axon-0N.nix (services.networking.thunderbolt-mesh-of.loopback):
    #   172.16.255.0/24      ipv4 fabric loopbacks (axon-0N = .N/32)
    #   fdfd:cafe:0:ff::/64  ipv6 fabric loopbacks (axon-0N = ::N/128)

    # The NAS exports below must allow non-privileged ports (Synology: "Allow
    # connections from non-privileged ports"; security sys, squash root to
    # admin). Cilium masquerade rewrites the client's <1024 source port, so a
    # default "secure" export refuses pod-netns mounts with EPERM.
    nfsVolumes.vault-nfs = {
      server = "10.10.10.10";
      share = "/volume2/data";
    };

    # Off-cluster backup target for the Longhorn backupstore (NOT a
    # StorageClass — csi-driver-nfs filters type="backup" out). Consumed by
    # the longhorn aspect's BackupTarget.
    nfsVolumes.longhorn-backups = {
      server = "10.10.10.10";
      share = "/volume2/longhorn-backups";
      type = "backup";
    };
  };

  # Cluster aspect — k8s services included at cluster scope
  den.aspects.axon = {
    includes = with den.aspects.kubernetes; [
      hardware.amd-gpu-device-plugin
      hardware.gvisor
      bootstrap
      services.network.cilium
      services.network.cilium.cilium-bgp-resources
      services.network.coredns
      services.security.cert-manager
      services.security.sops-secrets-operator
      services.argocd
      services.network.gateway.envoy-gateway
      services.network.gateway.host-upstreams
      # gateway-api aspect NOT included: envoy-gateway's gateway-crds-helm is
      # the sole Gateway API CRD owner (experimental channel, matches live
      # cluster); a second standard-channel copy duplicated every shared kind
      # and blocked the bootstrap sync. Its cilium GatewayClass was unused
      # (default-gateway is class envoy).
      services.storage.longhorn
      services.storage.csi-driver-nfs
      services.storage.volume-snapshots
      services.storage.cloudnative-pg
      services.monitoring.prometheus
      services.monitoring.metrics-server
      services.monitoring.loki
      services.monitoring.alloy
      services.monitoring.monitoring-pg
      services.monitoring.grafana
      services.monitoring.ingest
      services.network.cilium.hubble-ui
      services.media.base
      services.media.media-pg
      services.media.api-keys
      services.media.prowlarr
      services.media.flaresolverr
      services.media.sonarr
      services.media.radarr
      services.media.lidarr
      services.media.whisparr
      services.media.bazarr
      services.media.sabnzbd
      # TODO: allocate against LLM GPU resources (see hardware.amd-gpu-device-plugin) and enable
      #services.media.tdarr
      services.media.qbittorrent
      services.media.unpackerr
      services.media.profilarr
      services.media.shoko
      services.media.network-policy
      services.media.glance
      services.media.dash
      services.media.romm
      services.media.komga

      # communication — Matrix homeserver (server_name json64.dev, served at
      # matrix.json64.dev; kanidm native OIDC). See communication/matrix/synapse.nix.
      services.communication.matrix.matrix-pg
      services.communication.matrix.synapse
      services.communication.matrix.matrix-admin
      services.communication.matrix.synapse-admins
      services.communication.matrix.tuwunel

      # communication — Postfix relay to Proton for LAN and in-cluster senders.
      services.communication.smtp-relay

      # ai — Hindsight agent memory bank. Cluster-internal in this wave: no
      # route, no service domain (see hindsight.nix on why exposure is separate).
      services.ai.hindsight-pg
      services.ai.hindsight

      # ai — llama.cpp on the node APUs (Radeon 780M, Vulkan). Cluster-internal;
      # requires hardware.amd-gpu-device-plugin above for the amd.com/gpu resource.
      services.ai.llama-cpp

      # dev — Coder workspace platform (SP1 control plane)
      services.dev.coder.coder-pg
      services.dev.coder.coder

      # storage — Garage S3 (operator-managed, 3-node; public S3 + OIDC UI)
      services.security.reflector
      services.storage.garage.secrets
      services.storage.garage.garage-operator
      services.storage.garage.garage-cluster
      services.storage.garage.network-policy
      services.storage.garage.routes
      services.storage.garage.garage-ui
      services.storage.garage.sites
    ];
  };
}
