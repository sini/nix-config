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
    { lib, config, ... }:
    with builtins;
    let
      stableHosts = lib.filterAttrs (_: h: !(h.unstable or false)) config.hosts;
      unstableHosts = lib.filterAttrs (_: h: h.unstable or false) config.hosts;

      mkColmenaHive =
        { hosts, nixpkgs }:
        lib.mapAttrs (
          hostname: hostOptions:
          let
            nixosConfig = self.nixosConfigurations.${hostname};
          in
          {
            imports = nixosConfig._module.args.modules;
            deployment = {
              targetHost = hostOptions.deployment.targetHost;
              tags = hostOptions.roles;
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
        nixpkgs = inputs.nixpkgs;
      };

      colmenaUnstable = mkColmenaHive {
        hosts = unstableHosts;
        nixpkgs = inputs.nixpkgs-unstable;
      };

      hiveStable = inputs.colmena.lib.makeHive colmena;
      hiveUnstable = inputs.colmena.lib.makeHive colmenaUnstable;

      mergeMap =
        a: b:
        if (builtins.isAttrs a && builtins.isAttrs b) then
          a // b
        else
          throw "mergeMap: expected two attrsets";

      # ✅ Final merged Hive
      colmenaHive =
        let
          mergedNodes = hiveStable.nodes // hiveUnstable.nodes;
          mergedDeploymentConfig = mergeMap hiveStable.deploymentConfig hiveUnstable.deploymentConfig;
          deploymentConfigSelected = names: lib.filterAttrs (name: _: elem name names) mergedDeploymentConfig;
          evalSelected = names: lib.filterAttrs (name: _: elem name names) toplevel;
          evalSelectedDrvPaths = names: lib.mapAttrs (_: v: v.drvPath) (evalSelected names);

          introspect =
            f:
            f {
              inherit lib;
              pkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
              nodes = mergedNodes;
            };
          toplevel = mergeMap hiveStable.toplevel hiveUnstable.toplevel;
          passthrough = lib.filterAttrs (
            name: _: lib.hasAttr name hiveStable && lib.isFunction hiveStable.${name}
          ) hiveStable;

        in
        passthrough
        // {
          __schema = "v0.5";
          nodes = mergedNodes;
          metaConfig = hiveStable.metaConfig;
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
    { inputs', ... }:
    {
      devshells.default.packages = [ inputs'.colmena.packages.colmena ];
      devshells.default.commands = [
        {
          package = inputs'.colmena.packages.colmena;
          help = "Build and deploy this nix config to nodes";
        }
      ];
    };
}
