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
    {
      colmena =
        {
          meta = {
            nixpkgs = import inputs.nixpkgs-unstable {
              system = "x86_64-linux";
            };
            nodeNixpkgs = builtins.mapAttrs (_: v: v.pkgs) self.nixosConfigurations;
            nodeSpecialArgs = builtins.mapAttrs (_: v: v._module.specialArgs) self.nixosConfigurations;
          };
        }
        // (lib.mapAttrs (
          hostname: nixosConfig:
          # For each NixOS configuration, we find its original options from the flake.
          let
            hostOptions = config.hosts.${hostname};
          in
          {
            imports = nixosConfig._module.args.modules;
            deployment = {
              targetHost = hostOptions.deployment.targetHost;
              tags = hostOptions.roles;
              allowLocalDeployment = true;
            };
          }
        ) self.nixosConfigurations);

      colmenaHive = inputs.colmena.lib.makeHive self.outputs.colmena;
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
