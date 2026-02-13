{
  rootPath,
  config,
  ...
}:
let
  # Get hosts from the flake config
  hosts = config.flake.hosts;
  # Helper function to find master nodes in the same cluster and environment
  findClusterMaster =
    currentHostEnvironment: hosts: lib:
    let
      masterHosts =
        hosts
        |> lib.attrsets.filterAttrs (
          hostname: hostConfig:
          (builtins.elem "kubernetes" (hostConfig.roles or [ ]))
          && (hostConfig.environment == currentHostEnvironment)
        )
        |> lib.attrsets.filterAttrs (
          hostname: hostConfig: builtins.elem "kubernetes-master" (hostConfig.roles or [ ])
        );
    in
    if lib.length (lib.attrNames masterHosts) > 0 then
      let
        masterHost = lib.head (lib.attrValues masterHosts);
      in
      masterHost.tags.kubernetes-internal-ip or (builtins.head masterHost.ipv4)
    else
      null;
in
{
  flake.features.kubernetes = {
    requires = [ "containerd" ];
    nixos =
      {
        lib,
        pkgs,
        config,
        hostOptions,
        environment,
        ...
      }:
      let
        currentHostEnvironment = hostOptions.environment;
        isMaster = builtins.elem "kubernetes-master" hostOptions.roles;
        clusterInit = isMaster;
        internalIP = hostOptions.tags.kubernetes-internal-ip or (builtins.head hostOptions.ipv4);
        externalIP = builtins.head hostOptions.ipv4;

        # Find master node for agent connection (using hosts from outer scope)
        masterIP = findClusterMaster currentHostEnvironment hosts lib;
      in
      {
        age.secrets.kubernetes-cluster-token = {
          rekeyFile = rootPath + "/.secrets/env/${environment.name}/k3s-token.age";
        };

        age.secrets.kubernetes-sops-age-key = lib.mkIf isMaster {
          rekeyFile = rootPath + "/.secrets/env/${environment.name}/k3s-sops-age-key.age";
          path = "/var/lib/sops/age/key.txt";
        };

        # age.secrets.kubernetes-oidc-secret = {
        #   rekeyFile = rootPath + "/.secrets/env/${environment.name}/oidc/kubernetes-oidc-client-secret.age";
        #   intermediary = true;
        # };
        # age.secrets.kubernetes-oidc-env = {
        #   generator.dependencies = [ config.age.secrets.kubernetes-oidc-secret ];
        #   generator.script = (
        #     {
        #       lib,
        #       decrypt,
        #       deps,
        #       ...
        #     }:
        #     ''
        #       echo -n "OIDC_CLIENT_SECRET="
        #       ${decrypt} ${lib.escapeShellArg (lib.head deps).file}
        #     ''
        #   );
        # };

        # systemd.services.k3s = {
        #   serviceConfig.EnvironmentFile = config.age.secrets.kubernetes-oidc-secret.path;
        # };

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
          go-containerregistry # provides `crane` & `gcrane`, it's similar to skopeo
          dive # explore docker layers

          openiscsi # Required for Longhorn
          nfs-utils # Required for Longhorn

          # Filesystem tools
          ceph
          ceph-client
          util-linux
          parted
          gptfdisk
          lvm2
        ];

        # Kernel modules required by k3s
        boot.kernelModules = [
          # Filesystem support:
          "ceph"
          "rbd"
          "nfs"
          # Networking support:
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
        ];

        # Blacklist nbd module to prevent ceph-volume from hanging when scanning devices
        # nbd devices cause ceph-bluestore-tool show-label to hang indefinitely
        boot.blacklistedKernelModules = [ "nbd" ];

        networking = {
          nat = {
            enable = true;
            enableIPv6 = true;
          };

          firewall = {
            # For debug, disable firewall...
            enable = lib.mkForce false;

            # enable = lib.mkForce false;
            allowedTCPPorts = lib.flatten [
              6443 # Kubernetes API
              6444

              10250 # Kubelet metrics
              2379 # etcd
              2380 # etcd
              4240 # clilum healthcheck
              4244 # hubble api
              8080
              443
            ];

            allowedUDPPorts = [
              8472 # Cilium VXLAN
              4789 # Cilium VXLAN fallback
            ];

            trustedInterfaces = [
              "lo"
              "cni+"
              "flannel.1"
              "calico+"
              "cilium+"
              "lxc+"
              "dummy+"
              # These are our thunderbolt mesh interfaces, trust them
              "enp199s0f5"
              "enp199s0f6"
            ];

            # Critical: Allow packet forwarding for Kubernetes networking
            extraCommands = ''
              # Allow forwarding for pod and service networks
              iptables -A FORWARD -s ${environment.kubernetes.clusterCidr} -j ACCEPT  # Default k3s pod CIDR
              iptables -A FORWARD -d ${environment.kubernetes.clusterCidr} -j ACCEPT
              iptables -A FORWARD -s ${environment.kubernetes.serviceCidr} -j ACCEPT  # Default k3s service CIDR
              iptables -A FORWARD -d ${environment.kubernetes.serviceCidr} -j ACCEPT

              iptables -A FORWARD -s ${environment.kubernetes.internalMeshCidr} -j ACCEPT  # Default k3s pod CIDR
              iptables -A FORWARD -d ${environment.kubernetes.internalMeshCidr} -j ACCEPT

              # Allow pods to reach API server through service IP
              iptables -A INPUT -s ${environment.kubernetes.clusterCidr} -d ${environment.kubernetes.serviceCidr} -j ACCEPT
              iptables -A OUTPUT -s ${environment.kubernetes.clusterCidr} -d ${environment.kubernetes.serviceCidr} -j ACCEPT

              iptables -A INPUT -s ${environment.kubernetes.serviceCidr} -d ${environment.kubernetes.internalMeshCidr} -j ACCEPT
              iptables -A OUTPUT -s ${environment.kubernetes.serviceCidr} -d ${environment.kubernetes.internalMeshCidr} -j ACCEPT

              iptables -A INPUT -s ${environment.kubernetes.clusterCidr} -d ${environment.kubernetes.internalMeshCidr} -j ACCEPT
              iptables -A OUTPUT -s ${environment.kubernetes.clusterCidr} -d ${environment.kubernetes.internalMeshCidr} -j ACCEPT

              # Allow established connections
              iptables -A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

              # Allow ICMP for health checks
              iptables -A INPUT -p icmp --icmp-type echo-request -s ${environment.kubernetes.clusterCidr} -j ACCEPT
              iptables -A INPUT -p icmp --icmp-type echo-reply -s ${environment.kubernetes.clusterCidr} -j ACCEPT

              iptables -A INPUT -p icmp --icmp-type echo-request -s ${environment.kubernetes.internalMeshCidr} -j ACCEPT
              iptables -A INPUT -p icmp --icmp-type echo-reply -s ${environment.kubernetes.internalMeshCidr} -j ACCEPT

            '';

            # Clean up custom rules when firewall stops
            extraStopCommands = ''
              iptables -D FORWARD -s ${environment.kubernetes.clusterCidr} -j ACCEPT 2>/dev/null || true
              iptables -D FORWARD -d ${environment.kubernetes.clusterCidr} -j ACCEPT 2>/dev/null || true
              iptables -D FORWARD -s ${environment.kubernetes.serviceCidr} -j ACCEPT 2>/dev/null || true
              iptables -D FORWARD -d ${environment.kubernetes.serviceCidr} -j ACCEPT 2>/dev/null || true
            '';
          };
        };

        services = {

          k3s =
            let
              generalFlagList = [
                "--image-service-endpoint=unix:///run/nix-snapshotter/nix-snapshotter.sock"
                "--snapshotter=overlayfs"
                "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"

                "--node-ip=${internalIP}"
                "--node-external-ip=${internalIP}"
                "--node-name=${config.networking.hostName}"
                "--node-label=node.longhorn.io/create-default-disk=true"
                # CoreDNS doesn't like systemd-resolved's /etc/resolv.conf
                "--resolv-conf=/run/systemd/resolve/resolv.conf"

                "--node-label \"k3s-upgrade=false\""
                "--kubelet-arg=register-with-taints=node.cilium.io/agent-not-ready:NoExecute"
              ];
              serverFlagList = [
                "--bind-address=0.0.0.0"
                "--advertise-address=${internalIP}"
                "--cluster-cidr=${environment.kubernetes.clusterCidr}"
                "--service-cidr=${environment.kubernetes.serviceCidr}"
                "--cluster-domain k8s.${environment.domain}"

                "--kubelet-arg=fail-swap-on=false"

                "--write-kubeconfig-mode \"0644\""

                "--etcd-expose-metrics"
                "--etcd-snapshot-schedule-cron='0 */12 * * *'"
                "--etcd-arg=quota-backend-bytes=8589934592"
                "--etcd-arg=max-wals=5"
                "--etcd-arg=auto-compaction-mode=periodic"
                "--etcd-arg=auto-compaction-retention=30m"

                "--disable local-storage"
                "--disable metrics-server"
                "--disable traefik"

                # "--disable coredns"

                "--disable servicelb" # Cilium
                "--flannel-backend=none" # Cilium
                "--disable-network-policy" # Cilium
                "--disable-kube-proxy" # Cilium will handle this
                "--disable-cloud-controller"
                "--disable-helm-controller"

                "--tls-san=k8s.${config.networking.domain}"
                "--tls-san=${config.networking.fqdn}"
                "--tls-san=${config.networking.hostName}"
                "--tls-san=${externalIP}"

                "--kube-apiserver-arg=oidc-issuer-url=https://idm.${config.networking.domain}/oauth2/openid/kubernetes"
                "--kube-apiserver-arg=oidc-client-id=kubernetes"
                "--kube-apiserver-arg=oidc-signing-algs=ES256"
                "--kube-apiserver-arg=oidc-username-claim=email"
                "--kube-apiserver-arg=oidc-groups-claim=groups"
                ## "--kube-apiserver-arg=oidc-client-secret=\${OIDC_CLIENT_SECRET}"
              ]
              ++ (lib.map (ip: "--tls-san=${ip}") environment.kubernetes.tlsSanIps);
              serverFlags = builtins.concatStringsSep " " (generalFlagList ++ serverFlagList);
            in
            {
              inherit clusterInit;
              enable = true;
              role = "server";
              tokenFile = config.age.secrets.kubernetes-cluster-token.path;
              gracefulNodeShutdown.enable = true;
              extraFlags = lib.mkForce serverFlags;
            }
            // lib.optionalAttrs (!isMaster && masterIP != null) {
              serverAddr = "https://${masterIP}:6443";
            };

          # Required for Longhorn
          openiscsi = {
            enable = true;
            name = "iqn.2016-04.com.open-iscsi:${config.networking.fqdn}";
          };
        };

        # GitOps bootstrap
        systemd.services.k3s-bootstrap-cilium = lib.mkIf isMaster {
          description = "Install Cilium for bootstrapping";
          after = [ "k3s.service" ];
          requires = [ "k3s.service" ];
          path = with pkgs; [
            kubectl
            # kubernetes-helm
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

              echo "Adding helm repo for cilium..."

              ${lib.getExe pkgs.kubernetes-helm} --kubeconfig $KUBECONFIG repo add cilium https://helm.cilium.io/

              echo "Installing cilium..."
              ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                -n kube-system \
                --server-side \
                --force-conflicts \
                -f ${rootPath + "/kubernetes/generated/manifests/${environment.name}/cilium/"}
            '';
          };
          wantedBy = [ "multi-user.target" ];
        };

        systemd.services.k3s-install-sops-age-key = lib.mkIf isMaster {
          description = "Install Cilium for bootstrapping";
          after = [ "k3s.service" ];
          requires = [ "k3s.service" ];
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

              # Check if secret is already installed
              if ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG --namespace sops-secrets-operator get secret sops-age-key-file >/dev/null 2>&1; then
                echo "SOPS secret age key is already installed."
                exit 0
              fi

              ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG create secret generic sops-age-key-file \
                --namespace sops-secrets-operator \
                --from-file=key=${config.age.secrets.kubernetes-sops-age-key.path}
            '';
          };
          wantedBy = [ "multi-user.target" ];
        };

        environment.persistence."/persist".directories = [
          "/var/lib/rancher"
          "/var/lib/kubelet"
          "/etc/rancher"
        ];
      };
  };
}
