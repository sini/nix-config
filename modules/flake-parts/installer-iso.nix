{ inputs, withSystem, ... }:
{
  flake.nixosConfigurations.installer-iso = withSystem "x86_64-linux" (
    { system, ... }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ../hosts/_installer-iso
      ];
    }
  );

  # Add a package output for easy building of the ISO image
  # Use "iso" to avoid conflict with meta-build-target.nix which creates "installer-iso" package
  perSystem =
    { ... }:
    {
      packages.iso = inputs.self.nixosConfigurations.installer-iso.config.system.build.isoImage;
    };
}
