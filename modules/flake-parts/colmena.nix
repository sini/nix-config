{
  self,
  inputs,
  ...
}:
{
  text.readme.parts.colmena =
    # markdown
    ''
      ## Remote deployment via Colmena

      This repository uses [Colmena](https://github.com/zhaofengli/colmena) to deploy NixOS configurations to remote hosts.
      Colmena supports both local and remote deployment, and hosts can be targeted by roles as well as their name.
      Remote connection properties are defined in the `flake.hosts.<hostname>.deployment` attribute set, and implementation
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
    {
      lib,
      config,
      ...
    }:
    let
      colmenaHosts = lib.filterAttrs (_: h: lib.hasSuffix "-linux" h.system) config.hosts;

      stableHosts = lib.filterAttrs (_: h: !(h.unstable or false)) colmenaHosts;
      unstableHosts = lib.filterAttrs (_: h: h.unstable or false) colmenaHosts;

      mkColmenaHive =
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
              tags = [ hostOptions.environment ] ++ hostOptions.roles;
              allowLocalDeployment = true;
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

      colmena = mkColmenaHive {
        hosts = stableHosts;
        inherit (inputs) nixpkgs;
      };

      colmenaUnstable = mkColmenaHive {
        hosts = unstableHosts;
        nixpkgs = inputs.nixpkgs-unstable;
      };

      hiveStable = if stableHosts == { } then null else inputs.colmena.lib.makeHive colmena;
      hiveUnstable = if unstableHosts == { } then null else inputs.colmena.lib.makeHive colmenaUnstable;

      mergeMap =
        a: b:
        if a == null && b == null then
          { }
        else if a == null then
          b
        else if b == null then
          a
        else if (builtins.isAttrs a && builtins.isAttrs b) then
          a // b
        else
          throw "mergeMap: expected two attrsets or nulls";

      # Final merged Hive
      colmenaHive =
        let
          mergedNodes = mergeMap (if hiveStable != null then hiveStable.nodes else null) (
            if hiveUnstable != null then hiveUnstable.nodes else null
          );
          mergedDeploymentConfig = mergeMap (
            if hiveStable != null then hiveStable.deploymentConfig else null
          ) (if hiveUnstable != null then hiveUnstable.deploymentConfig else null);
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
          toplevel = mergeMap (if hiveStable != null then hiveStable.toplevel else null) (
            if hiveUnstable != null then hiveUnstable.toplevel else null
          );
          passthrough =
            if hiveStable != null then
              lib.filterAttrs (
                name: _: lib.hasAttr name hiveStable && lib.isFunction hiveStable.${name}
              ) hiveStable
            else if hiveUnstable != null then
              lib.filterAttrs (
                name: _: lib.hasAttr name hiveUnstable && lib.isFunction hiveUnstable.${name}
              ) hiveUnstable
            else
              { };
        in
        passthrough
        // {
          __schema = "v0.5";
          nodes = mergedNodes;
          metaConfig = if hiveStable != null then hiveStable.metaConfig else hiveUnstable.metaConfig;
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
