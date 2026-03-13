{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkDeferredModuleOpt =
    description:
    mkOption {
      inherit description;
      type = types.deferredModule;
      default = { };
    };

  featureSubmoduleGenericOptions = {
    requires = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of names of features required by this feature";
    };
    excludes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of names of features to exclude from this feature (prevents the feature and its requires from being added)";
    };

    # Cross-platform system module (included on both NixOS and Darwin)
    system = mkDeferredModuleOpt "A cross-platform system module for this feature (NixOS and Darwin)";

    # Platform-specific system modules (for config that only applies to one platform)
    linux = mkDeferredModuleOpt "A Linux-specific system module for this feature (NixOS only)";
    darwin = mkDeferredModuleOpt "A Darwin-specific system module for this feature (macOS only)";

    # Home-manager module (works on all platforms)
    home = mkDeferredModuleOpt "A Home-Manager module for this feature";
  };

  mkFeatureNameOpt =
    name:
    mkOption {
      type = types.str;
      default = name;
      readOnly = true;
      internal = true;
    };

  mkUsersWithFeaturesOpt =
    description:
    mkOption {
      type = types.lazyAttrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              # Home Manager / system user options
              features = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  List of features specific to the user.

                  While a feature may specify NixOS modules in addition to home
                  modules, only home modules will affect configuration.  For this
                  reason, users should be encouraged to avoid pointlessly specifying
                  their own NixOS modules.
                '';
              };
              configuration = mkDeferredModuleOpt "User-specific home configuration";

              baseline = mkOption {
                type = types.submodule {
                  options = {
                    features = mkOption {
                      type = types.listOf types.str;
                      default = [ ];
                      description = ''
                        List of baseline features shared by all of this user's configurations.
                      '';
                    };
                    inheritHostFeatures = mkOption {
                      type = types.bool;
                      default = false;
                      description = ''
                        Whether to inherit all home-manager features from the host configuration.

                        When true, this user will receive all home-manager modules from the host's
                        enabled features. When false, only user-specific features and baseline features
                        will be included.
                      '';
                    };
                  };
                };
                description = "Baseline features and configurations shared by all of this user's configurations";
                default = { };
              };

              enableUnixAccount = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Whether to create a Unix user account on hosts.
                  If false, this is an identity-only user (e.g., for Kanidm).
                '';
              };

              # Unix account options
              uid = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "User ID for the Unix account";
              };

              gid = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Group ID for the Unix account (defaults to uid if not set)";
              };

              linger = mkOption {
                type = types.bool;
                default = false;
                description = "Enable lingering for the user (systemd user services start without login)";
              };

              systemGroups = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  System groups (extraGroups) for the user.
                  Example: ["wheel", "networkmanager", "podman"]
                '';
              };

              # Identity options (used by Kanidm, Forgejo, etc.)
              displayName = mkOption {
                type = types.str;
                default = name;
                description = "Display name for the user (defaults to username)";
              };

              email = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  Email address for the user.
                  If null, defaults to username@domain.
                  If set, used as the full email address.
                '';
              };

              groups = mkOption {
                type = types.listOf types.str;
                default = [ "users" ];
                description = "List of identity groups the user belongs to (defaults to ['users'])";
              };

              sshKeys = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  SSH public keys for the user.
                  Can be used by system user configuration, Forgejo, etc.
                '';
              };

              gpgKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  GPG key ID for the user (parent key ID).
                  Used for git commit signing, sops encryption, etc.
                '';
              };
            };
          }
        )
      );
      default = { };
      inherit description;
    };
in
{
  flake.lib.modules = {
    inherit
      featureSubmoduleGenericOptions
      mkFeatureNameOpt
      mkDeferredModuleOpt
      mkUsersWithFeaturesOpt
      ;
  };
}
