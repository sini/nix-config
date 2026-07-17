{ inputs, ... }:
{
  flake-file.inputs.systems.url = "github:nix-systems/default/future-26.11";

  systems = import inputs.systems;
}
