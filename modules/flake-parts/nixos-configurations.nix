{
  lib,
  self,
  ...
}:
let
  inherit (self.lib.nixos-configuration-helpers) mkHost mkHostKexec;

  isLinux = lib.hasSuffix "-linux";
  isDarwin = lib.hasSuffix "-darwin";
in
{
  flake =
    { config, ... }:
    let
      linuxHosts = lib.filterAttrs (_: h: isLinux h.system) config.hosts;
      darwinHosts = lib.filterAttrs (_: h: isDarwin h.system) config.hosts;
    in
    {
      # This is set due to a regression in agenix-rekey that checks for homeConfigurations.
      homeConfigurations = { };

      # Build NixOS configurations for Linux hosts
      nixosConfigurations = lib.mapAttrs mkHost linuxHosts;

      # Build nix-darwin configurations for macOS hosts
      darwinConfigurations = lib.mapAttrs mkHost darwinHosts;

      # Kexec variants are Linux-only
      kexecNixosConfigurations = lib.mapAttrs' (
        name: hostOptions: lib.nameValuePair "${name}-kexec" (mkHostKexec name hostOptions)
      ) linuxHosts;

      # Allow systems to refer to each other via nodes.<name>
      # Exclude installer ISOs and kexec variants from deployment nodes
      nodes = lib.filterAttrs (
        name: _: !(lib.hasPrefix "installer-" name) && !(lib.hasSuffix "-kexec" name)
      ) self.outputs.nixosConfigurations;
    };
}
