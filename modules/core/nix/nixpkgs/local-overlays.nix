{ inputs, rootPath, ... }:
{
  flake.modules.nixos.nix = {
    nixpkgs.overlays =
      [ ]
      ++ builtins.attrValues (
        import (rootPath + "/overlays/default.nix") {
          inherit inputs;
        }
      );
  };
}
