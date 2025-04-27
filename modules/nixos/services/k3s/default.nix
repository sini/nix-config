{
  lib,
  config,
  namespace,
  ...
}:
{
  options.services.${namespace}.k3s = {
    enable = lib.mkOption {
      default = builtins.elem "kubernetes" config.node.deployment.tags;
      type = lib.types.bool;
      description = ''
        Whether to run k3s on this server.
      '';
    };

    role = lib.mkOption {
      default =
        if (builtins.elem "kubernetes-master" config.node.deployment.tags) then "server" else "agent";
      type = lib.types.str;
      description = ''
        Whether to run k3s as a server or an agent.
      '';
    };

    clusterInit = lib.mkOption {
      default = builtins.elem "kubernetes-master" config.node.deployment.tags;
      type = lib.types.bool;
      description = ''
        Whether this node should initialize the K8s cluster.
      '';
    };

    serverAddr = lib.mkOption {
      default =
        if config.services.${namespace}.clusterInit then
          null
        else
          lib.${namespace}.getKubernetesMasterTargetHost;
      type = with lib.types; nullOr str;
      description = ''
        Address of the server whose cluster this server should join.
        Leaving this empty will make the server initialize the cluster.
      '';
    };
  };

  config = lib.mkIf config.services.${namespace}.k3s.enable {
    # age.secrets = {
    #   "foo" = {
    #     rekeyFile = lib.${namespace}.relativeToRoot "secrets/foo.age";
    #     owner = "media";
    #     group = "media";
    #   };
    # };

    # environment.systemPackages = with pkgs; [
    #   k3s
    #   openiscsi # Required for Longhorn
    #   nfs-utils # Required for Longhorn
    # ];

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
    # };
  };
}
