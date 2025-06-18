{ lib, flakeRoot, ... }:

let
  inherit (builtins)
    attrNames
    elem
    filter
    map
    readDir
    toString
    ;
  inherit (lib.attrsets) filterAttrs;
  inherit (lib.filesystem) listFilesRecursive;
  inherit (lib.strings) hasSuffix;

  # Return path relative to flake root
  relativeToRoot = path: "${flakeRoot}/${path}";

  # List all .nix files recursively under a given path
  listModulesRec = path: filter (hasSuffix ".nix") (map toString (listFilesRecursive path));

  # Return all .nix files under a path, excluding specific ignored paths
  mkModuleTree =
    {
      path,
      ignoredPaths ? [ ./default.nix ],
    }:
    let
      files = listFilesRecursive path;
    in
    filter (file: (hasSuffix ".nix" file) && !(elem file ignoredPaths)) (map toString files);

  # List only directories under a path relative to flake root
  listDirectories =
    path: attrNames (filterAttrs (_: type: type == "directory") (readDir (relativeToRoot path)));

  # Return a list of `.nix` files and directories under a given path
  scanPaths =
    path:
    let
      entries = readDir path;
    in
    map (name: "${path}/${name}") (
      attrNames (
        filterAttrs (
          name: type: type == "directory" || (hasSuffix ".nix" name && name != "default.nix")
        ) entries
      )
    );
in
{
  inherit
    relativeToRoot
    listModulesRec
    mkModuleTree
    listDirectories
    scanPaths
    ;
}
