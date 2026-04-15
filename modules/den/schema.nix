# Typed host schema extensions for den aspects.
{
  lib,
  inputs,
  den,
  ...
}:
{
  den.schema.host =
    { config, ... }:
    let
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

      resolvedChannel = channels.${config.channel};
    in
    {
      options = {
        channel = lib.mkOption {
          type = lib.types.enum (builtins.attrNames channels);
          default = "nixos-unstable";
          description = "Nixpkgs channel — determines nixpkgs, home-manager, and nix-darwin versions";
        };

        # Computed IPs from networking interfaces (matching old host type)
        ipv4 = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          default =
            let
              interfaces = config.networking.interfaces or { };
              ifNames = builtins.attrNames interfaces;
              firstIf = if ifNames != [ ] then interfaces.${builtins.head ifNames} else { };
              stripCidr = addr: builtins.head (lib.splitString "/" addr);
            in
            map stripCidr (firstIf.ipv4 or [ ]);
          description = "Primary IPv4 addresses (derived from first networking interface, CIDR stripped)";
        };

        ipv6 = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          readOnly = true;
          default =
            let
              interfaces = config.networking.interfaces or { };
              ifNames = builtins.attrNames interfaces;
              firstIf = if ifNames != [ ] then interfaces.${builtins.head ifNames} else { };
            in
            firstIf.ipv6 or [ ];
          description = "Primary IPv6 addresses (derived from first networking interface)";
        };

        # Primary user owning this host (for libvirt, etc.)
        system-owner = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Primary user name for this host";
        };

        # Host-level access control
        system-access-groups = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Unix groups that grant login access to this host";
        };

        #Dynamically generate the settings namespace
        settings = lib.mkOption {
          description = "Per-aspect settings namespace";
          default = { };
          type =
            let
              aspectsWithSettings = lib.filterAttrs (_: a: a ? settings) den.aspects;

              reshapeSettings = raw: {
                imports = raw.imports or [ ];
                config = raw.config or { };
                options = builtins.removeAttrs raw [
                  "imports"
                  "config"
                ];
              };
            in
            lib.types.submodule {
              options = lib.mapAttrs (
                name: aspect:
                lib.mkOption {
                  # Pass the dynamically reshaped settings into the submodule
                  type = lib.types.submodule (reshapeSettings aspect.settings);
                  default = { };
                  description = "Settings for the ${name} aspect";
                }
              ) aspectsWithSettings;
            };
        };
      };

      # Set instantiate and home-manager module from channel (overridable per-host)
      config = {
        instantiate = lib.mkDefault (
          if config.class == "darwin" then resolvedChannel.darwinSystem else resolvedChannel.nixosSystem
        );

        # Per-channel home-manager module — den's HM provider reads this
        home-manager.module = lib.mkDefault (
          if config.class == "darwin" then
            resolvedChannel.home-manager-module.darwin
          else
            resolvedChannel.home-manager-module.nixos
        );
      };
    };
}
