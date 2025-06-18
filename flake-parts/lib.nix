{ inputs, ... }:

let
  # Alias the standard Nixpkgs library for easier reference
  nixpkgsLib = inputs.nixpkgs.lib;

  # Capture the absolute path to the root of the flake
  flakeRoot = ../.;

  # --- Helper: Extract the argument names of a function ---
  # Falls back to builtins if not overridden
  functionArgs = nixpkgsLib.functionArgs or (f: builtins.attrNames (builtins.functionArgs f));

  # --- Helper: Load and auto-call all .nix files in a directory ---
  # This function:
  #   - Imports each .nix file in the given path
  #   - If it's a function, it auto-applies standard arguments (e.g., inputs, lib, flakeRoot)
  #   - Returns a flat attribute set where keys are the filenames (without .nix)
  callLibsFromDir =
    self: path:
    nixpkgsLib.pipe (builtins.readDir path) [
      # Keep only regular `.nix` files
      (nixpkgsLib.filterAttrs (_: type: type == "regular" && nixpkgsLib.hasSuffix ".nix" _))
      # Turn each file into a { name, value } entry for an attrset
      (nixpkgsLib.mapAttrsToList (
        name: _:
        let
          filePath = "${path}/${name}";
          moduleName = nixpkgsLib.removeSuffix ".nix" name;
          rawFunc = import filePath;

          # If it's a function, apply default arguments like lib and inputs
          wrappedFunc =
            if nixpkgsLib.isFunction rawFunc then
              let
                args = functionArgs rawFunc;
                defaultArgs = nixpkgsLib.recursiveUpdate (nixpkgsLib.mapAttrs (_: _: null) args) {
                  inherit inputs flakeRoot;
                  lib = self;
                };
              in
              rawFunc defaultArgs
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

  # --- Helper: Merge together the values of a namespaced library ---
  # This flattens a nested set of modules (e.g. { a = { x = 1; }; b = { y = 2; }; })
  # into a single attribute set (e.g. { x = 1; y = 2; })
  flattenLib =
    namespaced: nixpkgsLib.foldl nixpkgsLib.recursiveUpdate { } (nixpkgsLib.attrValues namespaced);

  # --- Build the full extended library using a fixpoint ---
  # This ensures each function can use the full library (`self`) as a dependency.
  extendedLibrary = nixpkgsLib.fix (
    self:
    let
      # Load all custom library functions from ./lib/
      # Each receives the full extended lib as `lib`
      customLib = flattenLib (callLibsFromDir self (flakeRoot + "/lib"));
    in
    # Merge:
    # 1. nixpkgs.lib (base functions)
    # 2. flake-parts.lib (flake-specific helpers)
    # 3. nvf.lib (optional additional layer)
    # 4. your own custom library
    nixpkgsLib.recursiveUpdate nixpkgsLib (
      nixpkgsLib.recursiveUpdate (inputs.flake-parts.lib or { }) (
        nixpkgsLib.recursiveUpdate (inputs.nvf.lib or { }) customLib
      )
    )
  );

in
{
  perSystem = {
    # Inject the extended lib into each system's module arguments
    _module.args.lib = extendedLibrary;
  };

  flake = {
    # Also expose the library as a top-level flake output
    lib = extendedLibrary;
  };
}
