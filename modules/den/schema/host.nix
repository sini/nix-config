{ lib, inputs, ... }:
let
  inherit (lib) mkOption types;
  gen = inputs.gen { inherit lib; };

  interfaceType = types.submodule {
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
  };

  exporterType = types.submodule {
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
  };
in
{
  den.schema.host.isEntity = true;
  den.schema.host.validators = [
    (gen.mkValidator "valid-channel" (
      { channel, ... }:
      lib.elem channel [
        "nixos-unstable"
        "nixpkgs-master"
        "nixos-stable"
        "nixpkgs-stable-darwin"
      ]
    ) "channel must be one of: nixos-unstable, nixpkgs-master, nixos-stable, nixpkgs-stable-darwin")
  ];
  den.schema.host.imports = [
    (_: {
      options = {
        channel = mkOption {
          type = types.enum [
            "nixos-unstable"
            "nixpkgs-master"
            "nixos-stable"
            "nixpkgs-stable-darwin"
          ];
          default = "nixos-unstable";
          description = "The nixpkgs channel to use for this host";
        };

        # TODO: replace with schema.ref to den.environments once gen-schema
        # registry wiring is complete.
        environment = mkOption {
          type = types.str;
          default = "prod";
          description = "Environment name that this host belongs to";
        };

        networking =
          mkOption {
            type = types.submodule {
              options = {
                interfaces = mkOption {
                  type = types.attrsOf interfaceType;
                  default = { };
                  description = "Network interfaces with their IP addresses and properties";
                };
                bonds = mkOption {
                  type = types.attrsOf (types.submodule {
                    options = {
                      interfaces = mkOption {
                        type = types.listOf types.str;
                        description = "Physical interfaces to bond together";
                      };
                      mode = mkOption {
                        type = types.str;
                        default = "balance-rr";
                        description = "Bond mode (balance-rr, active-backup, balance-xor, etc.)";
                      };
                      transmitHashPolicy = mkOption {
                        type = types.nullOr types.str;
                        default = null;
                        description = "Transmit hash policy for load-balancing modes";
                      };
                    };
                  });
                  default = { };
                  description = "Network bond definitions";
                };
                autobridging = mkOption {
                  type = types.bool;
                  default = false;
                  description = "Auto-create bridges for each interface";
                };
                bridges = mkOption {
                  type = types.attrsOf (types.listOf types.str);
                  default = { };
                  description = "Bridge definitions mapping bridge name to member interfaces";
                };
              };
            };
            default = { };
            description = "Network configuration for the host";
          }
          // {
            identity = false;
          };

        system-owner = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "The primary user who owns this host";
        };

        system-access-groups = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "System-scoped groups that grant Unix account creation on this host";
        };

        facts =
          mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to the Facter JSON file for the host";
          }
          // {
            identity = false;
          };

        public_key =
          mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to the public SSH key for the host";
          }
          // {
            identity = false;
          };

        exporters =
          mkOption {
            type = types.attrsOf exporterType;
            default = { };
            description = "Prometheus exporters exposed by this host";
          }
          // {
            identity = false;
          };

        settings =
          mkOption {
            type = types.attrsOf (types.attrsOf types.anything);
            default = { };
            description = "Per-host feature settings (freeform nested namespace)";
          }
          // {
            identity = false;
          };
      };
    })
  ];
}
