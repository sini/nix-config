{ lib }:
let
  dir = ./modules;

  isModule =
    name: type: ((type == "regular") && (lib.hasSuffix ".nix" name)) || (type == "directory");
in
lib.pipe (builtins.readDir dir) [
  (lib.filterAttrs isModule)
  builtins.attrNames
  (builtins.map (filename: dir + "/${filename}"))
]
# ++ [
#   inputs.catppuccin.homeModules.catppuccin
# ]
