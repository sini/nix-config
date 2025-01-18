{ lib, ... }:
let
  inherit (builtins)
    filter
    map
    toString
    elem
    ;
  inherit (lib.filesystem) listFilesRecursive;
  inherit (lib.strings) hasSuffix;

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

  relativeToRoot = lib.path.append ../.;

  scanPaths =
    path:
    builtins.map (f: (path + "/${f}")) (
      builtins.attrNames (
        lib.attrsets.filterAttrs (
          path: _type:
          (_type == "directory") # include directories
          || (
            (path != "default.nix") # ignore default.nix
            && (lib.strings.hasSuffix ".nix" path) # include .nix files
          )
        ) (builtins.readDir path)
      )
    );
in
{
  inherit relativeToRoot scanPaths mkModuleTree;
}
