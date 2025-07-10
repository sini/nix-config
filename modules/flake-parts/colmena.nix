{
  self,
  inputs,
  ...
}:
{

  flake =
    {
      lib,
      config,
      ...
    }:
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

    in
    {
      colmena = mkColmenaHive {
        hosts = stableHosts;
        nixpkgs = inputs.nixpkgs;
      };

      colmenaUnstable = mkColmenaHive {
        hosts = unstableHosts;
        nixpkgs = inputs.nixpkgs-unstable;
      };

      # colmena =
      #   lib.mapAttrs (
      #     hostname: nixosConfig:
      #     # For each NixOS configuration, we find its original options from the flake.
      #     let
      #       hostOptions = config.hosts.${hostname};
      #     in
      #     {
      #       imports = nixosConfig._module.args.modules;
      #       deployment = {
      #         targetHost = hostOptions.deployment.targetHost;
      #         tags = hostOptions.roles;
      #         allowLocalDeployment = true;
      #       };
      #     }
      #   ) self.nixosConfigurations
      #   // {
      #     meta = {
      #       nixpkgs = import inputs.nixpkgs { system = "x86_64-linux"; };
      #       # This is triggering twice:
      #       # nodeNixpkgs = builtins.mapAttrs (_: v: v.pkgs) self.nixosConfigurations;
      #       nodeSpecialArgs = builtins.mapAttrs (_: v: v._module.specialArgs) self.nixosConfigurations;
      #     };
      #   };

      colmenaHive = inputs.colmena.lib.makeHive self.outputs.colmena;
      colmenaHiveUnstable = inputs.colmena.lib.makeHive self.outputs.colmenaUnstable;
    };

  perSystem =
    { inputs', ... }:
    {
      devshells.default.packages = [
        inputs'.colmena.packages.colmena
      ];

      devshells.default.commands = [
        {
          package = inputs'.colmena.packages.colmena;
          help = "Build and deploy this nix config to nodes";
        }
      ];
    };
}
