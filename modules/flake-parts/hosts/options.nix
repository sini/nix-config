{
  lib,
  self,
  rootPath,
  config,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (self.lib.features) mkDeferredModuleOpt;
  inherit (self.lib.users) mkHostUsersOpt;
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
                            description = "IPv4 addresses in CIDR notation (e.g., '10.9.2.1/16')";
                          };
                          ipv6 = mkOption {
                            type = types.listOf types.str;
                            default = [ ];
                            description = "IPv6 addresses in CIDR notation";
                          };
                          dhcp = mkOption {
                            type = types.nullOr (
                              types.enum [
                                "none"
                                "ipv4"
                                "ipv6"
                                "yes"
                              ]
                            );
                            default = null;
                            description = "DHCP mode. null = auto (ipv6 if static ipv4, yes if no static ipv4)";
                          };
                          managed = mkOption {
                            type = types.bool;
                            default = true;
                            description = "Apply environment gateway/DNS/subnet. false for point-to-point or standalone links.";
                          };
                          mtu = mkOption {
                            type = types.nullOr types.int;
                            default = null;
                            description = "MTU for this interface. null = system default.";
                          };
                          linkLocal = mkOption {
                            type = types.nullOr (
                              types.enum [
                                "ipv4"
                                "ipv6"
                                "yes"
                                "no"
                              ]
                            );
                            default = null;
                            description = "Link-local addressing. null = auto (ipv6 for managed, no for unmanaged).";
                          };
                          requiredForOnline = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                            description = "RequiredForOnline value. null = auto (routable).";
                          };
                        };
                      }
                    );
                    default = { };
                    description = "Network interfaces with their IP addresses and properties";
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
                  };

                  bonds = mkOption {
                    type = types.attrsOf (
                      types.submodule {
                        options = {
                          interfaces = mkOption {
                            type = types.listOf types.str;
                            description = "Member interfaces for this bond";
                          };
                          mode = mkOption {
                            type = types.str;
                            default = "802.3ad";
                            description = "Bond mode (802.3ad, balance-xor, balance-rr, etc.)";
                          };
                          transmitHashPolicy = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                            description = "Transmit hash policy for the bond";
                          };
                        };
                      }
                    );
                    default = { };
                    description = "Bond devices with their member interfaces and settings";
                  };
                };
              };
              default = { };
              description = "Network configuration for the host";
            };

            # Derived options — only managed interfaces, CIDR stripped
            ipv4 = mkOption {
              type = types.listOf types.str;
              default = lib.flatten (
                lib.mapAttrsToList (
                  _: iface:
                  if iface.managed or true then
                    map (addr: lib.head (lib.splitString "/" addr)) (iface.ipv4 or [ ])
                  else
                    [ ]
                ) config.networking.interfaces
              );
              description = "Management IPv4 addresses (derived from managed interfaces, CIDR stripped)";
            };

            ipv6 = mkOption {
              type = types.listOf types.str;
              default = lib.flatten (
                lib.mapAttrsToList (
                  _: iface: if iface.managed or true then iface.ipv6 or [ ] else [ ]
                ) config.networking.interfaces
              );
              description = "Management IPv6 addresses (derived from managed interfaces)";
            };

            extra-features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of features to enable for the host (beyond the core features).";
            };

            excluded-features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = "List of features to exclude for the host (prevents the feature and its requires from being added)";
            };

            settings = self.lib.features.mkFeatureSettingsOpt flakeConfig.features "Per-host feature settings (overrides environment defaults)";

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

            system-owner = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = ''
                The primary user who owns this host. Used by features that require
                a single user (e.g. libvirt QEMU process owner, sunshine game streaming).
                When null, defaults to the first canonical user with system-access scope.
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
                Includes core features, extra-features, and all transitive dependencies,
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
              computedFeatures = self.lib.features.resolver.computeActiveFeatures {
                featuresConfig = flakeConfig.features;
                hostFeatures = config.extra-features or [ ];
                hostExclusions = config.excluded-features or [ ];
              };

              # Derive system access groups from enabled features
              hasWorkstation = lib.elem "workstation" computedFeatures;
              hasDev = lib.elem "dev" computedFeatures;
              hasServer = lib.elem "server" computedFeatures;
            in
            {
              features = computedFeatures;

              hasFeature = featureName: lib.elem featureName computedFeatures;

              isDarwin = lib.hasSuffix "darwin" config.system;

              system-access-groups =
                let
                  defaultGroups =
                    if hasWorkstation || hasDev then
                      [ "workstation-access" ]
                    else if hasServer then
                      [ "server-access" ]
                    else
                      [ "system-access" ];
                in
                lib.mkDefault defaultGroups;
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
