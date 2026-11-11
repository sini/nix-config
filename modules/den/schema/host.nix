# Host entity schema — channels, networking, settings, computed fields.
#
# Follows feat/den's approach: channels defined inline, instantiate/HM module
# derived from config.channel, dynamic settings namespace from den.aspects,
# computed ipv4/ipv6 from networking interfaces.
{
  lib,
  inputs,
  den,
  self,
  rootPath,
  ...
}:
let
  inherit (lib) mkOption types;
  schemaLib = (inputs.gen.lib.mkGenLibs { }).schema;

  interfaceType = types.submodule {
    options = {
      ipv4 = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "IPv4 addresses in CIDR notation";
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
        description = "DHCP mode. null = auto";
      };
      managed = mkOption {
        type = types.bool;
        default = true;
        description = "Apply environment gateway/DNS/subnet";
      };
      mtu = mkOption {
        type = types.nullOr types.int;
        default = null;
        description = "MTU for this interface";
      };
      mac = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = ''
          MAC address of this interface. The interface holding a host's IPv4 on its
          environment's controller network must set it: it keys the host's DHCP
          reservation (docs/address-plan.md §2.3). A bridge adopts its port's, so
          the host's L2 identity is unchanged by bridging (netboot and the running
          system present the same address to the router); a bridge NEVER inherits
          a port's MAC on its own, and with null falls back to networkd's
          machine-id-derived address. A bond is pinned to its own (MACAddress=).
          Elsewhere it is the NIC's address, declared, not set.
        '';
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
        description = "Link-local addressing";
      };
      requiredForOnline = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "RequiredForOnline value";
      };
      privacyExtensions = mkOption {
        type = types.nullOr (
          types.enum [
            "yes"
            "no"
            "prefer-public"
            "kernel"
          ]
        );
        default = null;
        description = ''
          IPv6 privacy/temporary addresses (systemd-networkd
          IPv6PrivacyExtensions). null = default ("yes"). Set "no" on
          infrastructure nodes so the host sources traffic from a stable
          address (e.g. so Cilium's masquerade source stays warm).
        '';
      };
      advertiseUla = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Send prefix-only RAs for the environment's ULA (networks.default.ipv6_cidr)
          on this link: on-link, not autonomous, never a default router, so LAN clients
          reach the ULA addresses here directly (uplink, for Blocky's ::53;
          docs/dns-resolver.md §2.4(a)). A ULA address alone sends none.
        '';
      };
      acceptRAAutonomousPrefix = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = ''
          Generate a SLAAC address from RA autonomous prefixes
          ([IPv6AcceptRA] UseAutonomousPrefix). null = default (true). Set
          false for static-only addressing (RA is still used for the route). A LAN
          link's one stable GUA is its token (docs/address-plan.md §2.2).
        '';
      };
    };
  };

  exporterType = types.submodule {
    options = {
      port = mkOption {
        type = types.int;
        description = "Port number";
      };
      path = mkOption {
        type = types.str;
        default = "/metrics";
      };
      interval = mkOption {
        type = types.str;
        default = "30s";
      };
    };
  };

  # Channel definitions — maps channel name to nixpkgs/HM/darwin inputs
  channels = {
    nixos-unstable = {
      nixosSystem = inputs.nixpkgs-unstable.lib.nixosSystem;
      darwinSystem = inputs.nix-darwin-unstable.lib.darwinSystem;
      home-manager-module.nixos = inputs.home-manager-unstable.nixosModules.home-manager;
      home-manager-module.darwin = inputs.home-manager-unstable.darwinModules.home-manager;
    };
    nixpkgs-master = {
      nixosSystem = inputs.nixpkgs-master.lib.nixosSystem;
      darwinSystem = inputs.nix-darwin-unstable.lib.darwinSystem;
      home-manager-module.nixos = inputs.home-manager-master.nixosModules.home-manager;
      home-manager-module.darwin = inputs.home-manager-master.darwinModules.home-manager;
    };
    nixos-stable = {
      nixosSystem = inputs.nixpkgs.lib.nixosSystem;
      darwinSystem = inputs.nix-darwin.lib.darwinSystem;
      home-manager-module.nixos = inputs.home-manager.nixosModules.home-manager;
      home-manager-module.darwin = inputs.home-manager.darwinModules.home-manager;
    };
    nixpkgs-stable-darwin = {
      nixosSystem = inputs.nixpkgs-stable-darwin.lib.nixosSystem;
      darwinSystem = inputs.nix-darwin.lib.darwinSystem;
      home-manager-module.nixos = inputs.home-manager-stable-darwin.nixosModules.home-manager;
      home-manager-module.darwin = inputs.home-manager-stable-darwin.darwinModules.home-manager;
    };
  };

  channelNames = builtins.attrNames channels;

  # Dynamic settings type — recursively discovers aspects that declare .settings.
  # Mirrors the aspect tree: den.aspects.disk.zfs-disk-single.settings →
  # host.settings.disk.zfs-disk-single.*  (shared with the cluster schema).
  settingsType = import ./_settings-type.nix { inherit den lib; };
in
{
  den.schema.host.isEntity = true;

  den.schema.host.validators = [
    (schemaLib.mkValidator {
      name = "valid-channel";
      pred = { channel, ... }: lib.elem channel channelNames;
      message = "channel must be one of: ${lib.concatStringsSep ", " channelNames}";
    })
  ];

  den.schema.host.imports = [
    (
      { config, ... }:
      let
        resolvedChannel = channels.${config.channel};
      in
      {
        options = {
          channel = mkOption {
            type = types.enum channelNames;
            default = "nixos-unstable";
            description = "Nixpkgs channel — determines nixpkgs, home-manager, and nix-darwin versions";
          };

          environment = mkOption {
            type = types.str;
            default = "prod";
            description = "Environment name that this host belongs to";
          };

          # Computed IPs from networking interfaces
          ipv4 = mkOption {
            type = types.listOf types.str;
            readOnly = true;
            default =
              let
                ifaces = config.networking.interfaces or { };
                ifaceList = lib.attrValues ifaces;
                withIps = lib.findFirst (i: (i.ipv4 or [ ]) != [ ]) null ifaceList;
                stripCidr = addr: builtins.head (lib.splitString "/" addr);
              in
              if withIps != null then map stripCidr withIps.ipv4 else [ ];
            description = "Primary IPv4 addresses (derived from first interface with IPs, CIDR stripped)";
          };

          ipv6 = mkOption {
            type = types.listOf types.str;
            readOnly = true;
            default =
              let
                ifaces = config.networking.interfaces or { };
                ifaceList = lib.attrValues ifaces;
                withIps = lib.findFirst (i: (i.ipv6 or [ ]) != [ ]) null ifaceList;
              in
              if withIps != null then withIps.ipv6 else [ ];
            description = "Primary IPv6 addresses (derived from first interface with IPs)";
          };

          networking =
            mkOption {
              type = types.submodule {
                options = {
                  interfaces = mkOption {
                    type = types.attrsOf interfaceType;
                    default = { };
                    description = "Network interfaces";
                  };
                  bonds = mkOption {
                    type = types.attrsOf (
                      types.submodule {
                        options = {
                          interfaces = mkOption { type = types.listOf types.str; };
                          mode = mkOption {
                            type = types.str;
                            default = "balance-rr";
                          };
                          transmitHashPolicy = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                          };
                        };
                      }
                    );
                    default = { };
                    description = "Bond definitions";
                  };
                  autobridging = mkOption {
                    type = types.bool;
                    default = false;
                  };
                  bridges = mkOption {
                    type = types.attrsOf (types.listOf types.str);
                    default = { };
                  };
                };
              };
              default = { };
            }
            // {
              identity = false;
            };

          system-owner = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Primary user for this host";
          };

          system-access-groups = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Groups granting Unix account creation on this host";
          };

          facts =
            mkOption {
              type = types.nullOr types.path;
              default = null;
            }
            // {
              identity = false;
            };

          secretPath =
            mkOption {
              type = types.nullOr types.path;
              default = null;
            }
            // {
              identity = false;
            };

          public_key =
            mkOption {
              type = types.nullOr types.path;
              default = null;
            }
            // {
              identity = false;
            };

          exporters =
            mkOption {
              type = types.attrsOf exporterType;
              default = { };
            }
            // {
              identity = false;
            };

          # Dynamic settings namespace — auto-discovers aspects with .settings
          settings =
            mkOption {
              type = settingsType;
              default = { };
              description = "Per-aspect typed settings";
            }
            // {
              identity = false;
            };
        };

        # Computed config — channel determines instantiate + HM module
        config = {
          # rootPath (a `../..` path literal), NOT `self`: these defaults are
          # forced during base eval by the producer-class config-thunk broadcast
          # (a host config is navigated to reach a nested home config), where
          # `self` self-cycles (registry → self → flake outputs → registry).
          # Same git-tracked source as `self`; mirrors `user.secretPath`.
          secretPath = lib.mkDefault (rootPath + "/.secrets/hosts/${config.name}");
          facts = lib.mkDefault (rootPath + "/hosts/${config.name}/facter.json");
          public_key = lib.mkDefault (
            if config.secretPath != null then config.secretPath + "/ssh_host_ed25519_key.pub" else null
          );

          instantiate = lib.mkDefault (
            if config.class == "darwin" then resolvedChannel.darwinSystem else resolvedChannel.nixosSystem
          );

          home-manager.module = lib.mkDefault (
            if config.class == "darwin" then
              resolvedChannel.home-manager-module.darwin
            else
              resolvedChannel.home-manager-module.nixos
          );
        };
      }
    )
  ];
}
