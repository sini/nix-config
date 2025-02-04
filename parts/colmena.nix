{
  self,
  config,
  inputs,
  ...
}:
{
  flake =
    {
      lib,
      ...
    }:
    {
      colmena =
        lib.recursiveUpdate
          (builtins.mapAttrs (_k: v: { imports = v._module.args.modules; }) self.nixosConfigurations)
          {
            meta = {
              nixpkgs = import inputs.nixpkgs {
                system = "x86_64-linux";
                overlays = [ ];
              };
              nodeNixpkgs = builtins.mapAttrs (_: v: v.pkgs) self.nixosConfigurations;
              nodeSpecialArgs = builtins.mapAttrs (_: v: v._module.specialArgs) self.nixosConfigurations;
            };

            defaults.deployment.targetUser = "sini";
          }
        // builtins.mapAttrs (_name: value: {
          imports = value._module.args.modules ++ [
            {
              inherit (value.config.node) deployment;
            }
          ];
        }) self.nixosConfigurations;
    };
}
