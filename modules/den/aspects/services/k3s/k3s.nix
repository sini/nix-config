# K3s server aspect — full server-mode k3s with HA (keepalived VRRP),
# Cilium CNI (flannel disabled), OIDC via Kanidm, etcd snapshots,
# and bootstrap services (Cilium -> CoreDNS -> SOPS -> ArgoCD).
#
# Emits k3s-nodes quirk; consumes collected nodes for peer discovery,
# bootstrap ordering, keepalived, and TLS SANs.
#
# Static node plumbing (kernel modules, firewall, tooling) lives in the
# `node` sub-aspect; the bootstrap systemd units live in the `bootstrap`
# sub-aspect (./bootstrap.nix).
{
  den,
  lib,
  config,
  ...
}:
let
  inherit (lib)
    concatStringsSep
    flatten
    head
    mkForce
    mkOption
    types
    ;

  clusters = config.den.clusters or { };
  environments = config.den.environments;
in
{
  den.aspects.services.k3s = {
    includes = [
      den.aspects.services.k3s.containerd
      den.aspects.services.k3s.node
      den.aspects.services.k3s.bootstrap
    ];

    settings = {
      clusterName = mkOption {
        type = types.str;
        default = "axon";
        description = "Name of the den.clusters entry this host belongs to";
      };
    };

    # Emit node info for peer discovery
    k3s-nodes =
      { environment, host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        ipv6 = builtins.head host.ipv6;
        inherit environment;
        clusterName = host.settings.services.k3s.clusterName;
        # BGP and cilium-bgp settings needed by cilium-bgp-resources
        bgpLocalAsn = host.settings.services.bgp.localAsn or null;
        ciliumBgpLocalAsn = (host.settings.services.bgp.cilium-bgp or { }).localAsn or null;
        # OpenFabric loopback (if on the thunderbolt mesh). Inter-node etcd/k3s
        # traffic to peer mgmt IPs is routed over the fabric and sourced from
        # this loopback, so it must be a TLS SAN or peer-cert checks reject it.
        fabricLoopback =
          let
            lo = (host.settings.services.networking.thunderbolt-mesh-of or { }).loopback or null;
          in
          if lo != null then builtins.head (lib.splitString "/" lo.ipv4) else null;
      };

    nixos =
      {
        k3s-nodes,
        config,
        pkgs,
        host,
        ...
      }:
      let
        clusterName = host.settings.services.k3s.clusterName;
        cluster = clusters.${clusterName};

        environment = environments.${cluster.environment};

        podNetwork = cluster.networks.kubernetes-pods;
        serviceNetwork = cluster.networks.kubernetes-services;
        vip = cluster.getAssignment "kube-apiserver-vip";
        managementCidr = cluster.networks.control-plane.cidr;
        managementSubnet = lib.last (lib.splitString "/" managementCidr);

        # Filter collected nodes to same cluster (same-environment scoping
        # guaranteed by collect-k3s-nodes policy)
        clusterNodes = lib.filter (n: n.clusterName == clusterName) k3s-nodes;

        sortedNodes = builtins.sort (a: b: a.hostname < b.hostname) clusterNodes;

        nodeId =
          let
            result = lib.lists.findFirstIndex (node: node.hostname == host.name) null sortedNodes;
          in
          assert lib.assertMsg (result != null) ''
            den: k3s aspect failed to find host "${host.name}" in cluster peers.
            Available: ${concatStringsSep ", " (map (n: n.hostname) sortedNodes)}
          '';
          result;

        # Bootstrap when only one node is declared (initial cluster formation)
        shouldInit = (builtins.length sortedNodes) == 1;

        masterIP =
          if shouldInit then
            vip
          else
            let
              otherNodes = lib.filter (node: node.hostname != host.name) sortedNodes;
            in
            (head otherNodes).ip;

        # TLS SANs: VIP + all peer node IPs + hostnames + tailscale names +
        # fabric loopbacks (etcd peer traffic is sourced from these over the mesh)
        peerTlsSans = flatten (
          map (
            node:
            [
              "--tls-san=${node.ip}"
              "--tls-san=${node.hostname}"
              "--tls-san=${node.hostname}.ts.${environment.domain}"
            ]
            ++ lib.optional (node.fabricLoopback or null != null) "--tls-san=${node.fabricLoopback}"
          ) sortedNodes
        );

        generalFlagList = [
          "--snapshotter=overlayfs"
          "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"

          "--node-ip=${head host.ipv4},${head host.ipv6}"
          "--node-external-ip=${head host.ipv4},${head host.ipv6}"
          "--node-name=${config.networking.hostName}"
          "--node-label=node.longhorn.io/create-default-disk=true"
          "--node-label=node.kubernetes.io/amd-gpu=true"
          "--node-label \"k3s-upgrade=false\""
          "--kubelet-arg=register-with-taints=node.cilium.io/agent-not-ready:NoExecute"
        ];

        serverFlagList = [
          "--bind-address=0.0.0.0"
          "--advertise-address=${head host.ipv4}"
          "--cluster-cidr=${podNetwork.cidr},${podNetwork.ipv6_cidr}"
          "--service-cidr=${serviceNetwork.cidr},${serviceNetwork.ipv6_cidr}"
          "--kube-controller-manager-arg=--node-cidr-mask-size-ipv6=112"
          "--kubelet-arg=fail-swap-on=false"

          "--write-kubeconfig-mode \"0644\""
          "--kubelet-arg=--cluster-dns=${cluster.getAssignment "coredns"}"

          # etcd: 12h snapshots, 8GB quota, periodic compaction
          "--etcd-expose-metrics"
          "--etcd-snapshot-schedule-cron='0 */12 * * *'"
          "--etcd-arg=quota-backend-bytes=8589934592"
          "--etcd-arg=max-wals=5"
          "--etcd-arg=auto-compaction-mode=periodic"
          "--etcd-arg=auto-compaction-retention=30m"

          # Disable built-ins replaced by our stack
          "--disable metrics-server"
          "--disable local-storage"
          "--disable traefik"
          "--disable coredns"
          "--disable servicelb"
          "--flannel-backend=none"
          "--disable-network-policy"
          "--disable-kube-proxy"
          "--disable-cloud-controller"
          "--disable-helm-controller"

          # TLS SANs: API domain + FQDN + hostname + node IP + VIP
          "--tls-san=k8s.${environment.domain}"
          "--tls-san=${config.networking.fqdn}"
          "--tls-san=${config.networking.hostName}"
          "--tls-san=${config.networking.hostName}.ts.${environment.domain}"
          "--tls-san=${head host.ipv4}"
          "--tls-san=${vip}"

          # OIDC via Kanidm
          "--kube-apiserver-arg=oidc-issuer-url=https://${environment.getDomainFor "kanidm"}/oauth2/openid/kubernetes"
          "--kube-apiserver-arg=oidc-client-id=kubernetes"
          "--kube-apiserver-arg=oidc-signing-algs=ES256"
          "--kube-apiserver-arg=oidc-username-claim=email"
          "--kube-apiserver-arg=oidc-groups-claim=groups"
        ]
        ++ peerTlsSans;

        serverFlags = concatStringsSep " " (generalFlagList ++ serverFlagList);
      in
      {
        services = {
          # Keepalived VRRP — floats the kube-apiserver VIP across server nodes
          keepalived = {
            enable = true;
            vrrpScripts.check_k3s = {
              script = "${lib.getExe pkgs.netcat} -z 127.0.0.1 6443";
              interval = 2;
              weight = -20;
              fall = 2;
              rise = 2;
            };
            vrrpInstances.k3s = {
              state = if (nodeId == 0) then "MASTER" else "BACKUP";
              interface = "enp2s0";
              virtualRouterId = 51;
              priority = 100 - nodeId;
              virtualIps = [
                { addr = "${vip}/${managementSubnet}"; }
              ];
              trackScripts = [ "check_k3s" ];
            };
          };

          k3s = {
            clusterInit = shouldInit;
            enable = true;
            role = "server";
            tokenFile = config.age.secrets.kubernetes-cluster-token.path;
            gracefulNodeShutdown.enable = true;
            extraFlags = mkForce serverFlags;
          }
          // lib.optionalAttrs (!shouldInit) {
            serverAddr = "https://${masterIP}:6443";
          };

          # Required for Longhorn
          openiscsi = {
            enable = true;
            name = "iqn.2016-04.com.open-iscsi:${config.networking.fqdn}";
          };
        };

        systemd = {
          tmpfiles.rules = [
            "d /var/lib/longhorn 0750 root root -"
            "L+ /usr/local/bin/iscsiadm - - - - ${pkgs.openiscsi}/bin/iscsiadm"
          ];

          services.multipathd.enable = mkForce false;
        };
      };

    # Secrets: cluster token (all nodes) + SOPS age key (always provisioned,
    # but only used by bootstrap services which are guarded by shouldInit)
    age-secrets =
      { host, ... }:
      let
        clusterName = host.settings.services.k3s.clusterName;
        cluster = clusters.${clusterName};
      in
      {
        age.secrets.kubernetes-cluster-token = {
          rekeyFile = cluster.secretPath + "/cluster-token.age";
          generator.script = "passphrase";
        };

        age.secrets.kubernetes-sops-age-key = {
          rekeyFile = cluster.secretPath + "/cluster-sops-age-key.age";
          path = "/var/lib/sops/age/key.txt";
        };
      };

    # Persist k3s and kubeconfig state across reboots
    persist = {
      directories = [
        "/var/lib/rancher"
        "/var/lib/kubelet"
        "/etc/rancher"
      ];
    };
  };
}
