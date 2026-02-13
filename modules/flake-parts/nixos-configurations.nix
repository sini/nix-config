{
  self,
  lib,
  ...
}:
let
  inherit (self.lib.nixos-configuration-helpers) mkHost;
in
{
  flake =
    { config, ... }:
    {
      # This is set due to a regression in agenix-rekey that checks for homeConfigurations.
      homeConfigurations = { };

      # Build all NixOS configurations by applying the mkHost function to each host.
      nixosConfigurations = lib.mapAttrs mkHost config.hosts;

      # Allow systems to refer to each other via nodes.<name>
      nodes = self.outputs.nixosConfigurations;
    };
}
