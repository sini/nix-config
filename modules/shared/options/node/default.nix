{
  config,
  lib,
  namespace,
  pkgs,
  ...
}:
let
  inherit (lib)
    mkOption
    types
    ;
  inherit (lib.${namespace}) relativeToRoot;
in
{
  options.node = {

    hostname = mkOption {
      description = "The canonical hostname of the machine.";
      type = types.str;
      default = config.networking.hostName;
      readOnly = true;
    };

    system = lib.mkOption {
      type = lib.types.str;
      description = ''
        The architecture of the machine.

        By default, this is is an alias for {option}`pkgs.stdenv.system` and
        {option}`nixpkgs.hostPlatform` in a top-level configuration.
      '';
      default = pkgs.stdenv.system;
      readOnly = true;
    };

    rootPath = mkOption {
      description = "The root path for this node in the repository.";
      type = types.path;
      default = relativeToRoot "systems/${config.node.system}/${config.node.hostname}";
      readOnly = true;
    };

    secretsDir = mkOption {
      description = "Path to the secrets directory for this node.";
      type = types.path;
      default = relativeToRoot "systems/${config.node.system}/${config.node.hostname}/secrets";
      readOnly = true;
    };

    # Lifted from https://github.com/zhaofengli/colmena/blob/main/src/nix/hive/options.nix
    deployment = {
      targetHost = lib.mkOption {
        description = ''
          The target SSH node for deployment.

          By default, the node's attribute name will be used.
          If set to null, only local deployment will be supported.
        '';
        type = types.nullOr types.str;
        default = config.node.name;
      };
      targetPort = lib.mkOption {
        description = ''
          The target SSH port for deployment.

          By default, the port is the standard port (22) or taken
          from your ssh_config.
        '';
        type = types.nullOr types.ints.unsigned;
        default = null;
      };
      targetUser = lib.mkOption {
        description = ''
          The user to use to log into the remote node. If set to null, the
          target user will not be specified in SSH invocations.
        '';
        type = types.nullOr types.str;
        default = "root";
      };
      allowLocalDeployment = lib.mkOption {
        description = ''
          Allow the configuration to be applied locally on the host running
          Colmena.

          For local deployment to work, all of the following must be true:
          - The node must be running NixOS.
          - The node must have deployment.allowLocalDeployment set to true.
          - The node's networking.hostName must match the hostname.

          To apply the configurations locally, run `colmena apply-local`.
          You can also set deployment.targetHost to null if the nost is not
          accessible over SSH (only local deployment will be possible).
        '';
        type = types.bool;
        default = false;
      };
      buildOnTarget = lib.mkOption {
        description = ''
          Whether to build the system profiles on the target node itself.

          When enabled, Colmena will copy the derivation to the target
          node and initiate the build there. This avoids copying back the
          build results involved with the native distributed build
          feature. Furthermore, the `build` goal will be equivalent to
          the `push` goal. Since builds happen on the target node, the
          results are automatically "pushed" and won't exist in the local
          Nix store.

          You can temporarily override per-node settings by passing
          `--build-on-target` (enable for all nodes) or
          `--no-build-on-target` (disable for all nodes) on the command
          line.
        '';
        type = types.bool;
        default = false;
      };
      tags = lib.mkOption {
        description = ''
          A list of tags for the node.

          Can be used to select a group of nodes for deployment.
        '';
        type = types.listOf types.str;
        default = [ ];
      };
      privilegeEscalationCommand = lib.mkOption {
        description = ''
          Command to use to elevate privileges when activating the new profiles on SSH hosts.

          This is used on SSH hosts when `deployment.targetUser` is not `root`.
          The user must be allowed to use the command non-interactively.
        '';
        type = types.listOf types.str;
        default = [
          "doas"
          "--"
        ];
      };

    };

    sshConn = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      description = ''
        The SSH connection string for colmena nodes
      '';
      default = builtins.mapAttrs (_: v: "${v.targetUser}@${v.targetHost}") config.node.deployment;
      readOnly = true;
    };

  };
}
