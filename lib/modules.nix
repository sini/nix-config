{ lib, ... }:
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

  # List all module default.nix files rescursively
  listModulesRec = path: filter (hasSuffix ".nix") (map toString (listFilesRecursive path));

  # `mkModuleTree` is used to recursively import all Nix file in a given directory, assuming the
  # given directory to be the module root, where rest of the modules are to be imported. This
  # retains a sense of explicitness in the module tree, and allows for a more organized module
  # imports, discarding the vague `default.nix` name for directories that are *modules*.
  mkModuleTree =
    {
      path,
      ignoredPaths ? [ ./default.nix ],
    }:
    filter (hasSuffix ".nix") (
      map toString (
        # List all files in the given path, and filter out paths that are in
        # the ignoredPaths list
        filter (path: !elem path ignoredPaths) (listFilesRecursive path)
      )
    );

  scanPaths =
    path:
    map (f: (path + "/${f}")) (
      attrNames (
        filterAttrs (
          path: _type:
          (_type == "directory") # include directories
          || (
            (path != "default.nix") # ignore default.nix
            && (hasSuffix ".nix" path) # include .nix files
          )
        ) (readDir path)
      )
    );

in
{
  inherit
    scanPaths
    listModulesRec
    mkModuleTree
    ;
}
