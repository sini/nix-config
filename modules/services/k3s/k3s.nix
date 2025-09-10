{
  rootPath,
  ...
}:
let
  # hosts = config.flake.hosts;
  # kubernetesMasterMap = builtins.listToAttrs (
  #   map
  #     (
  #       { name, value }:
  #       {
  #         name = value.tags."kubernetes-cluster";
  #         value = name;
  #       }
  #     )
  #     (
  #       lib.filter (
  #         host:
  #         builtins.elem "kubernetes-master" (host.value.roles or [ ])
  #         && host.value.tags ? "kubernetes-cluster"
  #       ) (lib.attrsToList hosts)
  #     )
  # );
in
{
  flake.modules.nixos.kubernetes =
    {
      lib,
      pkgs,
      config,
      hostOptions,
      ...
    }:
    let
      kubernetesCluster = hostOptions.kubernetes-cluster or "dev";
      isMaster = builtins.elem "kubernetes-master" hostOptions.roles;
      role = "server"; # if isMaster then "server" else "agent";
      clusterInit = isMaster;
      cfg = config.k3s;
    in
    {
      options.k3s = {
        ipv4 = lib.mkOption {
          type = lib.types.str;
          example = "172.16.255.1";
        };
        neighbor = lib.mkOption {
          type = lib.types.str;
          default = "172.16.255.1";
        };
      };

      config = {
        age.secrets.kubernetes-cluster-token = {
          rekeyFile = rootPath + "/.secrets/k3s/${kubernetesCluster}/k3s-token.age";
        };

        environment.systemPackages = with pkgs; [
          k3s
          k9s
          kubectl
          istioctl
          kubernetes-helm
          cilium-cli
          fluxcd
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
          enableIPv6 = true;
          nat = {
            enable = true;
            enableIPv6 = true;
          };
          nftables.enable = lib.mkForce false;
          firewall.enable = lib.mkForce false;
        };

        # TODO: Enable Firewall...
        # networking = {
        #   nftables.enable = lib.mkForce false;
        #   firewall = {
        #     enable = lib.mkForce false;
        #     firewall.allowedTCPPorts = [
        #       6443 # k3s: required so that pods can reach the API server (running on port 6443 by default)
        #       2379 # k3s, etcd clients: required if using a "High Availability Embedded etcd" configuration
        #       2380 # k3s, etcd peers: required if using a "High Availability Embedded etcd" configuration
        #     ];
        #     firewall.allowedUDPPorts = [
        #       8472 # k3s, flannel: required if using multi-node for inter-node networking
        #     ];
        #   };
        # TODO Explore: networking.firewall.trustedInterfaces
        # };

        services = {
          nix-snapshotter.enable = true;
          k3s =
            let
              generalFlagList = [
                "--image-service-endpoint=unix:///run/nix-snapshotter/nix-snapshotter.sock"
                "--snapshotter=overlayfs"
                "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
                "--node-ip=${cfg.ipv4}"
                "--node-external-ip=${cfg.ipv4}"
                "--node-label=node.longhorn.io/create-default-disk=true"
                # CoreDNS doesn't like systemd-resolved's /etc/resolv.conf
                "--resolv-conf=/run/systemd/resolve/resolv.conf"
              ];
              serverFlagList = [
                # "--node-ip=${hostOptions.ipv4},fe80::5a47:caff:fe79:e8e2"
                # "--node-external-ip=${hostOptions.ipv4},fe80::5a47:caff:fe79:e8e2"
                # "--cluster-cidr=10.42.0.0/16,2001:cafe:42::/56"
                # "--service-cidr=10.43.0.0/16,2001:cafe:43::/112"
                #"--cluster-cidr=10.42.0.0/16"
                #"--service-cidr=10.43.0.0/16"
                "--bind-address=0.0.0.0"
                "--cluster-cidr=172.20.0.0/16"
                "--service-cidr=172.21.0.0/16"

                "--write-kubeconfig-mode \"0644\""
                "--etcd-expose-metrics"
                "--disable-helm-controller"

                "--disable local-storage"
                "--disable metrics-server"
                "--disable traefik"

                "--disable servicelb" # Cilium
                "--flannel-backend=none" # Cilium
                "--disable-network-policy" # Cilium
                "--disable-kube-proxy" # Cilium will handle this
                "--disable-cloud-controller"

                "--tls-san=${config.networking.fqdn}"
                "--tls-san=${config.networking.hostName}"
                #"--tls-san=${cfg.ipv4}"
                "--tls-san=10.10.10.2"
                "--tls-san=10.10.10.3"
                "--tls-san=10.10.10.4"
                "--tls-san=172.16.255.1"
                "--tls-san=172.16.255.2"
                "--tls-san=172.16.255.3"

              ];
              generalFlags = builtins.concatStringsSep " " generalFlagList;
              serverFlags = builtins.concatStringsSep " " (generalFlagList ++ serverFlagList);
            in
            {
              inherit clusterInit;
              role = "server";
              enable = true;
              tokenFile = config.age.secrets.kubernetes-cluster-token.path;
              #gracefulNodeShutdown.enable = true;
              extraFlags = lib.mkForce (if (role == "server") then serverFlags else generalFlags);
            }
            // lib.optionalAttrs (!isMaster) {
              serverAddr =
                # let
                #   address = kubernetesMasterMap.${kubernetesCluster};
                # in
                "https://${cfg.neighbor}:6443";
            };

          # Required for Longhorn
          openiscsi = {
            enable = true;
            name = "iqn.2016-04.com.open-iscsi:${config.networking.fqdn}";
          };
        };
      };
    };
}
