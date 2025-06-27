{ inputs, rootPath, ... }:
{
  flake.modules.nixos.nixpkgs = {
    nixpkgs.overlays =
      [ ]
      ++ builtins.attrValues (
        import (rootPath + "/overlays/default.nix") {
          inherit inputs;
        }
      );
  };
}
