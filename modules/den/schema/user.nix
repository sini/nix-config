{ lib, rootPath, ... }:
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
    (
      { config, ... }:
      {
        options = {
          identity = mkOption {
            type = types.submodule (
              { config, ... }:
              {
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
                  sshOidcPrincipals = mkOption {
                    type = types.listOf (
                      types.submodule {
                        options = {
                          provider = mkOption {
                            type = types.enum [
                              "kanidm"
                              "google"
                            ];
                            description = "Which opkssh OIDC provider this principal authenticates against.";
                          };
                          email = mkOption {
                            type = types.str;
                            description = "OIDC email claim authorized to log in as this user via opkssh.";
                          };
                        };
                      }
                    );
                    default = lib.optional (config.email != null) {
                      provider = "kanidm";
                      email = config.email;
                    };
                    defaultText = "kanidm principal from identity.email (if set)";
                    description = "opkssh OIDC principals authorized to log in as this user.";
                  };
                };
              }
            );
            default = { };
            description = "User identity information";
          };

          secretPath = mkOption {
            type = types.path;
            # rootPath (a plain `../..` path literal), NOT `self`: this default is
            # forced during the base registry eval, where `self` self-cycles
            # (registry → self → flake outputs → registry). Matches the existing
            # per-user secret convention (spotify-player, agenixUserAspect).
            default = rootPath + "/.secrets/users/${config.name}";
            description = "Per-user secret directory (mirrors host/environment/cluster secretPath).";
          };

          system = mkOption {
            type = types.submodule (
              { config, ... }:
              {
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
                    type = types.nullOr types.bool;
                    default = null;
                    description = "Enable lingering for the user (systemd user services start without login). null leaves it to the host's aspects (an xmsg federation node lingers), otherwise off.";
                  };
                  syncthingOffset = mkOption {
                    type = types.int;
                    default = if config.uid == null then 0 else config.uid - 1000;
                    description = "Per-user Syncthing sync-port offset (port = 22000 + offset). Default: uid - 1000.";
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
                    # Freeform, with typed groups for the aspects whose settings are paths
                    # into one user's home. Every typed default is empty, and empty is off.
                    type = types.submodule {
                      freeformType = types.attrsOf (types.attrsOf types.anything);
                      # applications.dev.ai.agents.claude
                      options.claude = {
                        gatedProjects = mkOption {
                          type = types.listOf types.str;
                          default = [ ];
                          description = "Projects, relative to home, whose sessions get the orchestrator hooks (claude.nix gated.sh). Empty: no session is ever gated.";
                        };
                        xmsgDesign = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                          description = "The xmsg arc's design repo, relative to home; sessions started there get its boot and pre-compact pointers. null: neither fires.";
                        };
                        nixConfigCheckouts = mkOption {
                          type = types.listOf types.str;
                          default = [ ];
                          description = "Checkouts of this nix-config (globs relative to home) whose generated files are denied to Edit. Empty: no deny rules.";
                        };
                        compactionRepos = mkOption {
                          type = types.listOf types.str;
                          default = [ ];
                          description = "Repos (globs relative to home) whose modified/unpushed counts a gated session's pre-compact summary reports. Empty: none.";
                        };
                      };
                      # applications.dev.ai.tools.beads
                      options.beads.workspace = mkOption {
                        type = types.nullOr types.str;
                        default = null;
                        description = "The pinned br workspace (a .beads directory), relative to home, exported as BEADS_DIR. null: no BEADS_DIR.";
                      };
                    };
                    default = { };
                    description = "Per-user feature settings (freeform nested namespace)";
                  };
                };
              }
            );
          };
        };
      }
    )
  ];
}
