{
  rootPath,
  config,
  ...
}:
let
  # Get hosts from the flake config
  hosts = config.flake.hosts;
  # Helper function to find master nodes in the same cluster
  findClusterMaster =
    kubernetesCluster: hosts: lib:
    let
      clusterHosts = lib.attrsets.filterAttrs (
        hostname: hostConfig:
        hostConfig.tags ? "kubernetes-cluster" && hostConfig.tags."kubernetes-cluster" == kubernetesCluster
      ) hosts;

      masterHosts = lib.attrsets.filterAttrs (
        hostname: hostConfig: builtins.elem "kubernetes-master" (hostConfig.roles or [ ])
      ) clusterHosts;
    in
    if lib.length (lib.attrNames masterHosts) > 0 then
      let
        masterHost = lib.head (lib.attrValues masterHosts);
      in
      masterHost.tags.kubernetes-internal-ip or masterHost.ipv4
    else
      null;

  # Original commented logic for reference:
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
      role = if isMaster then "server" else "agent";
      clusterInit = isMaster;
      internalIP = hostOptions.tags.kubernetes-internal-ip or hostOptions.ipv4;
      externalIP = hostOptions.ipv4;

      # Find master node for agent connection (using hosts from outer scope)
      masterIP = findClusterMaster kubernetesCluster hosts lib;
    in
    {
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

      # TODO: Enable proper firewall configuration
      # Required ports: 6443 (API), 2379/2380 (etcd), 8472 (CNI)

      services = {
        nix-snapshotter.enable = true;
        k3s =
          let
            generalFlagList = [
              "--image-service-endpoint=unix:///run/nix-snapshotter/nix-snapshotter.sock"
              "--snapshotter=overlayfs"
              "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
              "--node-ip=${internalIP}"
              "--node-external-ip=${externalIP}"
              "--node-label=node.longhorn.io/create-default-disk=true"
              # CoreDNS doesn't like systemd-resolved's /etc/resolv.conf
              "--resolv-conf=/run/systemd/resolve/resolv.conf"
            ];
            serverFlagList = [
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
              "--tls-san=${externalIP}"
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
            inherit role;
            enable = true;
            tokenFile = config.age.secrets.kubernetes-cluster-token.path;
            #gracefulNodeShutdown.enable = true;
            extraFlags = lib.mkForce (if (role == "server") then serverFlags else generalFlags);
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
    };
}
