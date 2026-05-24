# Den aspect wrapping the standalone agenix generators NixOS module.
_: {
  den.aspects.secrets.agenix-generators.nixos = import ./_generators-module.nix;
}
