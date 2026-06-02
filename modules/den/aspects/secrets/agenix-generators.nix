# Den aspect wrapping the standalone agenix generators NixOS module.
{
  den.aspects.secrets.agenix-generators.nixos = {
    imports = [ ./_generators-module.nix ];
  };
}
