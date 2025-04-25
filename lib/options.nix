{ lib, ... }:
let
  inherit (lib) mkOption types;

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
    enable = true;
  };

  disabled = {
    enable = false;
  };
in
{
  inherit
    mkOpt
    mkOpt'
    mkBoolOpt
    mkBoolOpt'
    mkPackageOpt
    mkPackageOpt'
    enabled
    disabled
    ;
}
