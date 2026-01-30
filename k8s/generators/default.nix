{
  inputs,
  system,
  lib,
  ...
}@sharedConfig:
let
  inherit (inputs) nixpkgs;
  pkgs = import nixpkgs { inherit system; };
  gFiles = builtins.attrNames (builtins.readDir ./.);
  generatorFiles = builtins.filter (
    file: builtins.match ".*\\.nix" file != null && file != "default.nix"
  ) gFiles;
  generators = builtins.listToAttrs (
    map (file: {
      name = builtins.replaceStrings [ ".nix" ] [ "" ] file;
      value = import (./. + "/${file}") sharedConfig;
    }) generatorFiles
  );
in
{
  packages.generate-crds = pkgs.writeShellScriptBin "generate-crds" ''
    set -eo pipefail

    ${lib.concatMapStringsSep "\n" (name: ''
      echo "generate ${name}"
      cat ${generators.${name}} > manifests/crd/${name}.nix
    '') (lib.attrNames generators)}
  '';
}
