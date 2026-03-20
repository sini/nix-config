{
  lib,
  self,
  rootPath,
  config,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (self.lib.modules) mkDeferredModuleOpt mkHostUsersOpt;
  flakeConfig = config; # Capture flake-level config for use in submodules
in
{
  options.hosts =
    let
      hostType = types.submodule (
        { name, config, ... }:
        {
          options = {
            hostname = mkOption {
              default = name;
              readOnly = true;
              description = "Hostname";
            };

            system = mkOption {
              type = types.enum [
                "aarch64-linux"
                "x86_64-linux"
                "aarch64-darwin"
              ];
              default = "x86_64-linux";
              description = "System string for the host";
            };

            remoteBuildJobs = mkOption {
              type = types.int;
              default = 4;
              description = "The number of build jobs to be scheduled";
            };

            remoteBuildSpeed = mkOption {
              type = types.int;
              default = 1;
              description = "The relative build speed";
            };

            remote-deployment-user = mkOption {
              type = types.str;
              default = "root";
              description = "The user to use for remote deployments";
            };

            channel = mkOption {
              type = types.enum (builtins.attrNames flakeConfig.channels);
              default = "nixos-unstable";
              description = "The nixpkgs channel to use for this host, determining nixpkgs, home-manager, and nix-darwin inputs.";
            };

            networking = mkOption {
              type = types.submodule {
                options = {
                  interfaces = mkOption {
                    type = types.attrsOf (
                      types.submodule {
                        options = {
                          ipv4 = mkOption {
                            type = types.listOf types.str;
                            default = [ ];
                            description = "IPv4 addresses for this interface";
                          };
                          ipv6 = mkOption {
                            type = types.listOf types.str;
                            default = [ ];
                            description = "IPv6 addresses for this interface";
                          };
                        };
                      }
                    );
                    default = { };
                    description = "Network interfaces with their IP addresses";
                    example = lib.literalExpression ''
                      {
                        enp8s0 = {
                          ipv4 = [ "10.9.2.1" ];
                          ipv6 = [ "fd64:0:1::5/64" ];
                        };
                      }
                    '';
                  };

                  autobridging = mkOption {
                    type = types.bool;
                    default = false;
                    description = "Enable automatic 1:1 bridge creation for each interface";
                  };

                  bridges = mkOption {
                    type = types.attrsOf (types.listOf types.str);
                    default = { };
                    description = "Attribute set mapping bridge names to lists of interfaces";
                    example = lib.literalExpression ''
                      {
                        br0 = [ "enp2s0" "enp3s0" ];
                        br1 = [ "enp4s0" ];
                      }
                    '';
                  };

                  unmanagedInterfaces = mkOption {
                    type = types.listOf types.str;
                    default = [ ];
                    description = "List of interfaces to mark as unmanaged by NetworkManager";
                  };
                };
              };
              default = { };
              description = "Network configuration for the host";
            };

            # Derived options for backward compatibility
            ipv4 = mkOption {
              type = types.listOf types.str;
              default = lib.flatten (
                lib.mapAttrsToList (_: iface: iface.ipv4 or [ ]) config.networking.interfaces
              );
              description = "The static IP addresses of this host in its home vlan (derived from networking.interfaces)";
            };

            ipv6 = mkOption {
              type = types.listOf types.str;
              default = lib.flatten (
                lib.mapAttrsToList (_: iface: iface.ipv6 or [ ]) config.networking.interfaces
              );
              description = "The static IPv6 addresses of this host (derived from networking.interfaces)";
            };

            roles = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of roles for the host.";
            };

            extra-features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of additional features to enable for the host (beyond those from roles).";
            };

            excluded-features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of features to exclude for the host (prevents the feature and its requires from being added)";
            };

            secretPath = mkOption {
              type = types.path;
              default = rootPath + "/.secrets/hosts/${name}";
              description = "Path to the directory containing secret keys for the host.";
            };

            public_key = mkOption {
              type = types.path;
              default = config.secretPath + "/ssh_host_ed25519_key.pub";
              description = "Path to or string value of the public SSH key for the host.";
            };

            facts = mkOption {
              type = types.nullOr types.path;
              default = null;
              description = "Path to the Facter JSON file for the host.";
            };

            systemConfiguration = mkOption {
              type = types.deferredModule;
              default = { };
              description = "Host-specific system module configuration.";
            };

            extra_modules = mkOption {
              type = types.listOf types.deferredModule;
              default = [ ];
              description = "List of additional modules to include for the host.";
            };

            tags = mkOption {
              type = types.attrsOf types.str;
              default = { };
              description = ''
                An attribute set of string key-value pairs to tag the host with metadata.
                Example: `{ "kubernetes-cluster" = "prod"; "kubernetes-internal-ip" = "10.0.1.100"; }`

                Special tags:
                - bgp-asn: BGP AS number for this host (used by bgp-hub and thunderbolt-mesh modules)
                - thunderbolt-interface-1: IPv4 address for first thunderbolt interface (e.g., "169.254.12.0/31")
                - thunderbolt-interface-2: IPv4 address for second thunderbolt interface (e.g., "169.254.31.1/31")
              '';
            };

            environment = mkOption {
              type = types.str;
              default = "prod";
              description = "Environment name that this host belongs to (references environments)";
            };

            baseline = mkOption {
              type = types.submodule {
                options = {
                  home = mkDeferredModuleOpt "Host-specific home-manager configuration, applied to all users for host.";
                };
              };
              description = "Baseline configurations for repeatable configuration types on this host";
              default = { };
            };

            users = mkHostUsersOpt "Users on this host with their features and configuration";

            system-access-groups = mkOption {
              type = types.listOf types.str;
              description = ''
                System-scoped groups that grant Unix account creation on this host.
                Merged with environment-level system-access-groups at resolution time.
                Defaults are derived from host roles (workstation → workstation-access,
                server → server-access, fallback → system-access).
              '';
            };

            exporters = mkOption {
              type = types.attrsOf (
                types.submodule {
                  options = {
                    port = mkOption {
                      type = types.int;
                      description = "Port number for the exporter";
                    };
                    path = mkOption {
                      type = types.str;
                      default = "/metrics";
                      description = "HTTP path for metrics endpoint";
                    };
                    interval = mkOption {
                      type = types.str;
                      default = "30s";
                      description = "Scrape interval";
                    };
                  };
                }
              );
              default = { };
              description = ''
                Prometheus exporters exposed by this host.
                Example: `{ node = { port = 9100; }; k3s = { port = 10249; }; }`
              '';
            };

            features = mkOption {
              type = types.listOf types.str;
              readOnly = true;
              description = ''
                Computed list of all enabled features for this host.
                Includes features from roles, extra-features, and all transitive dependencies,
                with excluded-features applied.
              '';
            };

            hasFeature = mkOption {
              type = types.functionTo types.bool;
              readOnly = true;
              description = ''
                Helper function to check if a feature is enabled for this host.
                Returns true if the feature is in the computed features list, false otherwise.
                Example: host.hasFeature "podman" → true/false
              '';
            };

            isDarwin = mkOption {
              type = types.bool;
              readOnly = true;
              description = ''
                Helper property to check if this host is running macOS (Darwin).
                Returns true if the system is aarch64-darwin, false otherwise.
                Example: host.isDarwin → true/false
              '';
            };
          };

          config =
            let
              # Use centralized feature resolution from lib.modules
              computedFeatures = self.lib.modules.computeActiveFeatures {
                featuresConfig = flakeConfig.features;
                rolesConfig = flakeConfig.roles;
                hostRoles = config.roles;
                hostFeatures = config.extra-features or [ ];
                hostExclusions = config.excluded-features or [ ];
              };
            in
            {
              features = computedFeatures;

              hasFeature = featureName: lib.elem featureName computedFeatures;

              isDarwin = lib.hasSuffix "darwin" config.system;

              system-access-groups =
                let
                  roleDefaults = {
                    workstation = [ "workstation-access" ];
                    dev = [ "workstation-access" ];
                    server = [ "server-access" ];
                  };
                  fromRoles = lib.unique (lib.flatten (map (role: roleDefaults.${role} or [ ]) config.roles));
                in
                lib.mkDefault (if fromRoles != [ ] then fromRoles else [ "system-access" ]);
            };
        }
      );
    in
    mkOption {
      type = types.attrsOf hostType;
      default = { };
      description = "Per-host NixOS configurations.";
    };
}
