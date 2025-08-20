{
  config,
  lib,
  rootPath,
  ...
}:
let
  hosts = config.flake.hosts;
  kubernetesMasterMap = builtins.listToAttrs (
    map
      (
        { name, value }:
        {
          name = value.tags."kubernetes-cluster";
          value = name;
        }
      )
      (
        lib.filter (
          host:
          builtins.elem "kubernetes-master" (host.value.roles or [ ])
          && host.value.tags ? "kubernetes-cluster"
        ) (lib.attrsToList hosts)
      )
  );
in
{
  flake.modules.nixos.kubernetes =
    {
      inputs,
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
    in
    {
      imports = [ inputs.nix-snapshotter.nixosModules.default ];
      nixpkgs.overlays = [ inputs.nix-snapshotter.overlays.default ];
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

      virtualisation.containerd = {
        enable = true;
        nixSnapshotterIntegration = true;
        k3sIntegration = true;
      };

      services = {
        nix-snapshotter.enable = true;
        k3s =
          let
            serverFlagList = [
              # "--image-service-endpoint=unix:///run/nix-snapshotter/nix-snapshotter.sock"
              # "--snapshotter=overlayfs"
              # "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
              "--node-ip=10.10.10.2,fe80::5a47:caff:fe79:e8e2"
              "--node-external-ip=10.10.10.2,fe80::5a47:caff:fe79:e8e2"
              "--write-kubeconfig-mode \"0644\""
              "--disable local-storage"
              "--disable metrics-server"
              "--disable traefik"
              "--disable servicelb"
              "--flannel-backend=none"
              "--disable-network-policy"
              "--disable-helm-controller"
              "--disable-kube-proxy"
              "--etcd-expose-metrics"
              "--tls-san=${config.networking.fqdn}"
              "--cluster-cidr=10.42.0.0/16,2001:cafe:42::/56"
              "--service-cidr=10.43.0.0/16,2001:cafe:43::/112"
            ];
            serverFlags = builtins.concatStringsSep " " serverFlagList;
          in
          {
            inherit role clusterInit;
            enable = true;
            tokenFile = config.age.secrets.kubernetes-cluster-token.path;
            gracefulNodeShutdown.enable = true;
            extraFlags = lib.mkIf (role == "server") (lib.mkForce serverFlags);
          }
          // lib.optionalAttrs (!isMaster) {
            serverAddr = kubernetesMasterMap.${kubernetesCluster};
          };

        # Required for Longhorn
        openiscsi = {
          enable = true;
          name = "iqn.2016-04.com.open-iscsi:${config.networking.fqdn}";
        };
      };

      # create symlinks to link k3s's cni directory to the one used by almost all CNI plugins
      # such as multus, calico, etc.
      # https://www.freedesktop.org/software/systemd/man/latest/tmpfiles.d.html#Type
      # systemd.tmpfiles.rules = [
      #   # https://docs.k3s.io/networking/multus-ipams
      #   "L+ /opt/cni/bin - - - - /var/lib/rancher/k3s/data/current/bin"
      #   # If you have disabled flannel, you will have to create the directory via a tmpfiles rule
      #   "d /var/lib/rancher/k3s/agent/etc/cni/net.d 0751 root root - -"
      #   # Link the CNI config directory
      #   "L+ /etc/cni/net.d - - - - /var/lib/rancher/k3s/agent/etc/cni/net.d"
      # ];

      # HACK: Symlink binaries to /usr/local/bin such that Longhorn can find them
      # when they use nsenter.
      # https://github.com/longhorn/longhorn/issues/2166#issuecomment-1740179416
      # systemd.tmpfiles.rules = [
      #   "L+ /usr/local/bin - - - - /run/current-system/sw/bin/"
      # ];

    };

}
