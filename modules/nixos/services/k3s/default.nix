{
  lib,
  config,
  namespace,
  ...
}:
{
  options.services.${namespace}.k3s = {
    enable = lib.mkOption {
      default = builtins.elem "kubernetes" config.deployment.tags;
      type = lib.types.bool;
      description = ''
        Whether to run k3s on this server.
      '';
    };

    role = lib.mkOption {
      default = if (builtins.elem "kubernetes-master" config.deployment.tags) then "server" else "agent";
      type = lib.types.str;
      description = ''
        Whether to run k3s as a server or an agent.
      '';
    };

    clusterInit = lib.mkOption {
      default = builtins.elem "kubernetes-master" config.deployment.tags;
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

  config = lib.mkIf config.services.${namespace}.k3s.enable { };
}
