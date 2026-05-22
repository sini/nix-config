{ lib, ... }:
let
  inherit (lib) mkOption types;

  sshKeyType = types.submodule {
    options = {
      tag = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Tag to categorize the SSH key (e.g., 'laptop', 'workstation', 'yubikey')";
      };
      key = mkOption {
        type = types.str;
        description = "SSH public key string";
      };
    };
  };
in
{
  den.schema.user.imports = [
    (_: {
      options = {
        identity = mkOption {
          type = types.submodule {
            options = {
              displayName = mkOption {
                type = types.str;
                default = "";
                description = "Display name for the user";
              };
              email = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "Email address for the user";
              };
              gpgKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "GPG key ID for the user";
              };
              sshKeys = mkOption {
                type = types.listOf sshKeyType;
                default = [ ];
                description = "SSH public keys for the user, each with an optional tag";
              };
            };
          };
          default = { };
          description = "User identity information";
        };

        system = mkOption {
          type = types.submodule {
            options = {
              uid = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "User ID for the Unix account";
              };
              gid = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Group ID for the Unix account";
              };
              linger = mkOption {
                type = types.bool;
                default = false;
                description = "Enable lingering for the user (systemd user services start without login)";
              };
              enableUnixAccount = mkOption {
                type = types.bool;
                default = true;
                description = "Whether to create a Unix account for this user (kanidm posixAccount flag)";
              };
              extra-features = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Additional feature aspects to include for this user beyond defaults";
              };
              excluded-features = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Feature aspects to exclude for this user";
              };
              include-host-features = mkOption {
                type = types.bool;
                default = false;
                description = "Whether to inherit host-level aspect features for this user";
              };
              settings = mkOption {
                type = types.attrsOf (types.attrsOf types.anything);
                default = { };
                description = "Per-user feature settings (freeform nested namespace)";
              };
            };
          };
          default = { };
          description = "Unix account defaults and system configuration";
        };
      };
    })
  ];
}
