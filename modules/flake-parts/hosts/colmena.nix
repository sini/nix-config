{
  self,
  inputs,
  config,
  lib,
  ...
}:
{
  flake-file.inputs.colmena = {
    url = "github:zw3rk/colmena/darwin-support";
    inputs = {
      nixpkgs.follows = "nixpkgs-unstable";
      flake-compat.follows = "flake-compat";
      flake-utils.follows = "flake-utils";
    };
  };

  text.readme.parts.colmena =
    # markdown
    ''
      ## Remote deployment via Colmena

      This repository uses [Colmena](https://github.com/zhaofengli/colmena) to deploy NixOS configurations to remote hosts.
      Colmena supports both local and remote deployment, and hosts can be targeted by roles as well as their name.
      Remote connection properties are defined in the `hosts.<hostname>.deployment` attribute set, and implementation
      can be found in the `modules/hosts/<hostname>/default.nix` file. This magic deployment logic lives in the
      [./m/f-p/colmena.nix](modules/flake-parts/colmena.nix) file.

      > [!NOTE]
      > I've made some pretty ugly hacks to make Colmena work with this repository to support multiple nixpkg versions
      > for different hosts, and to support both stable and unstable packages.

      ```bash
      # Deploy to all hosts
      colmena apply

      # Deploy to a specific host
      colmena apply --on <hostname>

      # Deploy to all hosts with the "server" tag
      colmena apply --on @server

      # Apply changes to the current host (useful for local development)
      colmena apply-local --sudo
      ```

    '';

  flake =
    let
      allHosts = config.hosts;
      colmenaLinuxHosts = lib.filterAttrs (_: h: lib.hasSuffix "-linux" h.system) allHosts;
      colmenaDarwinHosts = lib.filterAttrs (_: h: h.isDarwin) allHosts;

      # Group hosts by channel
      linuxHostsByChannel = lib.groupBy (name: colmenaLinuxHosts.${name}.channel) (
        lib.attrNames colmenaLinuxHosts
      );
      darwinHostsByChannel = lib.groupBy (name: colmenaDarwinHosts.${name}.channel) (
        lib.attrNames colmenaDarwinHosts
      );

      currentSystem = builtins.currentSystem or "x86_64-linux";

      mkColmenaLinuxHive =
        {
          hosts,
          nixpkgs,
        }:
        lib.mapAttrs (
          hostname: hostOptions:
          let
            nixosConfig = self.nixosConfigurations.${hostname};
          in
          {
            imports = nixosConfig._module.args.modules;
            deployment = {
              targetHost =
                if hostOptions.ipv4 == [ ] then "${hostname}.ts.json64.dev" else builtins.head hostOptions.ipv4;
              tags = [ hostOptions.environment ] ++ hostOptions.features;
              allowLocalDeployment = true;
              buildOnTarget = hostOptions.system != currentSystem;
              targetUser = hostOptions.remote-deployment-user;
            };
          }
        ) hosts
        // {
          meta = {
            nixpkgs = import nixpkgs { system = "x86_64-linux"; };
            nodeSpecialArgs = builtins.mapAttrs (
              hostname: _: self.nixosConfigurations.${hostname}._module.specialArgs
            ) hosts;
          };
        };

      mkColmenaDarwinHive =
        {
          hosts,
          nixpkgs,
          nix-darwin,
        }:
        lib.mapAttrs (
          hostname: hostOptions:
          let
            darwinConfig = self.darwinConfigurations.${hostname};
          in
          {
            imports = darwinConfig._module.args.modules;
            deployment = {
              targetHost =
                if hostOptions.ipv4 == [ ] then "${hostname}.ts.json64.dev" else builtins.head hostOptions.ipv4;
              tags = [ hostOptions.environment ] ++ hostOptions.features;
              allowLocalDeployment = true;
              systemType = "darwin";
              buildOnTarget = hostOptions.system != currentSystem;
              targetUser = hostOptions.remote-deployment-user;
            };
          }
        ) hosts
        // {
          meta = {
            inherit nix-darwin;
            nixpkgs = import nixpkgs { system = "aarch64-darwin"; };
            nodeSpecialArgs = builtins.mapAttrs (
              hostname: _: self.darwinConfigurations.${hostname}._module.specialArgs
            ) hosts;
          };
        };

      # Build a hive for each channel that has linux hosts
      linuxHivesPerChannel = lib.mapAttrs (
        channel: hostNames:
        let
          hosts = lib.getAttrs hostNames colmenaLinuxHosts;
          nixpkgs = config.channels.${channel}.nixpkgs;
          hiveConfig = mkColmenaLinuxHive { inherit hosts nixpkgs; };
        in
        inputs.colmena.lib.makeHive hiveConfig
      ) linuxHostsByChannel;

      # Build a hive for each channel that has darwin hosts
      darwinHivesPerChannel = lib.mapAttrs (
        channel: hostNames:
        let
          hosts = lib.getAttrs hostNames colmenaDarwinHosts;
          inherit (config.channels.${channel}) nixpkgs nix-darwin;
          hiveConfig = mkColmenaDarwinHive { inherit hosts nixpkgs nix-darwin; };
        in
        inputs.colmena.lib.makeHive hiveConfig
      ) darwinHostsByChannel;

      hiveList = (lib.attrValues linuxHivesPerChannel) ++ (lib.attrValues darwinHivesPerChannel);

      # Merge attribute sets from all hives
      mergeAttr = attr: lib.foldl' (acc: hive: acc // (hive.${attr} or { })) { } hiveList;

      # Final merged Hive
      colmenaHive =
        let
          mergedNodes = mergeAttr "nodes";
          mergedDeploymentConfig = mergeAttr "deploymentConfig";
          deploymentConfigSelected =
            names: lib.filterAttrs (name: _: builtins.elem name names) mergedDeploymentConfig;
          evalSelected = names: lib.filterAttrs (name: _: builtins.elem name names) toplevel;
          evalSelectedDrvPaths = names: lib.mapAttrs (_: v: v.drvPath) (evalSelected names);

          introspect =
            f:
            f {
              inherit lib;
              pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
              nodes = mergedNodes;
            };
          toplevel = mergeAttr "toplevel";
          firstHive = lib.head hiveList;
          passthrough = lib.filterAttrs (
            name: _: lib.hasAttr name firstHive && lib.isFunction firstHive.${name}
          ) firstHive;
        in
        passthrough
        // {
          __schema = "v0.5";
          nodes = mergedNodes;
          inherit (firstHive) metaConfig;
          deploymentConfig = mergedDeploymentConfig;
          inherit
            evalSelected
            evalSelectedDrvPaths
            deploymentConfigSelected
            introspect
            toplevel
            ;
        };
    in
    {
      inherit
        colmenaHive
        ;
    };

  perSystem =
    { inputs', pkgs, ... }:
    let
      # Override the flake input's colmena to use Lix instead of stock Nix
      colmena = inputs'.colmena.packages.colmena.override {
        nix-eval-jobs = pkgs.lixPackageSets.stable.nix-eval-jobs;
      };
    in
    {
      devshells.default.packages = [ colmena ];
      devshells.default.commands = [
        {
          package = colmena;
          help = "Build and deploy this nix config to nodes";
        }
      ];
    };
}
