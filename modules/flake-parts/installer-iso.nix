{ inputs, withSystem, ... }:
{
  flake.nixosConfigurations = {
    # ISO installer for booting from USB/CD
    installer-iso = withSystem "x86_64-linux" (
      { system, ... }:
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ../hosts/_installer-iso
        ];
      }
    );

    # Kexec installer for nixos-anywhere
    installer-kexec = withSystem "x86_64-linux" (
      { system, ... }:
      inputs.nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ../hosts/_installer-kexec
        ];
      }
    );
  };

  # Package outputs for easy building
  # Use "iso" and "kexec" to avoid conflict with meta-build-target.nix
  perSystem = {
    packages = {
      # ISO image for USB/CD booting
      iso = inputs.self.nixosConfigurations.installer-iso.config.system.build.isoImage;

      # Kexec tarball for nixos-anywhere
      kexec = inputs.self.nixosConfigurations.installer-kexec.config.system.build.kexecInstallerTarball;
    };
  };
}
