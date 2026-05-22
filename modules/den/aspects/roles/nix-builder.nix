{ den, ... }:
{
  den.aspects.roles.nix-builder = {
    includes = [
      den.aspects.services.nix-remote-build-server
    ];
  };
}
