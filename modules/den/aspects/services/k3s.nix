# K3s Kubernetes — server role with Cilium, keepalived VIP, and GitOps bootstrap.
#
# This is the most complex service aspect, managing:
#   - K3s server with embedded etcd
#   - Keepalived for API server VIP
#   - Bootstrap services for Cilium, SOPS, cert-manager, ArgoCD
#   - Firewall, impermanence, and secrets
#
# NOTE: Settings that should be typed (not yet in schema):
#   - k3s.role (str, "server" or "agent")
#   - k3s.clusterInit (bool)
#   - k3s.clusterCidr (str)
#   - k3s.serviceCidr (str)
{
  den,
  lib,
  rootPath,
  ...
}:
{
  den.aspects.k3s = {
    includes = lib.attrValues den.aspects.k3s._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
          cluster = host.cluster or null;
        in
        {
          nixos =
            {
              config,
              lib,
              pkgs,
              ...
            }:
            let
              managementSubnet = "/${lib.last (lib.splitString "/" environment.networks.default.cidr)}";

              kubernetesNodes = environment.findHostsByFeature "k3s";

              # Sort kubernetes nodes by hostname for deterministic ordering
              sortedKubernetesNodes = builtins.sort (a: b: a.hostname < b.hostname) (
                lib.mapAttrsToList (hostname: hostConfig: hostConfig // { inherit hostname; }) kubernetesNodes
              );

              # Get current node's index in the sorted list
              nodeId =
                let
                  result = lib.lists.findFirstIndex (
                    node: node.hostname == config.networking.hostName
                  ) null sortedKubernetesNodes;
                in
                assert lib.assertMsg (result != null) ''
                  Failed to find current host "${config.networking.hostName}" in kubernetes nodes.
                  Available nodes: ${builtins.concatStringsSep ", " (map (n: n.hostname) sortedKubernetesNodes)}
                '';
                result;

              # Initialize if there is only one kubernetes node -- the cluster is bootstrapping
              shouldInit = (builtins.length (lib.attrValues kubernetesNodes)) == 1;

              # Find master node for agent connection
              masterIP =
                if shouldInit then
                  cluster.getAssignment "kube-apiserver-vip"
                else
                  let
                    otherNodes = lib.filter (node: node.hostname != config.networking.hostName) sortedKubernetesNodes;
                    firstOtherNode = builtins.head otherNodes;
                  in
                  builtins.head firstOtherNode.ipv4;

              # Isolate each manifest directory/file into its own store path
              manifestBase =
                rootPath + "/generated/manifests/${cluster.resolvedEnvironment.name}-${cluster.name}";
              manifestPath =
                name:
                builtins.path {
                  path = manifestBase + "/${name}";
                  name = "${cluster.name}-${builtins.replaceStrings [ "/" "." ] [ "-" "-" ] name}";
                };
            in
            lib.mkIf (cluster != null) {
              environment.systemPackages = with pkgs; [
                k3s
                k9s
                kubectl
                istioctl
                kubernetes-helm
                cilium-cli

                clusterctl # for kubernetes cluster-api
                nerdctl # containerd CLI, similar to docker CLI

                skopeo # copy/sync images between registries and local storage
                go-containerregistry # provides `crane` & `gcrane`
                dive # explore docker layers

                openiscsi # Required for Longhorn
                nfs-utils # Required for Longhorn

                # Filesystem tools
                util-linux
                parted
                gptfdisk
                lvm2
              ];

              boot = {
                # Kernel modules required by k3s
                kernelModules = [
                  # Filesystem support:
                  "ceph"
                  "rbd"
                  "nfs"
                  "overlay"
                  # Networking support:
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

                # Enable eBPF
                kernel.sysctl = {
                  "net.bridge.bridge-nf-call-iptables" = 1;
                  "net.bridge.bridge-nf-call-ip6tables" = 1;
                  "net.core.bpf_jit_enable" = 1;
                  "net.core.bpf_jit_harden" = 0;
                };

                # Blacklist nbd module to prevent ceph-volume from hanging
                blacklistedKernelModules = [ "nbd" ];
              };

              networking = {
                firewall = {
                  # For debug, disable firewall...
                  enable = lib.mkForce false;

                  allowedTCPPorts = lib.flatten [
                    179 # BGP
                    6443 # Kubernetes API
                    6444
                    6081
                    # Cilium Geneve
                    10250 # Kubelet metrics
                    2379 # etcd
                    2380 # etcd
                    4240 # clilum healthcheck
                    4244 # hubble api
                    8080
                    443

                    # Longhorn Manager
                    9500
                    # Longhorn Engine
                    10250
                  ];

                  allowedUDPPorts = [
                    8472 # Cilium VXLAN
                    4789 # Cilium VXLAN fallback
                  ];

                  trustedInterfaces = [
                    "lo"
                    "cni+"
                    "cilium+"
                    "lxc+"
                    # Thunderbolt mesh interfaces
                    "enp199s0f5"
                    "enp199s0f6"
                  ];

                  # Allow VRRP protocol for Keepalived (IPv4 only)
                  extraCommands = ''
                    iptables -A nixos-fw -p vrrp -j ACCEPT
                  '';
                };
              };

              services = {
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
                    interface = "enp2s0"; # All our current k3s nodes have this interface...
                    virtualRouterId = 51;
                    priority = 100 - nodeId; # Higher number wins
                    virtualIps = [
                      { addr = "${cluster.getAssignment "kube-apiserver-vip"}/${managementSubnet}"; }
                    ];
                    trackScripts = [ "check_k3s" ];
                  };
                };

                k3s =
                  let
                    # Access networks by name
                    podNetwork = cluster.networks.kubernetes-pods;
                    serviceNetwork = cluster.networks.kubernetes-services;

                    generalFlagList = [
                      "--image-service-endpoint=unix:///run/nix-snapshotter/nix-snapshotter.sock"
                      "--snapshotter=overlayfs"
                      "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"

                      "--node-ip=${builtins.head host.ipv4},${builtins.head host.ipv6}"
                      "--node-external-ip=${builtins.head host.ipv4},${builtins.head host.ipv6}"
                      "--node-name=${config.networking.hostName}"
                      "--node-label=node.longhorn.io/create-default-disk=true"
                      "--node-label=node.kubernetes.io/amd-gpu=true"

                      "--node-label \"k3s-upgrade=false\""
                      "--kubelet-arg=register-with-taints=node.cilium.io/agent-not-ready:NoExecute"
                    ];
                    serverFlagList = [
                      "--bind-address=0.0.0.0"
                      "--advertise-address=${builtins.head host.ipv4}"
                      "--cluster-cidr=${podNetwork.cidr},${podNetwork.ipv6_cidr}"
                      "--service-cidr=${serviceNetwork.cidr},${serviceNetwork.ipv6_cidr}"
                      "--kube-controller-manager-arg=--node-cidr-mask-size-ipv6=112"
                      "--kubelet-arg=fail-swap-on=false"

                      "--write-kubeconfig-mode \"0644\""
                      "--kubelet-arg=--cluster-dns=${cluster.getAssignment "coredns"}"

                      "--etcd-expose-metrics"
                      "--etcd-snapshot-schedule-cron='0 */12 * * *'"
                      "--etcd-arg=quota-backend-bytes=8589934592"
                      "--etcd-arg=max-wals=5"
                      "--etcd-arg=auto-compaction-mode=periodic"
                      "--etcd-arg=auto-compaction-retention=30m"

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

                      "--tls-san=k8s.${environment.domain}"
                      "--tls-san=${config.networking.fqdn}"
                      "--tls-san=${config.networking.hostName}"
                      "--tls-san=${config.networking.hostName}.ts.${environment.domain}"
                      "--tls-san=${builtins.head host.ipv4}"
                      "--tls-san=${cluster.getAssignment "kube-apiserver-vip"}"

                      "--kube-apiserver-arg=oidc-issuer-url=https://${environment.getDomainFor "kanidm"}/oauth2/openid/kubernetes"
                      "--kube-apiserver-arg=oidc-client-id=kubernetes"
                      "--kube-apiserver-arg=oidc-signing-algs=ES256"
                      "--kube-apiserver-arg=oidc-username-claim=email"
                      "--kube-apiserver-arg=oidc-groups-claim=groups"
                    ]
                    ++ (lib.optionals (cluster != null) (lib.map (ip: "--tls-san=${ip}") cluster.kubernetes.tlsSanIps));
                    serverFlags = builtins.concatStringsSep " " (generalFlagList ++ serverFlagList);
                  in
                  {
                    clusterInit = shouldInit;
                    enable = true;
                    role = "server";
                    tokenFile = config.age.secrets.kubernetes-cluster-token.path;
                    gracefulNodeShutdown.enable = true;
                    extraFlags = lib.mkForce serverFlags;
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

              # GitOps bootstrap
              systemd = {
                tmpfiles.rules = [
                  "d /var/lib/longhorn 0750 root root -"
                  "L+ /usr/local/bin/iscsiadm - - - - ${pkgs.openiscsi}/bin/iscsiadm"
                ];
                services = {
                  # Ensure multipathd is disabled (can conflict with Longhorn)
                  multipathd.enable = lib.mkForce false;

                  k3s-bootstrap-cilium = lib.mkIf shouldInit {
                    description = "Install Cilium for bootstrapping";
                    after = [ "k3s.service" ];
                    requires = [ "k3s.service" ];
                    path = with pkgs; [
                      kubectl
                      cilium-cli
                    ];
                    environment = {
                      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
                    };
                    serviceConfig = {
                      Type = "oneshot";
                      ExecStart = pkgs.writeShellScript "k3s-bootstrap-cilium" ''
                        set -e

                        echo "Starting k3s bootstrap process..."

                        # Wait for k3s to be fully up
                        echo "Waiting for k3s to be ready..."
                        until kubectl get nodes; do
                          echo "Waiting for k3s API server to be available..."
                          sleep 5
                        done

                        echo "k3s is ready!"

                        # Check if Cilium is already installed
                        if ${lib.getExe pkgs.cilium-cli} --kubeconfig $KUBECONFIG status >/dev/null 2>&1; then
                          echo "Cilium is already installed."
                          exit 0
                        fi

                        echo "Installing bootstrap resources..."
                        ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                          --server-side \
                          --force-conflicts \
                          -f ${manifestPath "bootstrap"} || true

                        echo "Installing cilium..."
                        ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                          --server-side \
                          --force-conflicts \
                          -f ${manifestPath "cilium"} || true
                        echo "Sleeping for 30 seconds for resources to settle..."
                        sleep 30;

                        echo "Installing coredns..."
                        ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                          --server-side \
                          --force-conflicts \
                          -f ${manifestPath "coredns"} || true
                        echo "Sleeping for 30 seconds for resources to settle..."
                        sleep 30;
                      '';
                    };
                    wantedBy = [ "multi-user.target" ];
                  };

                  k3s-install-sops-secrets-operator = lib.mkIf shouldInit {
                    description = "Install SOPS Secrets Operator for bootstrapping";
                    after = [
                      "k3s.service"
                      "k3s-bootstrap-cilium.service"
                    ];
                    requires = [
                      "k3s.service"
                      "k3s-bootstrap-cilium.service"
                    ];
                    path = with pkgs; [
                      kubectl
                    ];
                    environment = {
                      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
                    };
                    serviceConfig = {
                      Type = "oneshot";
                      ExecStart = pkgs.writeShellScript "k3s-install-sops-age-key" ''
                        set -e
                        echo "Starting k3s bootstrap process..."

                        # Wait for k3s to be fully up
                        echo "Waiting for k3s to be ready..."
                        until kubectl get nodes; do
                          echo "Waiting for k3s API server to be available..."
                          sleep 5
                        done

                        # Create namespace if it doesn't exist
                        if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get namespace sops-secrets-operator >/dev/null 2>&1; then
                          echo "Creating sops-secrets-operator namespace..."
                          ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG create namespace sops-secrets-operator
                        fi

                        # Check if secret is already installed
                        if ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG --namespace sops-secrets-operator get secret sops-age-key-file >/dev/null 2>&1; then
                          echo "SOPS secret age key is already installed."
                        else
                          echo "Creating SOPS age key secret..."
                          ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG create secret generic sops-age-key-file \
                            --namespace sops-secrets-operator \
                            --from-file=key=${config.age.secrets.kubernetes-sops-age-key.path}
                        fi

                        # Install sops-secrets-operator if deployment doesn't exist
                        if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get deployment -n sops-secrets-operator sops-sops-secrets-operator >/dev/null 2>&1; then
                          echo "Installing sops-secrets-operator..."
                          ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                            --server-side \
                            --force-conflicts \
                            -f ${manifestPath "sops-secrets-operator"}
                          echo "Sleeping for 30 seconds..."
                          sleep 30
                        fi

                        # Install cert-manager if deployment doesn't exist
                        if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get deployment -n cert-manager cert-manager >/dev/null 2>&1; then
                          echo "Installing cert-manager..."
                          ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                            --server-side \
                            --force-conflicts \
                            -f ${manifestPath "cert-manager"}
                          echo "Sleeping for 30 seconds..."
                          sleep 30
                        fi
                      '';
                    };
                    wantedBy = [ "multi-user.target" ];
                  };

                  k3s-install-argocd = lib.mkIf shouldInit {
                    description = "Install ArgoCD for bootstrapping";
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
                    path = with pkgs; [
                      kubectl
                    ];
                    environment = {
                      KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";
                    };
                    serviceConfig = {
                      Type = "oneshot";
                      ExecStart = pkgs.writeShellScript "k3s-install-argocd" ''
                        set -e
                        echo "Starting ArgoCD installation..."

                        # Wait for k3s to be fully up
                        echo "Waiting for k3s to be ready..."
                        until kubectl get nodes; do
                          echo "Waiting for k3s API server to be available..."
                          sleep 5
                        done

                        # Create namespace if it doesn't exist
                        if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get namespace argocd >/dev/null 2>&1; then
                          echo "Creating argocd namespace..."
                          ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG create namespace argocd
                        fi

                        # Install ArgoCD if deployment doesn't exist
                        if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get deployment -n argocd argocd-server >/dev/null 2>&1; then
                          echo "Installing ArgoCD..."
                          ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                            --server-side \
                            --force-conflicts \
                            -f ${manifestPath "argocd"}
                          echo "Installing App bootstrap.yaml"
                          ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                            -f ${manifestPath "bootstrap.yaml"}
                        else
                          echo "ArgoCD is already installed."
                        fi
                      '';
                    };
                    wantedBy = [ "multi-user.target" ];
                  };
                };
              };
            };
        }
      );

      secrets = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
          cluster = host.cluster or null;
          kubernetesNodes = environment.findHostsByFeature "k3s";
          shouldInit = (builtins.length (lib.attrValues kubernetesNodes)) == 1;
        in
        lib.mkIf (cluster != null) {
          secrets = {
            kubernetes-cluster-token = {
              rekeyFile = cluster.secretPath + "/cluster-token.age";
              generator.script = "passphrase";
            };
          }
          // lib.optionalAttrs shouldInit {
            kubernetes-sops-age-key = {
              rekeyFile = cluster.secretPath + "/cluster-sops-age-key.age";
              path = "/var/lib/sops/age/key.txt";
            };
          };
        }
      );

      impermanence = den.lib.perHost {
        persist.directories = [
          "/var/lib/rancher"
          "/var/lib/kubelet"
          "/etc/rancher"
        ];
      };
    };
  };
}
