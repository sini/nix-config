# Colmena battery: registers the colmena class, wires host modules into
# a colmena hive via policy.instantiate, and adds the CLI to devshell.
{
  den,
  lib,
  config,
  inputs,
  self,
  ...
}:
let
  currentSystem = builtins.currentSystem or "x86_64-linux";

  allHosts = lib.foldl' (acc: system: acc // (config.den.hosts.${system} or { })) { } (
    builtins.attrNames (config.den.hosts or { })
  );

  colmenaNodes = lib.mapAttrs (
    name: _modules:
    let
      host = allHosts.${name} or { };
      isNixos = (host.class or "") == "nixos";
      isDarwin = (host.class or "") == "darwin";
      osConfig =
        if isNixos then
          self.nixosConfigurations.${name} or null
        else if isDarwin then
          self.darwinConfigurations.${name} or null
        else
          null;
    in
    {
      imports = if osConfig != null then osConfig._module.args.modules else [ ];
      deployment = {
        targetHost =
          let
            ipv4 = host.ipv4 or [ ];
          in
          if ipv4 == [ ] then "${name}.ts.json64.dev" else builtins.head ipv4;
        tags = [ (host.environment or "prod") ];
        allowLocalDeployment = true;
        buildOnTarget = (host.system or currentSystem) != currentSystem;
        targetUser = host.remote-deployment-user or "sini";
      }
      // lib.optionalAttrs isDarwin { systemType = "darwin"; };
    }
  ) (config.flake.colmenaNodes or { });

  hiveConfig = colmenaNodes // {
    meta = {
      nixpkgs = import inputs.nixpkgs-unstable { system = "x86_64-linux"; };
      nodeSpecialArgs = lib.mapAttrs (
        name: _:
        let
          osConfig = self.nixosConfigurations.${name} or self.darwinConfigurations.${name} or null;
        in
        if osConfig != null then osConfig._module.specialArgs else { }
      ) colmenaNodes;
    };
  };
in
{
  den.classes.colmena = { };

  den.policies.host-to-colmena =
    { host, ... }:
    [
      (den.lib.policy.instantiate {
        inherit (host) name;
        class = "colmena";
        instantiate = { modules, ... }: modules;
        intoAttr = [
          "colmenaNodes"
          host.name
        ];
      })
    ];

  den.schema.host.includes = [ den.policies.host-to-colmena ];

  flake.colmenaHive = inputs.colmena.lib.makeHive hiveConfig;

  # Emit colmena CLI into devshell via class routing
  den.aspects.devshell.colmena = {
    devshell =
      { inputs', pkgs, ... }:
      let
        colmena = inputs'.colmena.packages.colmena.override {
          nix-eval-jobs = pkgs.lixPackageSets.stable.nix-eval-jobs;
        };
      in
      {
        packages = [ colmena ];
        commands = [
          {
            package = colmena;
            help = "Build and deploy this nix config to nodes";
          }
        ];
      };
  };
  den.schema.flake-parts.includes = [ den.aspects.devshell.colmena ];
}
