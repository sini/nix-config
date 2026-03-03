{
  self,
  rootPath,
  lib,
  ...
}:
let
  inherit (lib) types mkOption;
  inherit (self.lib.modules) mkDeferredModuleOpt mkUsersWithFeaturesOpt;
in
{
  options.flake.hosts =
    let
      hostType = types.submodule (
        { name, ... }:
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

            unstable = lib.mkOption {
              type = types.bool;
              default = true;
            };

            ipv4 = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "The static IP addresses of this host in it's home vlan.";
            };

            ipv6 = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "The static IPv6 addresses of this host.";
            };

            roles = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of roles for the host.";
            };

            features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of features for the host";
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

            nixosConfiguration = mkOption {
              type = types.deferredModule;
              default = { };
              description = "Host-specific NixOS module configuration.";
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
    };
}
