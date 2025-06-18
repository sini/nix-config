{ inputs, ... }:
let
  inherit (inputs.nixpkgs) lib;

  # Determine the path to your local lib directory
  libDir = ../lib;
  flakeRoot = ../.;

  # Reusable logic for figuring out required function arguments
  functionArgs = lib.functionArgs or (f: builtins.attrNames (builtins.functionArgs f));

  # Automatically load and wrap lib functions with required args
  callLibsFromDir =
    path:
    lib.pipe (builtins.readDir path) [
      (lib.filterAttrs (_name: type: type == "regular" && lib.hasSuffix ".nix" _name))
      (lib.mapAttrsToList (
        name: _type:
        let
          filePath = "${path}/${name}";
          moduleName = lib.removeSuffix ".nix" name;
          rawFunc = import filePath;

          wrappedFunc =
            if lib.isFunction rawFunc then
              let
                args = functionArgs rawFunc;
                defaultArgs = lib.recursiveUpdate (lib.mapAttrs (_: _: null) args) {
                  inherit inputs;
                  lib = extendedLibrary;
                  inherit flakeRoot;
                };
              in
              {
                __functor = _: overrideArgs: rawFunc (lib.recursiveUpdate defaultArgs overrideArgs);
                inherit rawFunc;
              }
              // rawFunc defaultArgs
            else
              rawFunc;
        in
        {
          name = moduleName;
          value = wrappedFunc;
        }
      ))
      builtins.listToAttrs
    ];

  mergeKeys =
    keys: prev: next:
    lib.foldl (
      acc: key:
      acc
      // {
        ${key} = lib.recursiveUpdate (prev.${key} or { }) (next.${key} or { });
      }
    ) { } keys;

  # Placeholder so we can reference the full library during its construction
  extendedLib = callLibsFromDir libDir;

  # Compose all libraries together
  extensions = lib.composeManyExtensions [
    (_: _: inputs.nixpkgs.lib)
    (_: _: inputs.flake-parts.lib)
    (_: _: inputs.nvf.lib or { })
    (mergeKeys [
      "options"
      "attrs"
    ]) # These modules are deep merged
    (_: _: extendedLib)
  ];

  # Fully constructed extended library
  extendedLibrary = (lib.makeExtensible (_: extendedLib)).extend extensions;

in
{
  perSystem = {
    _module.args.lib = extendedLibrary;
  };

  flake = {
    lib = extendedLibrary;
  };
}
