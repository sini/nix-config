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
  ...
}:
let
  inherit (lib) mkOption types;
  gen = inputs.gen { inherit lib; };

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
        type = types.nullOr (types.enum [ "none" "ipv4" "ipv6" "yes" ]);
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
      linkLocal = mkOption {
        type = types.nullOr (types.enum [ "ipv4" "ipv6" "yes" "no" ]);
        default = null;
        description = "Link-local addressing";
      };
      requiredForOnline = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "RequiredForOnline value";
      };
    };
  };

  exporterType = types.submodule {
    options = {
      port = mkOption { type = types.int; description = "Port number"; };
      path = mkOption { type = types.str; default = "/metrics"; };
      interval = mkOption { type = types.str; default = "30s"; };
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
  # Walks the nested aspect tree, collecting { "name" = settings-module } pairs.
  settingsType =
    let
      # Recursively collect aspects with .settings from the aspect tree.
      # Produces a flat attrset: { "zfs-disk-single" = <settings>; "impermanence" = <settings>; ... }
      collectSettings = prefix: aspects:
        lib.foldlAttrs (acc: name: aspect:
          let
            fullName = if prefix == "" then name else "${prefix}-${name}";
            hasSelf = builtins.isAttrs aspect && aspect ? settings;
            # Recurse into nested aspects (attrsets that contain further aspects)
            nested = if builtins.isAttrs aspect
              then collectSettings fullName (lib.filterAttrs (k: v:
                builtins.isAttrs v && k != "settings" && k != "nixos" && k != "darwin"
                && k != "homeManager" && k != "includes" && k != "meta" && k != "name"
                && k != "homeLinux" && k != "homeDarwin" && k != "homeAarch64"
                && k != "firewall" && k != "persist" && k != "cache"
                && k != "persistHome" && k != "cacheHome" && k != "age-secrets"
                && k != "service-domains" && k != "k8s-manifests" && k != "prometheus-targets"
                && k != "_"
              ) aspect)
              else { };
          in
          acc
          // lib.optionalAttrs hasSelf { ${fullName} = aspect.settings; }
          // nested
        ) { } aspects;

      aspectsWithSettings = collectSettings "" (den.aspects or { });

      reshapeSettings = raw: {
        imports = raw.imports or [ ];
        config = raw.config or { };
        options = builtins.removeAttrs raw [ "imports" "config" ];
      };
    in
    types.submodule {
      options = lib.mapAttrs (
        name: settings:
        mkOption {
          type = types.submodule (reshapeSettings settings);
          default = { };
          description = "Settings for the ${name} aspect";
        }
      ) aspectsWithSettings;
    };
in
{
  den.schema.host.isEntity = true;

  den.schema.host.validators = [
    (gen.mkValidator "valid-channel"
      ({ channel, ... }: lib.elem channel channelNames)
      "channel must be one of: ${lib.concatStringsSep ", " channelNames}")
  ];

  den.schema.host.imports = [
    ({ config, ... }:
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
              ifNames = builtins.attrNames ifaces;
              firstIf = if ifNames != [ ] then ifaces.${builtins.head ifNames} else { };
              stripCidr = addr: builtins.head (lib.splitString "/" addr);
            in
            map stripCidr (firstIf.ipv4 or [ ]);
          description = "Primary IPv4 addresses (derived from first interface, CIDR stripped)";
        };

        ipv6 = mkOption {
          type = types.listOf types.str;
          readOnly = true;
          default =
            let
              ifaces = config.networking.interfaces or { };
              ifNames = builtins.attrNames ifaces;
              firstIf = if ifNames != [ ] then ifaces.${builtins.head ifNames} else { };
            in
            firstIf.ipv6 or [ ];
          description = "Primary IPv6 addresses (derived from first interface)";
        };

        networking = mkOption {
          type = types.submodule {
            options = {
              interfaces = mkOption {
                type = types.attrsOf interfaceType;
                default = { };
                description = "Network interfaces";
              };
              bonds = mkOption {
                type = types.attrsOf (types.submodule {
                  options = {
                    interfaces = mkOption { type = types.listOf types.str; };
                    mode = mkOption { type = types.str; default = "balance-rr"; };
                    transmitHashPolicy = mkOption { type = types.nullOr types.str; default = null; };
                  };
                });
                default = { };
                description = "Bond definitions";
              };
              autobridging = mkOption { type = types.bool; default = false; };
              bridges = mkOption {
                type = types.attrsOf (types.listOf types.str);
                default = { };
              };
            };
          };
          default = { };
        } // { identity = false; };

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

        facts = mkOption {
          type = types.nullOr types.path;
          default = null;
        } // { identity = false; };

        secretPath = mkOption {
          type = types.nullOr types.path;
          default = null;
        } // { identity = false; };

        public_key = mkOption {
          type = types.nullOr types.path;
          default = null;
        } // { identity = false; };

        exporters = mkOption {
          type = types.attrsOf exporterType;
          default = { };
        } // { identity = false; };

        # Dynamic settings namespace — auto-discovers aspects with .settings
        settings = mkOption {
          type = settingsType;
          default = { };
          description = "Per-aspect typed settings";
        } // { identity = false; };
      };

      # Computed config — channel determines instantiate + HM module
      config = {
        secretPath = lib.mkDefault (self + "/.secrets/hosts/${config.name}");
        facts = lib.mkDefault (self + "/hosts/${config.name}/facter.json");
        public_key = lib.mkDefault (
          if config.secretPath != null
          then config.secretPath + "/ssh_host_ed25519_key.pub"
          else null
        );

        instantiate = lib.mkDefault (
          if config.class == "darwin"
          then resolvedChannel.darwinSystem
          else resolvedChannel.nixosSystem
        );

        home-manager.module = lib.mkDefault (
          if config.class == "darwin"
          then resolvedChannel.home-manager-module.darwin
          else resolvedChannel.home-manager-module.nixos
        );
      };
    })
  ];
}
