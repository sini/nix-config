{ lib, ... }:
with lib;
let
  libs = [
    (import ./attrs.nix { inherit lib; })
    (import ./modules.nix { inherit lib; })
    (import ./options.nix { inherit lib; })
  ];
in
lib.attrsets.mergeAttrsList libs
