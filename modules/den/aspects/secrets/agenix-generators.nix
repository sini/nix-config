# Den aspect wrapping the standalone agenix generators NixOS module.
_: {
  den.aspects.secrets.agenix-generators.nixos = import ../../../agenix/_generators.nix;
}
