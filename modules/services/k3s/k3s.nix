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

        # age.secrets.kubernetes-oidc-secret = {
        #   rekeyFile = rootPath + "/.secrets/services/kubernetes-oidc-client-secret.age";
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
        ];

        # Kernel modules required by cilium
        boot.kernelModules = [
          "ip6_tables"
          "ip6table_mangle"
          "ip6table_raw"
          "ip6table_filter"
        ];

        networking = {
          firewall = {
            # For debug, disable firewall...
            enable = lib.mkForce false;

            # enable = lib.mkForce false;
            allowedTCPPorts = lib.flatten [
              6443 # Kubernetes API
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
              ];
              serverFlagList = [
                "--bind-address=0.0.0.0"
                "--cluster-cidr=${environment.kubernetes.clusterCidr}"
                "--service-cidr=${environment.kubernetes.serviceCidr}"
                "--cluster-domain k8s.${environment.domain}"

                "--kubelet-arg=fail-swap-on=false"

                "--write-kubeconfig-mode \"0644\""
                "--etcd-expose-metrics"

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

              # autoDeployCharts =
              #   let
              #     cilium = pkgs.runCommand "helm-template" { allowSubstitution = false; } ''
              #       mkdir -p "$out"
              #       ${pkgs.kubernetes-helm}/bin/helm template cilium ${pkgs.inputs.cilium-chart} \
              #         --namespace kube-system \
              #         --set kubeProxyReplacement=true \
              #         --set k8sServiceHost=192.168.123.101 \
              #         --set k8sServicePort=6443 \
              #         --set enableExternalIPs=true \
              #         --set enableHostPort=true \
              #         --set enableNodePort=true \
              #         --set ipam.operator.clusterPoolIPv4PodCIDRList=${settings.cluster-cidr} \
              #         --set ipv4NativeRoutingCIDR=${settings.cluster-cidr} \
              #         --set routingMode=native \
              #         --set autoDirectNodeRoutes=true \
              #         --set devices='{enp199s0f5,enp199s0f6}' \
              #         --set bpf.masquerade=true \
              #         --set endpointRoutes.enabled=true \
              #         --set autoDirectNodeRoute=true \
              #         --set encryption.enabled=true\
              #         --set encryption.type=wireguard \
              #         --set encryption.nodeEncryption=true > "$out"/cilium.yaml
              #     '';
              #   in
              #   {
              #     flux = "${pkgs.fluxcd-yaml}/flux.yaml";
              #     cilium = "${cilium}/cilium.yaml";
              #   };
              # Based on: https://github.com/CallumTarttelin/dotfiles/blob/b8c4dfef47b826652620266c1dc52eb825626424/modules/k3s.nix#L42
              autoDeployCharts = {
                cilium = {
                  enable = true;

                  name = "cilium";
                  repo = "https://helm.cilium.io/";
                  version = "1.18.6";
                  hash = "sha256-+yr38lc5X1+eXCFE/rq/K0m4g/IiNFJHuhB+Nu24eUs=";

                  targetNamespace = "kube-system";

                  values = {
                    kubeProxyReplacement = true;
                    # routingMode = "native";
                    # bpf.masquerade = true;
                    # ipam.mode = "cluster-pool";

                    # bandwidthManager.enabled = true;
                    # bandwidthManager.bbr = true;

                    # CNI chaining
                    cni.chainingMode = "portmap";

                    # IPAM & Pod CIDRs
                    ipam = {
                      mode = "cluster-pool";
                      operator.clusterPoolIPv4PodCIDRList = [ "172.20.0.0/16" ];
                    };

                    # Routing Mode
                    routingMode = "tunnel";
                    tunnelProtocol = "geneve";

                    # Masquerading (SNAT) behavior
                    enableIPv4 = true;
                    enableIpMasqAgent = false;
                    enableIPv4Masquerade = true;
                    nonMasqueradeCIDRs = "{10.0.0.0/8,172.16.0.0/12,192.168.0.0/16}";
                    masqLinkLocal = false;

                    devices = [
                      "dummy0"
                      "enp2s0"
                      "enp199s0f5"
                      "enp199s0f6"
                    ];

                    policyEnforcementMode = "always";
                    encryption = {
                      enabled = true;
                      type = "wireguard";
                    };

                    hubble = {
                      relay.enabled = true;
                      ui.enabled = true;
                      metrics.enabled = [
                        "dns"
                        "drop"
                        "tcp"
                        "flow"
                        "port-distribution"
                        "icmp"
                        "http"
                      ];
                    };
                  };

                  extraFieldDefinitions = {
                    spec = {
                      repo = "https://helm.cilium.io/";
                      chart = "cilium";
                      version = "1.18.6";
                      bootstrap = true;
                    };
                  };

                  # extraDeploy = [
                  #   {
                  #     apiVersion = "cilium.io/v2";
                  #     kind = "CiliumLoadBalancerIPPool";
                  #     metadata = {
                  #       name = "all";
                  #     };
                  #     spec = {
                  #       blocks = [
                  #         {
                  #           start = "10.11.0.1";
                  #           stop = "10.11.0.255";
                  #         }
                  #       ];
                  #     };
                  #   }
                  #   {
                  #     apiVersion = "cilium.io/v2alpha1";
                  #     kind = "CiliumL2AnnouncementPolicy";
                  #     metadata = {
                  #       name = "policy-all";
                  #     };
                  #     spec = {
                  #       interfaces = [
                  #         "^ens[0-9]+"
                  #         "enp0s[0-9]+"
                  #         "enp199s0f5"
                  #         "enp199s0f6"
                  #       ];
                  #       externalIPs = true;
                  #       loadBalancerIPs = true;
                  #     };
                  #   }
                  # ];
                };
              };
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

        environment.persistence."/persist".directories = [
          "/var/lib/rancher"
          "/var/lib/kubelet"
          "/etc/rancher"
        ];
      };
  };
}
