# K3s server aspect — full server-mode k3s with HA (keepalived VRRP),
# Cilium CNI (flannel disabled), OIDC via Kanidm, etcd snapshots,
# and bootstrap services (Cilium -> CoreDNS -> SOPS -> ArgoCD).
#
# Cluster membership and network CIDRs are resolved from den.clusters.
# Bootstrap services are oneshot systemd units that apply manifests in
# dependency order during initial cluster formation.
{
  den,
  lib,
  config,
  self,
  ...
}:
let
  inherit (lib)
    attrNames
    attrValues
    concatStringsSep
    filterAttrs
    findFirst
    flatten
    head
    mapAttrsToList
    mkForce
    mkIf
    mkOption
    optionals
    types
    ;

  clusters = config.den.clusters or { };
  environments = config.den.environments;
  allHosts = config.den.hosts.x86_64-linux or { };
in
{
  den.aspects.services.k3s = {
    includes = [ den.aspects.services.k3s-containerd ];

    settings = {
      clusterName = mkOption {
        type = types.str;
        default = "axon";
        description = "Name of the den.clusters entry this host belongs to";
      };
    };

    nixos =
      {
        config,
        pkgs,
        host,
        ...
      }:
      let
        clusterName = host.settings.services.k3s.clusterName;
        cluster = clusters.${clusterName};

        # Resolve environment for domain/OIDC lookups
        environment = environments.${cluster.environment};

        # Network CIDRs from cluster definition
        podNetwork = cluster.networks.kubernetes-pods;
        serviceNetwork = cluster.networks.kubernetes-services;
        vip = cluster.getAssignment "kube-apiserver-vip";
        managementCidr = cluster.networks.control-plane.cidr;
        managementSubnet = lib.last (lib.splitString "/" managementCidr);
        k3sHosts = filterAttrs (
          _: h: h.environment == cluster.environment && (h.settings.services.k3s or { }) != { }
        ) allHosts;

        # Deterministic ordering by hostname
        sortedNodes = builtins.sort (a: b: a.name < b.name) (attrValues k3sHosts);

        nodeId =
          let
            result = lib.lists.findFirstIndex (node: node.name == host.name) null sortedNodes;
          in
          assert lib.assertMsg (result != null) ''
            den: k3s aspect failed to find host "${host.name}" in cluster peers.
            Available: ${concatStringsSep ", " (map (n: n.name) sortedNodes)}
          '';
          result;

        # Bootstrap when only one node is declared (initial cluster formation)
        shouldInit = (builtins.length sortedNodes) == 1;

        # Join address: VIP when bootstrapping, otherwise first other node
        masterIP =
          if shouldInit then
            vip
          else
            let
              otherNodes = lib.filter (node: node.name != host.name) sortedNodes;
            in
            head (head otherNodes).ipv4;

        # Manifest paths — each directory isolated into its own store path so
        # unrelated repo changes don't invalidate bootstrap derivations
        manifestBase = self + "/generated/manifests/${cluster.environment}-${clusterName}";
        manifestPath =
          name:
          builtins.path {
            path = manifestBase + "/${name}";
            name = "${clusterName}-${builtins.replaceStrings [ "/" "." ] [ "-" "-" ] name}";
          };

        # TLS SANs: VIP + all peer node IPs + hostnames + tailscale names
        peerTlsSans = flatten (
          map (node: [
            "--tls-san=${head node.ipv4}"
            "--tls-san=${node.name}"
            "--tls-san=${node.name}.ts.${environment.domain}"
          ]) sortedNodes
        );

        generalFlagList = [
          "--image-service-endpoint=unix:///run/nix-snapshotter/nix-snapshotter.sock"
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
        environment.systemPackages = with pkgs; [
          k3s
          k9s
          kubectl
          istioctl
          kubernetes-helm
          cilium-cli

          clusterctl
          nerdctl

          skopeo
          go-containerregistry
          dive

          openiscsi
          nfs-utils

          util-linux
          parted
          gptfdisk
          lvm2
        ];

        boot = {
          kernelModules = [
            # Filesystem
            "ceph"
            "rbd"
            "nfs"
            "overlay"
            # Networking / eBPF
            "bpf"
            "ip_tables"
            "br_netfilter"
            "nft-expr-counter"
            "iptable_nat"
            "iptable_filter"
            "nft_counter"
            "ip6_tables"
            "ip6table_mangle"
            "ip6table_raw"
            "ip6table_filter"
            "ip_conntrack"
            "ip_vs"
            "ip_vs_rr"
            "ip_vs_wrr"
            "ip_vs_sh"
            "iscsi_tcp"
          ];

          kernel.sysctl = {
            "net.bridge.bridge-nf-call-iptables" = 1;
            "net.bridge.bridge-nf-call-ip6tables" = 1;
            "net.core.bpf_jit_enable" = 1;
            "net.core.bpf_jit_harden" = 0;
          };

          blacklistedKernelModules = [ "nbd" ];
        };

        networking.firewall = {
          enable = mkForce false;

          allowedTCPPorts = flatten [
            179 # BGP
            6443 # Kubernetes API
            6444
            6081
            10250 # Kubelet metrics
            2379 # etcd
            2380 # etcd
            4240 # Cilium healthcheck
            4244 # Hubble API
            8080
            443
            9500 # Longhorn Manager
          ];

          allowedUDPPorts = [
            8472 # Cilium VXLAN
            4789 # Cilium VXLAN fallback
            51820 # WireGuard
          ];

          trustedInterfaces = [
            "lo"
            "cni+"
            "cilium+"
            "lxc+"
            "enp199s0f5"
            "enp199s0f6"
          ];

          extraCommands = ''
            iptables -A nixos-fw -p vrrp -j ACCEPT
          '';
        };

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

        # Bootstrap services — oneshot systemd units that apply manifests in order
        systemd = {
          tmpfiles.rules = [
            "d /var/lib/longhorn 0750 root root -"
            "L+ /usr/local/bin/iscsiadm - - - - ${pkgs.openiscsi}/bin/iscsiadm"
          ];

          services = {
            multipathd.enable = mkForce false;

            # Wave -2: Cilium CNI + CoreDNS (networking must come first)
            k3s-bootstrap-cilium = mkIf shouldInit {
              description = "Bootstrap Cilium CNI and CoreDNS";
              after = [ "k3s.service" ];
              requires = [ "k3s.service" ];
              path = with pkgs; [
                kubectl
                cilium-cli
              ];
              environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "k3s-bootstrap-cilium" ''
                  set -e

                  echo "Waiting for k3s API server..."
                  until kubectl get nodes; do
                    sleep 5
                  done

                  if ${lib.getExe pkgs.cilium-cli} --kubeconfig $KUBECONFIG status >/dev/null 2>&1; then
                    echo "Cilium already installed."
                    exit 0
                  fi

                  echo "Applying bootstrap resources..."
                  ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                    --server-side --force-conflicts \
                    -f ${manifestPath "bootstrap"} || true

                  echo "Applying Cilium manifests..."
                  ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                    --server-side --force-conflicts \
                    -f ${manifestPath "cilium"} || true
                  sleep 30

                  echo "Applying CoreDNS manifests..."
                  ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                    --server-side --force-conflicts \
                    -f ${manifestPath "coredns"} || true
                  sleep 30
                '';
              };
              wantedBy = [ "multi-user.target" ];
            };

            # Wave -1: SOPS secrets operator + cert-manager
            k3s-install-sops-secrets-operator = mkIf shouldInit {
              description = "Bootstrap SOPS secrets operator and cert-manager";
              after = [
                "k3s.service"
                "k3s-bootstrap-cilium.service"
              ];
              requires = [
                "k3s.service"
                "k3s-bootstrap-cilium.service"
              ];
              path = [ pkgs.kubectl ];
              environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "k3s-install-sops" ''
                  set -e

                  echo "Waiting for k3s API server..."
                  until kubectl get nodes; do
                    sleep 5
                  done

                  if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get namespace sops-secrets-operator >/dev/null 2>&1; then
                    ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG create namespace sops-secrets-operator
                  fi

                  if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG --namespace sops-secrets-operator get secret sops-age-key-file >/dev/null 2>&1; then
                    ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG create secret generic sops-age-key-file \
                      --namespace sops-secrets-operator \
                      --from-file=key=${config.age.secrets.kubernetes-sops-age-key.path}
                  fi

                  if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get deployment -n sops-secrets-operator sops-sops-secrets-operator >/dev/null 2>&1; then
                    ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                      --server-side --force-conflicts \
                      -f ${manifestPath "sops-secrets-operator"}
                    sleep 30
                  fi

                  if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get deployment -n cert-manager cert-manager >/dev/null 2>&1; then
                    ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                      --server-side --force-conflicts \
                      -f ${manifestPath "cert-manager"}
                    sleep 30
                  fi
                '';
              };
              wantedBy = [ "multi-user.target" ];
            };

            # Wave -1: ArgoCD (depends on SOPS for secret decryption)
            k3s-install-argocd = mkIf shouldInit {
              description = "Bootstrap ArgoCD";
              after = [
                "k3s.service"
                "k3s-bootstrap-cilium.service"
                "k3s-install-sops-secrets-operator.service"
              ];
              requires = [
                "k3s.service"
                "k3s-bootstrap-cilium.service"
                "k3s-install-sops-secrets-operator.service"
              ];
              path = [ pkgs.kubectl ];
              environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = pkgs.writeShellScript "k3s-install-argocd" ''
                  set -e

                  echo "Waiting for k3s API server..."
                  until kubectl get nodes; do
                    sleep 5
                  done

                  if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get namespace argocd >/dev/null 2>&1; then
                    ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG create namespace argocd
                  fi

                  if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get deployment -n argocd argocd-server >/dev/null 2>&1; then
                    ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                      --server-side --force-conflicts \
                      -f ${manifestPath "argocd"}
                    ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                      -f ${manifestPath "bootstrap.yaml"}
                  fi
                '';
              };
              wantedBy = [ "multi-user.target" ];
            };
          };
        };
      };

    # Secrets: cluster token (all nodes) + SOPS age key (bootstrap only)
    age-secrets =
      { host, ... }:
      let
        clusterName = host.settings.services.k3s.clusterName;
        cluster = clusters.${clusterName};
        k3sHosts = filterAttrs (
          _: h: h.environment == cluster.environment && (h.settings.services.k3s or { }) != { }
        ) allHosts;
        shouldInit = (builtins.length (attrValues k3sHosts)) == 1;
      in
      {
        age.secrets.kubernetes-cluster-token = {
          rekeyFile = cluster.secretPath + "/cluster-token.age";
          generator.script = "passphrase";
        };

        age.secrets.kubernetes-sops-age-key = mkIf shouldInit {
          rekeyFile = cluster.secretPath + "/cluster-sops-age-key.age";
          path = "/var/lib/sops/age/key.txt";
        };
      };

    # Persist k3s and kubeconfig state across reboots
    persist = {
      directories = [
        "/var/lib/rancher/k3s"
        "/var/lib/kubelet"
        "/etc/rancher"
      ];
    };
  };
}
