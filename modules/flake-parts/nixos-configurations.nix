{
  lib,
  self,
  ...
}:
let
  inherit (self.lib.nixos-configuration-helpers) mkHost mkHostKexec;
in
{
  flake =
    { config, ... }:
    {
      # This is set due to a regression in agenix-rekey that checks for homeConfigurations.
      homeConfigurations = { };

      # Build all NixOS configurations by applying the mkHost function to each host.
      # Also generate kexec variants for each host with the "-kexec" suffix.
      nixosConfigurations =
        (lib.mapAttrs mkHost config.hosts)
        // (lib.mapAttrs' (
          name: hostOptions: lib.nameValuePair "${name}-kexec" (mkHostKexec name hostOptions)
        ) config.hosts);

      # Allow systems to refer to each other via nodes.<name>
      # Exclude installer ISOs and kexec variants from deployment nodes
      nodes = lib.filterAttrs (
        name: _: !(lib.hasPrefix "installer-" name) && !(lib.hasSuffix "-kexec" name)
      ) self.outputs.nixosConfigurations;
    };
}
