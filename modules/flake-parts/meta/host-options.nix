{
  lib,
  self,
  rootPath,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (self.lib.modules) mkDeferredModuleOpt mkUsersWithFeaturesOpt;
in
{
  options.flake.hosts =
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

            unstable = mkOption {
              type = types.bool;
              default = true;
              description = "Whether to use nixpkgs-unstable for this host.";
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

            features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of features for the host.";
            };

            exclude-features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of features to exclude for the host (prevents the feature and its requires from being added)";
            };

            public_key = mkOption {
              type = types.path;
              default = rootPath + "/.secrets/host-keys/${name}/ssh_host_ed25519_key.pub";
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
              description = "Environment name that this host belongs to (references flake.environments)";
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

            users = mkUsersWithFeaturesOpt "Users on this host with their features and configuration";

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
