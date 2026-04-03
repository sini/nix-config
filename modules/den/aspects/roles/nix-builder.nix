# Nix builder role: includes nix-remote-build-server
{ den, ... }:
{
  den.aspects.nix-builder = {
    includes = [
      den.aspects.nix-remote-build-server
    ];
  };
}
