{
  lib,
  self,
  config,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (self.lib.users) identitySubmoduleType;
  flakeConfig = config;
in
{
  options.users = mkOption {
    type = types.lazyAttrsOf (
      types.submodule (
        { name, config, ... }:
        {
          options = {
            name = mkOption {
              default = name;
              readOnly = true;
              description = "Username";
            };

            # Identity — single source of truth, never duplicated
            identity = mkOption {
              type = identitySubmoduleType name;
              default = { };
              description = "User identity information (single source of truth)";
            };

            # System / Unix account defaults + feature resolution
            system = mkOption {
              type = types.submodule {
                options = {
                  enableUnixAccount = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Whether this user should be provisioned as a Kanidm posixAccount (enables Unix attributes in Kanidm)";
                  };

                  uid = mkOption {
                    type = types.nullOr types.int;
                    default = null;
                    description = "User ID for the Unix account";
                  };

                  gid = mkOption {
                    type = types.nullOr types.int;
                    default = config.system.uid;
                    defaultText = "Same as uid";
                    description = "Group ID for the Unix account (defaults to uid if not set)";
                  };

                  linger = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Enable lingering for the user (systemd user services start without login)";
                  };

                  extra-features = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "List of home-manager feature names to enable for this user";
                  };

                  excluded-features = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "List of feature names to exclude for this user";
                  };

                  include-host-features = mkOption {
                    type = types.bool;
                    default = true;
                    description = ''
                      Whether to inherit all home-manager features from the host configuration.
                      When true, the user receives home modules from all of the host's active features.
                      When false, only user-specific extra-features (and core) are included.
                    '';
                  };

                  settings = self.lib.modules.mkFeatureUserSettingsOpt flakeConfig.features "Per-user feature settings for home modules";
                };
              };
              default = { };
              description = "Unix account defaults and home-manager feature configuration";
            };
          };
        }
      )
    );
    default = { };
    description = "User specifications — canonical identity, system defaults, and feature configuration";
  };
}
