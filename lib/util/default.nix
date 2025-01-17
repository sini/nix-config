

{ lib, ... }:
with lib;
let
  inherit (builtins) fromJSON readFile;
  inherit (lib.meta) getExe;

  /*
    *
  Converts a YAML file to a JSON representation using the `yj` tool.

  # Inputs

  `pkgs`
  : A set of Nix packages, must include `yj`.

  `file`
  : A path to the YAML file to be converted.

  # Type

  ```
  fromYAML :: { pkgs: pkgs } -> file: string -> JSON
  ```
  */

  fromYAML = pkgs: file: let
    converted-json = pkgs.runCommand "yaml-converted.json" {} ''
      ${getExe pkgs.yj} < ${file} > $out
    '';
  in
    fromJSON (readFile converted-json);
in
rec {
  inherit fromYAML;
  ## Create a NixOS module option.
  ##
  ## ```nix
  ## lib.mkOpt nixpkgs.lib.types.str "My default" "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkOpt =
    type: default: description:
    mkOption { inherit type default description; };

  ## Create a NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkOpt' nixpkgs.lib.types.str "My default"
  ## ```
  ##
  #@ Type -> Any -> String
  mkOpt' = type: default: mkOpt type default null;

  ## Create a boolean NixOS module option.
  ##
  ## ```nix
  ## lib.mkBoolOpt true "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkBoolOpt = mkOpt types.bool;

  ## Create a boolean NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkBoolOpt true
  ## ```
  ##
  #@ Type -> Any -> String
  mkBoolOpt' = mkOpt' types.bool;

  ## Create a package NixOS module option.
  ##
  ## ```nix
  ## lib.mkPackageOpt pkgs.rofi-wayland "Description of my option."
  ## ```
  ##
  #@ Type -> Any -> String
  mkPackageOpt = mkOpt types.package;

  ## Create a package NixOS module option without a description.
  ##
  ## ```nix
  ## lib.mkPackageOpt' pkgs.rofi-wayland
  ## ```
  ##
  #@ Type -> Any -> String
  mkPackageOpt' = mkOpt types.package;

  enabled = {
    ## Quickly enable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ true
    enable = true;
  };

  disabled = {
    ## Quickly disable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ false
    enable = false;
  };

  ## Capitalize the first letter of a string.
  capitalize =
    s:
    let
      len = lib.stringLength s;
    in
    if len == 0 then "" else (lib.toUpper (lib.substring 0 1 s)) + (lib.substring 1 len s);

  # return an int (1/0) based on boolean value
  # `boolToNum true` -> 1
  boolToNum = bool: if bool then 1 else 0;

  ## Create a default attribute set.
  default-attrs = mapAttrs (_key: lib.mkDefault);

  ## Create a force attribute set.
  force-attrs = mapAttrs (_key: lib.mkForce);

  ## Create a nested default attribute set.
  nested-default-attrs = mapAttrs (_key: default-attrs);

  ## Create a nested force attribute set.
  nested-force-attrs = mapAttrs (_key: force-attrs);
}
