# Ensure the home-manager NixOS module is always imported.
# Den's home-manager battery wires HM per-user, but aspects like agenix
# unconditionally reference home-manager.sharedModules. This core aspect
# guarantees the option exists on every host.
{ den, inputs, ... }:
{
  den.aspects.core.home-manager = {
    nixos = {
      imports = [ inputs.home-manager.nixosModules.home-manager ];
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
    };
  };
}
