{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (builtins) elemAt;
  inherit (lib)
    mkMerge
    mkOption
    types
    ;
  inherit (lib.lists) optionals;
  inherit (lib.types)
    enum
    listOf
    str
    ;
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

    mainUser = mkOption {
      type = enum config.node.users;
      default = elemAt config.node.users 0;
      description = ''
        The username of the main user for your system.

        In case of a multiple systems, this will be the user with priority in ordered lists and enabled options.
      '';
    };

    users = mkOption {
      type = listOf str;
      default = [ "sini" ];
      description = "A list of home-manager users on the system.";
    };

    tags = lib.mkOption {
      description = ''
        A list of tags for the node.

        Can be used to select a group of nodes for deployment.
      '';
      type = types.listOf types.str;
      default = [ ];
    };

  };

  config = {
    warnings = mkMerge [
      (optionals (config.node.users == [ ]) [
        ''
          You have not added any users to be supported by your system. You may end up with an unbootable system!

          Consider setting {option}`config.node.users` in your configuration
        ''
      ])
    ];
  };
}
