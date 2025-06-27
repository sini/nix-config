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
              overlays = [ ];
            };
            nodeNixpkgs = builtins.mapAttrs (_: v: v.pkgs) self.nixosConfigurations;
            nodeSpecialArgs = builtins.mapAttrs (_: v: v._module.specialArgs) self.nixosConfigurations;
          };
        }
        // (lib.mapAttrs (
          hostname: nixosConfig:
          # For each NixOS configuration, we find its original options from the flake.
          let
            hostOptions = config.flake.hosts.${hostname};
          in
          {
            imports = nixosConfig._module.args.modules;
            deployment = {
              targetHost = hostOptions.deployment.targetHost;
              tags = hostOptions.tags;
              allowLocalDeployment = true;
              privilegeEscalationCommand = [
                "doas"
                "--"
              ];
            };
          }
        ) self.nixosConfigurations);
    };
}
