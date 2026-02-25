{
  self,
  rootPath,
  ...
}:
let
  inherit (self.lib.kubernetes-utils) findKubernetesNodes;
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

        managementSubnet = "/${lib.last (lib.splitString "/" environment.networks.management.cidr)}";

        kubernetesNodes = findKubernetesNodes environment;

        # Sort kubernetes nodes by hostname for deterministic ordering
        sortedKubernetesNodes = builtins.sort (a: b: a.hostname < b.hostname) (
          lib.attrValues kubernetesNodes
        );

        # Extract server IPs from sorted nodes

        # Get current node's index in the sorted list
        nodeId = lib.lists.findFirstIndex (
          node: node.hostname == config.networking.hostName
        ) null sortedKubernetesNodes;

        # Initialize if there is only one kubernetes node -- the cluster is bootstrapping
        shouldInit = (builtins.length (lib.attrValues kubernetesNodes)) == 1;

        # Find master node for agent connection (using hosts from outer scope)
        # masterIP = findClusterMaster environment;
        masterIP = environment.kubernetes.kubeAPIVIP;
      in
      {
        age.secrets.kubernetes-cluster-token = {
          rekeyFile = rootPath + "/.secrets/env/${environment.name}/k3s-token.age";
        };

        age.secrets.kubernetes-sops-age-key = lib.mkIf shouldInit {
          rekeyFile = rootPath + "/.secrets/env/${environment.name}/k3s-sops-age-key.age";
          path = "/var/lib/sops/age/key.txt";
        };

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
        ];

        # Enable eBPF
        boot.kernel.sysctl = {
          # These are set in server, don't feel like lib.mkDefaulting them...
          # "net.ipv4.ip_forward" = 1;
          # "net.ipv4.conf.all.forwarding" = 1;
          # "net.ipv6.conf.all.forwarding" = 1;
          "net.bridge.bridge-nf-call-iptables" = 1;
          "net.bridge.bridge-nf-call-ip6tables" = 1;
          "net.core.bpf_jit_enable" = 1;
          "net.core.bpf_jit_harden" = 0;
        };

        # Blacklist nbd module to prevent ceph-volume from hanging when scanning devices
        # nbd devices cause ceph-bluestore-tool show-label to hang indefinitely
        boot.blacklistedKernelModules = [ "nbd" ];

        networking = {
          firewall = {
            # For debug, disable firewall...
            enable = lib.mkForce false;

            # enable = lib.mkForce false;
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
              # These are our thunderbolt mesh interfaces, trust them
              "enp199s0f5"
              "enp199s0f6"
            ];
          };
        };

        services = {
          # 1. HAProxy: Routes traffic from port 6443 to the actual k3s API
          # haproxy = {
          #   enable = true;
          #   config = ''
          #     frontend k3s-frontend
          #       bind *:6443
          #       mode tcp
          #       option tcplog
          #       default_backend k3s-backend

          #     backend k3s-backend
          #       mode tcp
          #       option tcp-check
          #       balance roundrobin
          #       ${lib.concatStringsSep "\n" (map (ip: "server node-${ip} ${ip}:6444 check") serverIps)}
          #   '';
          # };

          keepalived = {
            enable = true;
            vrrpInstances.k3s = {
              state = if (nodeId == 0) then "MASTER" else "BACKUP";
              interface = "br0"; # We use br0 cause we're cool like that...
              virtualRouterId = 51;
              priority = 100 - nodeId; # Higher number wins (e.g., 101 on MASTER)
              virtualIps = [ { addr = "${environment.kubernetes.kubeAPIVIP}/${managementSubnet}"; } ]; # Our networks are all /16...
            };
          };

          k3s =
            let
              generalFlagList = [
                "--image-service-endpoint=unix:///run/nix-snapshotter/nix-snapshotter.sock"
                "--snapshotter=overlayfs"
                "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"

                "--node-ip=${builtins.head hostOptions.ipv4}"
                "--node-external-ip=${builtins.head hostOptions.ipv4}"
                "--node-name=${config.networking.hostName}"
                # TODO: If longhorn disk enabled...
                "--node-label=node.longhorn.io/create-default-disk=true"
                # CoreDNS doesn't like systemd-resolved's /etc/resolv.conf
                "--resolv-conf=/run/systemd/resolve/resolv.conf"

                "--node-label \"k3s-upgrade=false\""
                "--kubelet-arg=register-with-taints=node.cilium.io/agent-not-ready:NoExecute"
              ];
              serverFlagList = [
                "--bind-address=0.0.0.0"
                "--advertise-address=${builtins.head hostOptions.ipv4}"
                "--cluster-cidr=${environment.kubernetes.clusterCidr}"
                "--service-cidr=${environment.kubernetes.serviceCidr}"

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

                "--tls-san=k8s.${environment.domain}"
                "--tls-san=${config.networking.fqdn}"
                "--tls-san=${config.networking.hostName}"
                "--tls-san=${config.networking.hostName}.ts.${environment.domain}"
                "--tls-san=${builtins.head hostOptions.ipv4}"
                "--tls-san=${environment.kubernetes.kubeAPIVIP}"

                "--kube-apiserver-arg=oidc-issuer-url=https://idm.${environment.domain}/oauth2/openid/kubernetes"
                "--kube-apiserver-arg=oidc-client-id=kubernetes"
                "--kube-apiserver-arg=oidc-signing-algs=ES256"
                "--kube-apiserver-arg=oidc-username-claim=email"
                "--kube-apiserver-arg=oidc-groups-claim=groups"
              ]
              ++ (lib.map (ip: "--tls-san=${ip}") environment.kubernetes.tlsSanIps);
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
        systemd.services.k3s-bootstrap-cilium = lib.mkIf shouldInit {
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

              echo "Installing bootstrap resources..."
              ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                --server-side \
                --force-conflicts \
                -f ${rootPath + "/kubernetes/generated/manifests/${environment.name}/bootstrap/"} || true

              echo "Installing cilium..."
              ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                --server-side \
                --force-conflicts \
                -f ${rootPath + "/kubernetes/generated/manifests/${environment.name}/cilium/"} || true
              echo "Sleeping for 30 seconds for resources to settle..."
              sleep 30;
            '';
          };
          wantedBy = [ "multi-user.target" ];
        };

        systemd.services.k3s-install-sops-secrets-operator = lib.mkIf shouldInit {
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
                  -f ${rootPath + "/kubernetes/generated/manifests/${environment.name}/sops-secrets-operator/"}
                echo "Sleeping for 30 seconds..."
                sleep 30
              fi

              # Install cert-manager if deployment doesn't exist
              if ! ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG get deployment -n cert-manager cert-manager >/dev/null 2>&1; then
                echo "Installing cert-manager..."
                ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                  --server-side \
                  --force-conflicts \
                  -f ${rootPath + "/kubernetes/generated/manifests/${environment.name}/cert-manager/"}
                echo "Sleeping for 30 seconds..."
                sleep 30
              fi
            '';
          };
          wantedBy = [ "multi-user.target" ];
        };

        systemd.services.k3s-install-argocd = lib.mkIf shouldInit {
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
                  -f ${rootPath + "/kubernetes/generated/manifests/${environment.name}/argocd/"}
                echo "Installing App bootstrap.yaml"
                ${lib.getExe pkgs.kubectl} --kubeconfig $KUBECONFIG apply \
                  -f ${rootPath + "/kubernetes/generated/manifests/${environment.name}/bootstrap.yaml"}
              else
                echo "ArgoCD is already installed."
              fi
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
